import Foundation
import Testing
@testable import RunningAnalyzer

struct RunningAnalyzerTests {
    @Test
    func parseBasicOCRText() throws {
        let parser = OCRRunRecordParser()
        let date = ISO8601DateFormatter().date(from: "2026-02-03T09:00:00Z")!
        let rawText = "거리 10.5km 시간 00:52:30 페이스 5:00 min/km 평균심박 158 bpm 640 kcal"

        let record = try parser.parse(text: rawText, date: date)

        #expect(record.distanceKm == 10.5)
        #expect(record.durationSec == 3150)
        #expect(record.paceSecPerKm == 300)
        #expect(record.avgHeartRate == 158)
        #expect(record.calories == 640)
    }

    @Test
    func parseKoreanPaceAndUnits() throws {
        let parser = OCRRunRecordParser()
        let date = ISO8601DateFormatter().date(from: "2026-02-04T09:00:00Z")!
        let rawText = "7.2킬로미터 42:10 평균 5분51 분/km 심박 152"

        let record = try parser.parse(text: rawText, date: date)

        #expect(record.distanceKm == 7.2)
        #expect(record.durationSec == 2530)
        #expect(record.paceSecPerKm == 351)
        #expect(record.avgHeartRate == 152)
    }

    @Test
    func summarizeByMonth() {
        let dateFormatter = ISO8601DateFormatter()
        let records = [
            RunRecord(
                date: dateFormatter.date(from: "2026-02-01T07:00:00Z")!,
                distanceKm: 10,
                durationSec: 3000,
                paceSecPerKm: 300,
                avgHeartRate: 150,
                calories: 600,
                sourceText: "a"
            ),
            RunRecord(
                date: dateFormatter.date(from: "2026-02-15T07:00:00Z")!,
                distanceKm: 5,
                durationSec: 1560,
                paceSecPerKm: 312,
                avgHeartRate: 160,
                calories: 340,
                sourceText: "b"
            ),
            RunRecord(
                date: dateFormatter.date(from: "2026-03-02T07:00:00Z")!,
                distanceKm: 8,
                durationSec: 2560,
                paceSecPerKm: 320,
                avgHeartRate: nil,
                calories: 500,
                sourceText: "c"
            )
        ]

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let summaries = MonthlySummaryCalculator().summarize(records: records, calendar: calendar)

        #expect(summaries.count == 2)
        #expect(summaries[0].yearMonth == "2026-02")
        #expect(summaries[0].runCount == 2)
        #expect(summaries[0].totalDistanceKm == 15)
        #expect(summaries[0].totalDurationSec == 4560)
        #expect(summaries[0].avgPaceSecPerKm == 304)
        #expect(summaries[0].avgHeartRate == 155)

        #expect(summaries[1].yearMonth == "2026-03")
        #expect(summaries[1].runCount == 1)
        #expect(summaries[1].avgHeartRate == nil)
    }

    @Test
    func throwsWhenRequiredFieldsMissing() {
        let parser = OCRRunRecordParser()
        let date = Date()

        #expect(throws: OCRParsingError.distanceNotFound) {
            _ = try parser.parse(text: "시간 10:00 페이스 5:00 min/km", date: date)
        }

        #expect(throws: OCRParsingError.durationNotFound) {
            _ = try parser.parse(text: "거리 5.0km 페이스 5:00 min/km", date: date)
        }

        #expect(throws: OCRParsingError.paceNotFound) {
            _ = try parser.parse(text: "거리 5.0km 시간 25:00", date: date)
        }
    }
}
