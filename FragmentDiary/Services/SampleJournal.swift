#if DEBUG
import PencilKit
import UIKit

/// Development only: fills last month and this month, up to today, with made-up days so the 기록 book has
/// pages (and a second month) to leaf through. Last month keeps a few blank days, the way a real diary does. Days that already have an entry are left alone, and the sample ids are remembered so removing
/// takes away exactly these and never a real entry.
@MainActor
enum SampleJournal {
    private static let idsKey = "sampleJournalEntryIDs"

    private static var storedIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: idsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: idsKey) }
    }

    static var hasSamples: Bool { !storedIDs.isEmpty }

    /// Returns how many days were added.
    static func fill(_ store: JournalStore) throws -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let monthStart = calendar.dateInterval(of: .month, for: today)?.start,
              let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart) else { return 0 }
        var ids = storedIDs
        var added = 0
        var day = lastMonthStart
        while day <= today {
            let index = calendar.component(.day, from: day) - 1
            let template = day < monthStart
                ? lastMonthTemplates[index % lastMonthTemplates.count]
                : templates[index % templates.count]
            if let template, store.entry(on: day) == nil {
                let entry = try makeEntry(on: day, from: template, store: store)
                try store.save(entry)
                ids.append(entry.id.uuidString)
                added += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        storedIDs = ids
        return added
    }

    /// Returns how many sample days were removed.
    static func remove(_ store: JournalStore) throws -> Int {
        let ids = Set(storedIDs)
        let samples = store.entries.filter { ids.contains($0.id.uuidString) }
        for entry in samples {
            try store.delete(entry)
        }
        storedIDs = []
        return samples.count
    }

    // MARK: Days

    private struct Template {
        var mood: Mood
        var note: String
        var quick = false
        var pieces: [Piece]
    }

    private enum Piece {
        case memo(String, hour: Int, color: Int)
        case emoji(String)
        case event(String, place: String?, hour: Int, reaction: String?, answer: String = "")
        case reminder(String, hour: Int, reaction: String?)
        case drawing(Doodle, caption: String, weather: Weather)
        case photo(Scene, caption: String, hour: Int)

        var isPhoto: Bool {
            if case .photo = self { return true }
            return false
        }
    }

    /// Last month, one per day (September 2026 starts on a Tuesday, 추석 falls on the 25th); nil days stay blank.
    private static let lastMonthTemplates: [Template?] = [
        Template(mood: .good, note: "9월 시작, 아침 공기가 선선해졌다", pieces: [
            .photo(.sky, caption: "출근길 구름이 예뻤다", hour: 8),
            .emoji("🍃☁️"),
        ]),
        Template(mood: .calm, note: "평범한 수요일", quick: true, pieces: [
            .event("팀 점심", place: "사내 식당", hour: 12, reaction: "🙂 무난했어"),
        ]),
        nil,
        Template(mood: .bright, note: "불금! 동료들이랑 치맥", pieces: [
            .event("동료들이랑 치맥", place: "회사 앞 호프", hour: 19, reaction: "🍻 즐거웠어", answer: "다음 주에 또 가기로 했다"),
            .emoji("🍗🍺"),
        ]),
        Template(mood: .good, note: "오랜만에 대청소", pieces: [
            .reminder("대청소", hour: 11, reaction: "✨ 개운해"),
            .drawing(.plant, caption: "베란다 정리", weather: .sunny),
        ]),
        Template(mood: .calm, note: "카페에서 책 읽은 일요일", pieces: [
            .photo(.cafe, caption: "단골 카페 창가", hour: 15),
            .memo("다 읽은 책: 작별하지 않는다", hour: 17, color: 5),
        ]),
        Template(mood: .low, note: "주말이 너무 짧다", quick: true, pieces: [
            .emoji("😮‍💨☕️"),
        ]),
        Template(mood: .calm, note: "회의가 길어져서 늦게 퇴근", pieces: [
            .event("프로젝트 회의", place: "대회의실", hour: 16, reaction: "😐 길었어"),
        ]),
        nil,
        Template(mood: .good, note: "요가 다시 시작!", pieces: [
            .event("요가 클래스", place: nil, hour: 19, reaction: "💪 개운해"),
            .memo("화·목 요가 등록 완료", hour: 21, color: 2),
        ]),
        Template(mood: .bright, note: "친구 청첩장 모임", pieces: [
            .photo(.cake, caption: "축하 케이크", hour: 19),
            .emoji("💐💍🥂"),
        ]),
        Template(mood: .good, note: "한강에서 피크닉", pieces: [
            .photo(.river, caption: "돗자리 펴고 낮잠", hour: 14),
            .drawing(.bike, caption: "자전거도 탔다", weather: .sunny),
        ]),
        Template(mood: .calm, note: "빨래하고 장 보고, 다음 주 준비", quick: true, pieces: [
            .reminder("장보기", hour: 16, reaction: "😌 후련해"),
        ]),
        Template(mood: .heavy, note: "아무것도 하기 싫은 날", quick: true, pieces: [
            .emoji("🛌"),
        ]),
        Template(mood: .low, note: "비가 하루 종일 왔다", pieces: [
            .drawing(.rain, caption: "비 오는 화요일", weather: .rainy),
        ]),
        nil,
        Template(mood: .good, note: "발표 무사히 끝!", pieces: [
            .event("분기 발표", place: "대회의실", hour: 14, reaction: "😌 후련해", answer: "질문에도 잘 답했다"),
            .memo("발표 자료 공유하기", hour: 17, color: 3),
        ]),
        Template(mood: .bright, note: "회사 앞에서 고양이를 만났다", pieces: [
            .drawing(.cat, caption: "고등어 고양이", weather: .sunny),
            .emoji("🐈✨"),
        ]),
        Template(mood: .good, note: "가을 옷 쇼핑하고 공원 산책", pieces: [
            .photo(.park, caption: "벌써 물드는 나무", hour: 16),
            .memo("니트 하나 샀다", hour: 18, color: 1),
        ]),
        Template(mood: .calm, note: "늦잠 자고 영화 한 편", pieces: [
            .emoji("🎬🍿🛋️"),
        ]),
        nil,
        Template(mood: .calm, note: "추석 선물 주문 완료", pieces: [
            .reminder("추석 선물 주문", hour: 20, reaction: "🎁 완료"),
        ]),
        Template(mood: .good, note: "연휴 전날, 일찍 퇴근", pieces: [
            .photo(.sunset, caption: "퇴근길 노을", hour: 18),
        ]),
        Template(mood: .bright, note: "추석 연휴 시작! 고향 가는 길", pieces: [
            .memo("기차 7시 출발, 3호차", hour: 7, color: 0),
            .emoji("🚄🌕"),
        ]),
        Template(mood: .bright, note: "추석, 가족이랑 송편 빚었다", pieces: [
            .event("가족 모임", place: "본가", hour: 12, reaction: "🥰 즐거웠어", answer: "송편 모양은 내가 제일 예뻤다"),
            .drawing(.moon, caption: "보름달 소원", weather: .cloudy),
        ]),
        Template(mood: .good, note: "연휴 마지막 날, 푹 쉬었다", quick: true, pieces: [
            .emoji("😴🍂"),
        ]),
        Template(mood: .calm, note: "다음 주 준비하는 일요일", pieces: [
            .memo("월요일 회의 자료 확인", hour: 21, color: 4),
        ]),
        Template(mood: .low, note: "연휴 후유증", quick: true, pieces: [
            .emoji("🥱"),
        ]),
        nil,
        Template(mood: .good, note: "9월 마지막 날, 한 달 돌아보기", pieces: [
            .memo("9월: 요가 6번, 책 2권", hour: 22, color: 5),
            .photo(.night, caption: "야경 보며 퇴근", hour: 21),
        ]),
    ]

    /// This month, one per day (October 2026 starts on a Thursday), so a date always gets the same page.
    private static let templates: [Template] = [
        Template(mood: .good, note: "10월의 첫날, 공기가 확 달라졌다", pieces: [
            .photo(.sky, caption: "출근길 하늘이 너무 파랬다", hour: 8),
            .memo("이번 달 목표: 책 두 권, 매일 30분 걷기", hour: 22, color: 0),
        ]),
        Template(mood: .bright, note: "드디어 금요일! 친구들이랑 늦게까지 수다 떨었다", pieces: [
            .event("대학 동기 모임", place: "을지로 노가리 골목", hour: 19, reaction: "🥰 즐거웠어", answer: "다음엔 캠핑 가기로 했다"),
            .drawing(.cheers, caption: "건배", weather: .sunny),
        ]),
        Template(mood: .good, note: "늦잠 자고 동네 한 바퀴", pieces: [
            .photo(.park, caption: "공원 은행나무가 노래지기 시작", hour: 15),
            .emoji("😴🍂🚶"),
        ]),
        Template(mood: .calm, note: "빨래하고 반찬 만들고, 다음 주 준비 끝", quick: true, pieces: [
            .reminder("장보기", hour: 11, reaction: "😌 후련해"),
            .memo("두부조림 성공. 간장 조금 덜 넣기", hour: 18, color: 4),
        ]),
        Template(mood: .low, note: "월요병이 제대로 왔다", pieces: [
            .drawing(.rain, caption: "비 오는 월요일", weather: .rainy),
            .emoji("🌧️😮‍💨"),
        ]),
        Template(mood: .calm, note: "조용히 일만 한 하루", quick: true, pieces: [
            .event("주간 회의", place: "3층 회의실", hour: 10, reaction: "😐 그럭저럭"),
            .emoji("💻☕️🌙"),
        ]),
        Template(mood: .calm, note: "점심에 새로 생긴 쌀국수집에 가봤다", pieces: [
            .event("점심 약속", place: "회사 앞 쌀국수집", hour: 12, reaction: "😋 맛있었어"),
            .memo("고수 빼달라고 하기!", hour: 13, color: 2),
        ]),
        Template(mood: .good, note: "운동 다녀오니 기분이 한결 낫다", pieces: [
            .event("요가 클래스", place: nil, hour: 19, reaction: "💪 개운해"),
            .emoji("🧘‍♀️✨"),
        ]),
        Template(mood: .bright, note: "한글날, 오랜만에 혼자 전시 보러 갔다", pieces: [
            .photo(.gallery, caption: "마음에 든 그림 앞에서 한참 서 있었다", hour: 14),
            .drawing(.frame, caption: "전시 보고 따라 그림", weather: .sunny),
            .memo("작가 이름 기억하기", hour: 16, color: 5),
        ]),
        Template(mood: .calm, note: "비 소리 들으면서 책 읽었다", quick: true, pieces: [
            .emoji("📚☔️🫖"),
        ]),
        Template(mood: .good, note: "가족이랑 저녁 먹은 날", pieces: [
            .event("엄마 생신 저녁", place: "한정식집", hour: 18, reaction: "🥹 뭉클했어", answer: "케이크에 초 꽂는 사진 남김"),
            .photo(.cake, caption: "생신 축하해요", hour: 20),
        ]),
        Template(mood: .heavy, note: "피곤해서 아무것도 못 했다", quick: true, pieces: [
            .emoji("🛌"),
        ]),
        Template(mood: .low, note: "일이 계속 꼬였지만 퇴근길 노을이 위로가 됐다", pieces: [
            .photo(.sunset, caption: "버스 창밖 노을", hour: 18),
            .reminder("보고서 제출", hour: 17, reaction: "😮‍💨 겨우 끝"),
        ]),
        Template(mood: .calm, note: "오늘은 일찍 잤다", pieces: [
            .drawing(.moon, caption: "일찍 자는 밤", weather: .cloudy),
        ]),
        Template(mood: .good, note: "회의가 생각보다 잘 끝났다", pieces: [
            .event("분기 리뷰", place: "대회의실", hour: 15, reaction: "😌 후련해"),
            .memo("다음 분기엔 발표 연습 미리 하기", hour: 17, color: 3),
            .emoji("📈👏"),
        ]),
        Template(mood: .bright, note: "퇴근하고 한강에서 자전거 탔다", pieces: [
            .photo(.river, caption: "바람이 시원했던 한강", hour: 20),
            .drawing(.bike, caption: "따릉이", weather: .sunny),
        ]),
        Template(mood: .good, note: "카페에서 하루 종일 밀린 일기 정리", pieces: [
            .photo(.cafe, caption: "창가 자리 성공", hour: 13),
            .memo("라떼 말고 아인슈페너 맛집", hour: 14, color: 1),
        ]),
        Template(mood: .calm, note: "집 정리하고 화분 분갈이", quick: true, pieces: [
            .drawing(.plant, caption: "새 화분", weather: .sunny),
            .reminder("분리수거", hour: 10, reaction: nil),
        ]),
        Template(mood: .low, note: "감기 기운이 있어서 하루 쉬었다", pieces: [
            .emoji("🤧🍵💊"),
            .memo("따뜻한 물 많이 마시기", hour: 21, color: 3),
        ]),
        Template(mood: .calm, note: "컨디션 회복 중", pieces: [
            .event("병원", place: "동네 내과", hour: 9, reaction: "🙂 괜찮대"),
            .emoji("🌤️"),
        ]),
        Template(mood: .good, note: "점심시간에 산책하다 고양이를 만났다", pieces: [
            .drawing(.cat, caption: "치즈 고양이", weather: .sunny),
            .memo("내일도 그 골목으로 가보기", hour: 13, color: 0),
        ]),
        Template(mood: .bright, note: "오래 준비한 일이 드디어 끝났다!", pieces: [
            .reminder("프로젝트 마감", hour: 18, reaction: "🎉 해냈다"),
            .emoji("🎉🍻🔥"),
            .photo(.night, caption: "끝나고 본 야경", hour: 22),
        ]),
        Template(mood: .good, note: "금요일 밤엔 역시 영화", pieces: [
            .event("영화 예매", place: "동네 CGV", hour: 20, reaction: "🍿 재밌었어", answer: "결말이 계속 생각난다"),
            .emoji("🎬🍿🌃"),
        ]),
        Template(mood: .bright, note: "단풍 보러 가까운 산에 다녀왔다", pieces: [
            .photo(.park, caption: "정상에서 본 단풍", hour: 13),
            .drawing(.frame, caption: "산 위에서 본 풍경", weather: .sunny),
            .memo("다음엔 김밥 두 줄 챙기기", hour: 16, color: 4),
        ]),
        Template(mood: .calm, note: "느긋한 일요일, 다음 주 계획 세우기", quick: true, pieces: [
            .memo("월: 장보기 / 수: 운동 / 금: 친구 생일", hour: 21, color: 3),
            .emoji("☕️📝🌤️"),
        ]),
        Template(mood: .calm, note: "새 주가 시작됐다", pieces: [
            .event("주간 회의", place: "3층 회의실", hour: 10, reaction: "🙂 무난했어"),
        ]),
        Template(mood: .good, note: "점심에 동료랑 산책", pieces: [
            .emoji("🍂🚶‍♀️🍂"),
            .memo("붕어빵 파는 곳 생김!", hour: 13, color: 4),
        ]),
        Template(mood: .low, note: "조금 지치는 하루", quick: true, pieces: [
            .drawing(.rain, caption: "흐림", weather: .cloudy),
        ]),
        Template(mood: .good, note: "친구 생일 선물 고르기", pieces: [
            .reminder("선물 포장", hour: 21, reaction: "🎁 완료"),
        ]),
        Template(mood: .bright, note: "친구 생일 파티!", pieces: [
            .photo(.cake, caption: "생일 축하해", hour: 20),
            .emoji("🎂🥳🎈"),
        ]),
        Template(mood: .bright, note: "할로윈이라 동네가 북적였다", pieces: [
            .emoji("🎃👻🍬"),
            .photo(.night, caption: "불빛이 예뻤던 거리", hour: 21),
        ]),
    ]

    private static func makeEntry(on day: Date, from template: Template, store: JournalStore) throws -> DiaryEntry {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(day)
        // Today's photo pieces are skipped: their fake library ids would meet the real photo collector.
        let pieces = template.pieces.filter { !(isToday && $0.isPhoto) }
        var fragments: [Fragment] = []
        for (index, piece) in pieces.enumerated() {
            fragments.append(try fragment(piece, index: index, on: day, store: store))
        }
        let written = isToday ? Date.now : calendar.date(bySettingHour: 22, minute: 30, second: 0, of: day) ?? day
        return DiaryEntry(
            id: UUID(), day: calendar.startOfDay(for: day), mood: template.mood, note: template.note,
            quick: template.quick, fragments: fragments.sorted { $0.start < $1.start },
            createdAt: written, updatedAt: written
        )
    }

    private static func fragment(_ piece: Piece, index: Int, on day: Date, store: JournalStore) throws -> Fragment {
        func at(_ hour: Int) -> Date {
            Calendar.current.date(bySettingHour: hour, minute: (index * 17) % 60, second: 0, of: day) ?? day
        }
        let id = "sample:\(UUID().uuidString)"
        switch piece {
        case let .memo(text, hour, color):
            var fragment = Fragment(sourceID: id, kind: .note, start: at(hour))
            fragment.caption = text
            fragment.noteColor = color
            return fragment
        case let .emoji(text):
            var fragment = Fragment(sourceID: id, kind: .emoji, start: at(12))
            fragment.caption = text
            return fragment
        case let .event(title, place, hour, reaction, answer):
            var fragment = Fragment(sourceID: id, kind: .event, start: at(hour), end: at(hour).addingTimeInterval(3600))
            fragment.title = title
            fragment.place = place
            fragment.reaction = reaction
            fragment.caption = answer
            return fragment
        case let .reminder(title, hour, reaction):
            var fragment = Fragment(sourceID: id, kind: .reminder, start: at(hour))
            fragment.title = title
            fragment.reaction = reaction
            return fragment
        case let .drawing(doodle, caption, weather):
            let layers = DecorationLayers(drawing: doodle.drawing.dataRepresentation(), stickers: [], aspectRatio: DrawingDiary.aspectRatio)
            let image = DecorationRenderer.render(base: nil, paper: UIColor(rgb: DrawingDiary.paperRGB), layers: layers, outputWidth: 1600)
            let attachment = UUID()
            try store.saveAttachment(attachment, image: image, layers: layers)
            var fragment = Fragment(sourceID: id, kind: .drawing, start: at(20))
            fragment.drawingID = attachment
            fragment.caption = caption
            fragment.weather = weather
            return fragment
        case let .photo(scene, caption, hour):
            // Shown the way a decorated photo is: the sealed image stands in for the library asset.
            let image = scene.render()
            let layers = DecorationLayers(drawing: PKDrawing().dataRepresentation(), stickers: [], aspectRatio: image.size.width / image.size.height)
            let attachment = UUID()
            try store.saveAttachment(attachment, image: image, layers: layers)
            let assetID = "sample-photo:\(attachment.uuidString)"
            var fragment = Fragment(sourceID: id, kind: .photos, start: at(hour))
            fragment.assetIDs = [assetID]
            fragment.decorations = [assetID: attachment]
            fragment.caption = caption
            return fragment
        }
    }
}

