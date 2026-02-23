# RunningAnalyzer

아이폰 러닝 앱에서 **스크린샷 OCR 텍스트를 파싱**하고, 저장된 기록을 **월 결산**으로 집계하기 위한 Swift 패키지입니다.

## 제공 기능
- `OCRRunRecordParser`
  - OCR 텍스트에서 거리, 시간, 페이스, 심박수, 칼로리를 추출
  - 거리/시간/페이스가 없으면 에러 반환
- `MonthlySummaryCalculator`
  - `RunRecord` 배열을 `YYYY-MM` 기준으로 그룹핑
  - 월별 러닝 횟수, 총 거리, 총 시간, 평균 페이스, 평균 심박수 계산

## 데이터 모델
- `RunRecord`: 1회 러닝 기록
- `MonthlySummary`: 월 단위 요약 결과

## 빠른 사용 예시
```swift
import RunningAnalyzer

let parser = OCRRunRecordParser()
let date = Date()
let text = "거리 10.5km 시간 00:52:30 페이스 5:00 min/km 평균심박 158 bpm 640 kcal"

let record = try parser.parse(text: text, date: date)

let summaries = MonthlySummaryCalculator().summarize(records: [record])
print(summaries)
```

## 테스트 실행
```bash
swift test
```

## iOS 앱 연동 포인트
- Vision `VNRecognizeTextRequest`로 문자열 추출
- 추출 텍스트를 `OCRRunRecordParser`에 전달
- 사용자 검수 후 `RunRecord` 저장 (SwiftData/Core Data)
- 월 결산 화면에서 `MonthlySummaryCalculator` 사용
