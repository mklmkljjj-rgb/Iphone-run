import Foundation

public struct RunRecord: Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let distanceKm: Double
    public let durationSec: Int
    public let paceSecPerKm: Int
    public let avgHeartRate: Int?
    public let calories: Int?
    public let sourceText: String
    public let isManuallyEdited: Bool

    public init(
        id: UUID = UUID(),
        date: Date,
        distanceKm: Double,
        durationSec: Int,
        paceSecPerKm: Int,
        avgHeartRate: Int?,
        calories: Int?,
        sourceText: String,
        isManuallyEdited: Bool = false
    ) {
        self.id = id
        self.date = date
        self.distanceKm = distanceKm
        self.durationSec = durationSec
        self.paceSecPerKm = paceSecPerKm
        self.avgHeartRate = avgHeartRate
        self.calories = calories
        self.sourceText = sourceText
        self.isManuallyEdited = isManuallyEdited
    }
}

public struct MonthlySummary: Equatable, Sendable {
    public let yearMonth: String
    public let runCount: Int
    public let totalDistanceKm: Double
    public let totalDurationSec: Int
    public let avgPaceSecPerKm: Int
    public let avgHeartRate: Int?

    public init(
        yearMonth: String,
        runCount: Int,
        totalDistanceKm: Double,
        totalDurationSec: Int,
        avgPaceSecPerKm: Int,
        avgHeartRate: Int?
    ) {
        self.yearMonth = yearMonth
        self.runCount = runCount
        self.totalDistanceKm = totalDistanceKm
        self.totalDurationSec = totalDurationSec
        self.avgPaceSecPerKm = avgPaceSecPerKm
        self.avgHeartRate = avgHeartRate
    }
}

public enum OCRParsingError: Error, Equatable {
    case distanceNotFound
    case durationNotFound
    case paceNotFound
}

public struct OCRRunRecordParser: Sendable {
    public init() {}

    public func parse(text: String, date: Date) throws -> RunRecord {
        let normalized = text.lowercased()

        guard let distanceKm = extractDistance(from: normalized) else {
            throw OCRParsingError.distanceNotFound
        }

        guard let durationSec = extractDuration(from: normalized) else {
            throw OCRParsingError.durationNotFound
        }

        guard let paceSecPerKm = extractPace(from: normalized) else {
            throw OCRParsingError.paceNotFound
        }

        let heartRate = extractHeartRate(from: normalized)
        let calories = extractCalories(from: normalized)

        return RunRecord(
            date: date,
            distanceKm: distanceKm,
            durationSec: durationSec,
            paceSecPerKm: paceSecPerKm,
            avgHeartRate: heartRate,
            calories: calories,
            sourceText: text
        )
    }

    private func extractDistance(from text: String) -> Double? {
        let matches = text.captureGroups(pattern: #"(\d+(?:\.\d+)?)\s*(km|킬로미터)"#)
        guard let raw = matches.first?.first else { return nil }
        return Double(raw)
    }

    private func extractHeartRate(from text: String) -> Int? {
        let postfixed = text.captureGroups(pattern: #"(\d{2,3})\s*(bpm|심박)"#)
        if let raw = postfixed.first?.first, let value = Int(raw) {
            return value
        }

        let prefixed = text.captureGroups(pattern: #"(?:심박|bpm)\s*(\d{2,3})"#)
        guard let raw = prefixed.first?.first else { return nil }
        return Int(raw)
    }

    private func extractCalories(from text: String) -> Int? {
        let matches = text.captureGroups(pattern: #"(\d{2,5})\s*(kcal|칼로리)"#)
        guard let raw = matches.first?.first else { return nil }
        return Int(raw)
    }

    private func extractPace(from text: String) -> Int? {
        let matches = text.captureGroups(pattern: #"(\d{1,2})[:분](\d{2})\s*(?:/km|min/km|분/km)"#)
        guard let groups = matches.first, groups.count == 2,
              let min = Int(groups[0]),
              let sec = Int(groups[1]) else {
            return nil
        }
        return min * 60 + sec
    }

    private func extractDuration(from text: String) -> Int? {
        let hms = text.captureGroups(pattern: #"(\d{1,2}):(\d{2}):(\d{2})"#)
        if let g = hms.first, g.count == 3,
           let h = Int(g[0]), let m = Int(g[1]), let s = Int(g[2]) {
            return h * 3600 + m * 60 + s
        }

        let ms = text.captureGroups(pattern: #"(\d{1,2}):(\d{2})(?!\s*(?:/km|min/km|분/km))"#)
        if let g = ms.first, g.count == 2,
           let m = Int(g[0]), let s = Int(g[1]) {
            return m * 60 + s
        }
        return nil
    }
}

public struct MonthlySummaryCalculator: Sendable {
    public init() {}

    public func summarize(records: [RunRecord], calendar: Calendar = .current) -> [MonthlySummary] {
        let grouped = Dictionary(grouping: records) { record in
            Self.yearMonthString(from: record.date, calendar: calendar)
        }

        return grouped.map { yearMonth, runs in
            let runCount = runs.count
            let totalDistance = runs.reduce(0.0) { $0 + $1.distanceKm }
            let totalDuration = runs.reduce(0) { $0 + $1.durationSec }
            let avgPace = Int((Double(totalDuration) / max(totalDistance, 0.001)).rounded())

            let hrValues = runs.compactMap { $0.avgHeartRate }
            let avgHeartRate: Int? = hrValues.isEmpty ? nil : Int(Double(hrValues.reduce(0, +)) / Double(hrValues.count))

            return MonthlySummary(
                yearMonth: yearMonth,
                runCount: runCount,
                totalDistanceKm: totalDistance,
                totalDurationSec: totalDuration,
                avgPaceSecPerKm: avgPace,
                avgHeartRate: avgHeartRate
            )
        }
        .sorted { $0.yearMonth < $1.yearMonth }
    }

    private static func yearMonthString(from date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }
}

private extension String {
    func captureGroups(pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.matches(in: self, options: [], range: range).map { match in
            guard match.numberOfRanges > 1 else { return [] }
            return (1..<match.numberOfRanges).compactMap { index in
                let groupRange = match.range(at: index)
                guard let swiftRange = Range(groupRange, in: self) else { return nil }
                return String(self[swiftRange])
            }
        }
    }
}