// MARK: Drawings

/// Simple pen doodles in the drawing canvas's coordinates (1000 × 720).
private enum Doodle {
    case cheers, rain, frame, moon, bike, plant, cat

    var drawing: PKDrawing {
        let ink = UIColor(rgb: 0x3B3029)
        switch self {
        case .cheers:
            return PKDrawing(strokes: [
                line([CGPoint(x: 330, y: 220), CGPoint(x: 360, y: 520), CGPoint(x: 470, y: 520), CGPoint(x: 500, y: 220), CGPoint(x: 330, y: 220)], ink, 9),
                line([CGPoint(x: 345, y: 320), CGPoint(x: 485, y: 320)], UIColor(rgb: 0xE0A93B), 26, .marker),
                line([CGPoint(x: 540, y: 240), CGPoint(x: 560, y: 520), CGPoint(x: 670, y: 520), CGPoint(x: 690, y: 240), CGPoint(x: 540, y: 240)], ink, 9),
                line([CGPoint(x: 552, y: 330), CGPoint(x: 678, y: 330)], UIColor(rgb: 0xE0A93B), 26, .marker),
                line([CGPoint(x: 490, y: 160), CGPoint(x: 470, y: 110)], ink, 7),
                line([CGPoint(x: 520, y: 150), CGPoint(x: 520, y: 95)], ink, 7),
                line([CGPoint(x: 550, y: 160), CGPoint(x: 575, y: 110)], ink, 7),
            ])
        case .rain:
            var strokes = [
                line(arc(center: CGPoint(x: 420, y: 260), radius: 90, from: .pi, to: 2 * .pi), UIColor(rgb: 0x7A8CA0), 10),
                line(arc(center: CGPoint(x: 560, y: 230), radius: 110, from: .pi, to: 2 * .pi), UIColor(rgb: 0x7A8CA0), 10),
                line([CGPoint(x: 330, y: 260), CGPoint(x: 670, y: 260)], UIColor(rgb: 0x7A8CA0), 10),
            ]
            for x in stride(from: 360, through: 640, by: 70) {
                strokes.append(line([CGPoint(x: x, y: 320), CGPoint(x: x - 20, y: 380)], UIColor(rgb: 0x5B8FC9), 9))
                strokes.append(line([CGPoint(x: x + 30, y: 430), CGPoint(x: x + 10, y: 490)], UIColor(rgb: 0x5B8FC9), 9))
            }
            return PKDrawing(strokes: strokes)
        case .frame:
            return PKDrawing(strokes: [
                line([CGPoint(x: 300, y: 160), CGPoint(x: 700, y: 160), CGPoint(x: 700, y: 560), CGPoint(x: 300, y: 560), CGPoint(x: 300, y: 160)], UIColor(rgb: 0x9C7A54), 14),
                line([CGPoint(x: 340, y: 500), CGPoint(x: 450, y: 330), CGPoint(x: 530, y: 440), CGPoint(x: 590, y: 380), CGPoint(x: 660, y: 500)], UIColor(rgb: 0x6E9B6E), 10),
                line(circle(center: CGPoint(x: 600, y: 250), radius: 40), UIColor(rgb: 0xE0703B), 12, .marker),
            ])
        case .moon:
            var strokes = [
                line(arc(center: CGPoint(x: 500, y: 340), radius: 150, from: 0.6 * .pi, to: 1.9 * .pi), UIColor(rgb: 0xE0A93B), 12),
                line(arc(center: CGPoint(x: 560, y: 310), radius: 120, from: 0.65 * .pi, to: 1.85 * .pi), UIColor(rgb: 0xE0A93B), 12),
            ]
            for point in [CGPoint(x: 280, y: 180), CGPoint(x: 730, y: 220), CGPoint(x: 700, y: 520), CGPoint(x: 260, y: 480)] {
                strokes.append(line([CGPoint(x: point.x - 18, y: point.y), CGPoint(x: point.x + 18, y: point.y)], ink, 7))
                strokes.append(line([CGPoint(x: point.x, y: point.y - 18), CGPoint(x: point.x, y: point.y + 18)], ink, 7))
            }
            return PKDrawing(strokes: strokes)
        case .bike:
            return PKDrawing(strokes: [
                line(circle(center: CGPoint(x: 340, y: 450), radius: 100), ink, 10),
                line(circle(center: CGPoint(x: 660, y: 450), radius: 100), ink, 10),
                line([CGPoint(x: 340, y: 450), CGPoint(x: 460, y: 300), CGPoint(x: 620, y: 300), CGPoint(x: 660, y: 450)], UIColor(rgb: 0x4F9A6B), 12),
                line([CGPoint(x: 460, y: 300), CGPoint(x: 520, y: 450), CGPoint(x: 620, y: 300)], UIColor(rgb: 0x4F9A6B), 12),
                line([CGPoint(x: 430, y: 260), CGPoint(x: 490, y: 260)], ink, 12),
                line([CGPoint(x: 620, y: 300), CGPoint(x: 600, y: 230), CGPoint(x: 650, y: 220)], ink, 10),
            ])
        case .plant:
            return PKDrawing(strokes: [
                line([CGPoint(x: 400, y: 420), CGPoint(x: 600, y: 420), CGPoint(x: 570, y: 600), CGPoint(x: 430, y: 600), CGPoint(x: 400, y: 420)], UIColor(rgb: 0xC0704A), 12),
                line([CGPoint(x: 500, y: 420), CGPoint(x: 500, y: 200)], UIColor(rgb: 0x4F9A6B), 10),
                line(arc(center: CGPoint(x: 430, y: 300), radius: 70, from: -0.2 * .pi, to: 0.9 * .pi), UIColor(rgb: 0x4F9A6B), 18, .marker),
                line(arc(center: CGPoint(x: 570, y: 250), radius: 70, from: 0.1 * .pi, to: 1.2 * .pi), UIColor(rgb: 0x4F9A6B), 18, .marker),
            ])
        case .cat:
            return PKDrawing(strokes: [
                line(circle(center: CGPoint(x: 500, y: 380), radius: 150), UIColor(rgb: 0xE0A93B), 12),
                line([CGPoint(x: 390, y: 280), CGPoint(x: 400, y: 160), CGPoint(x: 470, y: 235)], UIColor(rgb: 0xE0A93B), 12),
                line([CGPoint(x: 530, y: 235), CGPoint(x: 600, y: 160), CGPoint(x: 610, y: 280)], UIColor(rgb: 0xE0A93B), 12),
                line(circle(center: CGPoint(x: 445, y: 360), radius: 12), ink, 14),
                line(circle(center: CGPoint(x: 555, y: 360), radius: 12), ink, 14),
                line([CGPoint(x: 480, y: 420), CGPoint(x: 500, y: 435), CGPoint(x: 520, y: 420)], ink, 8),
                line([CGPoint(x: 330, y: 400), CGPoint(x: 420, y: 410)], ink, 6),
                line([CGPoint(x: 580, y: 410), CGPoint(x: 670, y: 400)], ink, 6),
            ])
        }
    }

    private func line(_ points: [CGPoint], _ color: UIColor, _ width: CGFloat, _ type: PKInk.InkType = .pen) -> PKStroke {
        let strokePoints = points.enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.02, size: CGSize(width: width, height: width),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(type, color: color), path: PKStrokePath(controlPoints: strokePoints, creationDate: .now))
    }

    private func arc(center: CGPoint, radius: CGFloat, from start: CGFloat, to end: CGFloat) -> [CGPoint] {
        (0...32).map { step in
            let angle = start + (end - start) * CGFloat(step) / 32
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        }
    }

    private func circle(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        arc(center: center, radius: radius, from: 0, to: 2 * .pi)
    }
}

// MARK: Photos

/// Painted stand-ins for photos, so sample pages have something to tape on.
private enum Scene {
    case sky, park, gallery, cake, sunset, river, cafe, night

    func render() -> UIImage {
        let size = CGSize(width: 1200, height: 900)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            func gradient(_ top: UInt32, _ bottom: UInt32, in rect: CGRect) {
                let colors = [UIColor(rgb: top).cgColor, UIColor(rgb: bottom).cgColor] as CFArray
                guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
                cg.saveGState()
                cg.clip(to: rect)
                cg.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
                cg.restoreGState()
            }
            func fill(_ rgb: UInt32, _ path: UIBezierPath) {
                UIColor(rgb: rgb).setFill()
                path.fill()
            }
            func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> UIBezierPath {
                UIBezierPath(ovalIn: CGRect(x: x, y: y, width: w, height: h))
            }
            let full = CGRect(origin: .zero, size: size)
            switch self {
            case .sky:
                gradient(0x5FA8E8, 0xCFE8FA, in: full)
                fill(0xFFFFFF, oval(180, 220, 260, 110)); fill(0xFFFFFF, oval(280, 170, 220, 140))
                fill(0xFFFFFF, oval(720, 360, 300, 120)); fill(0xFFFFFF, oval(820, 310, 200, 130))
                fill(0x8C9AA6, UIBezierPath(rect: CGRect(x: 0, y: 760, width: 1200, height: 140)))
            case .park:
                gradient(0xBFE3F2, 0xF2F0D8, in: full)
                fill(0x8BBF6A, UIBezierPath(rect: CGRect(x: 0, y: 600, width: 1200, height: 300)))
                for (x, color) in [(220, 0xF2C230), (560, 0xE8A93A), (900, 0xF2D04A)] as [(CGFloat, UInt32)] {
                    fill(0x7A5A3A, UIBezierPath(rect: CGRect(x: x - 18, y: 440, width: 36, height: 200)))
                    fill(color, oval(x - 150, 220, 300, 280))
                }
            case .gallery:
                fill(0xF4F1EA, UIBezierPath(rect: full))
                fill(0xD9D2C3, UIBezierPath(rect: CGRect(x: 0, y: 720, width: 1200, height: 180)))
                fill(0x9C7A54, UIBezierPath(rect: CGRect(x: 350, y: 160, width: 500, height: 400)))
                gradient(0x3C5A8A, 0xE8B86A, in: CGRect(x: 375, y: 185, width: 450, height: 350))
                fill(0xF2E3C2, oval(640, 230, 90, 90))
            case .cake:
                gradient(0xF6E3D6, 0xEBC9B6, in: full)
                fill(0xFFFFFF, oval(300, 560, 600, 160))
                fill(0xF7D9A8, UIBezierPath(roundedRect: CGRect(x: 380, y: 380, width: 440, height: 240), cornerRadius: 30))
                fill(0xFFF6EC, UIBezierPath(rect: CGRect(x: 380, y: 380, width: 440, height: 60)))
                for x in stride(from: 450, through: 750, by: 100) {
                    fill(0x8FB8E0, UIBezierPath(rect: CGRect(x: x, y: 290, width: 18, height: 90)))
                    fill(0xF2A93A, oval(CGFloat(x) - 6, 250, 30, 46))
                }
            case .sunset:
                gradient(0x5B4B8A, 0xF29A5A, in: CGRect(x: 0, y: 0, width: 1200, height: 620))
                fill(0xF7C66A, oval(500, 420, 200, 200))
                fill(0x2E2A3A, UIBezierPath(rect: CGRect(x: 0, y: 560, width: 1200, height: 340)))
                for (x, h) in [(60, 200), (220, 300), (380, 160), (760, 260), (930, 340)] as [(CGFloat, CGFloat)] {
                    fill(0x1F1C28, UIBezierPath(rect: CGRect(x: x, y: 560 - h, width: 120, height: h)))
                }
            case .river:
                gradient(0x9CC9E8, 0xE8F2F7, in: CGRect(x: 0, y: 0, width: 1200, height: 520))
                gradient(0x4F86B0, 0x7FB0CF, in: CGRect(x: 0, y: 520, width: 1200, height: 380))
                fill(0x6E7F8F, UIBezierPath(rect: CGRect(x: 0, y: 470, width: 1200, height: 50)))
                for x in stride(from: 40, through: 1160, by: 160) {
                    fill(0x6E7F8F, UIBezierPath(rect: CGRect(x: x, y: 470, width: 24, height: 120)))
                }
            case .cafe:
                gradient(0xE9DCC8, 0xCDB79A, in: full)
                fill(0x8A6A4A, UIBezierPath(rect: CGRect(x: 0, y: 640, width: 1200, height: 260)))
                fill(0xFFFFFF, oval(420, 600, 360, 90))
                fill(0xFFFFFF, UIBezierPath(roundedRect: CGRect(x: 480, y: 420, width: 240, height: 220), cornerRadius: 40))
                fill(0xC08A5A, oval(495, 420, 210, 50))
                UIColor(rgb: 0xFFFFFF).setStroke()
                let handle = oval(690, 470, 90, 110)
                handle.lineWidth = 24
                handle.stroke()
            case .night:
                gradient(0x141B33, 0x2D3A66, in: full)
                for (x, h) in [(40, 360), (190, 520), (340, 300), (480, 600), (640, 420), (800, 560), (960, 380)] as [(CGFloat, CGFloat)] {
                    fill(0x0D1222, UIBezierPath(rect: CGRect(x: x, y: 900 - h, width: 130, height: h)))
                    for row in stride(from: 900 - h + 30, to: 880, by: 60) {
                        for column in stride(from: x + 20, to: x + 110, by: 40) where Int(row + column) % 3 != 0 {
                            fill(0xF2D77A, UIBezierPath(rect: CGRect(x: column, y: row, width: 16, height: 22)))
                        }
                    }
                }
                fill(0xF4EFD8, oval(950, 90, 110, 110))
            }
        }
    }
}
#endif
