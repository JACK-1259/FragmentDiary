import SwiftUI

/// A saved day as one page of a spiral notebook: photos taped in as prints, answers and notes
/// written on the ruled lines, drawings stuck on like notes — all in the order they happened.
struct JournalPageView: View {
    let entry: DiaryEntry

    private static let ink = Color(rgb: 0x2A2420)
    private static let muted = Color(rgb: 0x8A7F75)
    private static let rule = Color(rgb: 0xE6DCCD)
    private static let paper = Color(rgb: 0xFFFDF6)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if let mood = entry.mood {
                    MoodChip(mood: mood, day: entry.day)
                }
                Spacer(minLength: 0)
                if entry.isBackfilled {
                    Text("나중에 채움")
                        .font(.caption)
                        .foregroundStyle(Self.muted)
                }
            }
            .padding(.bottom, entry.mood == nil && !entry.isBackfilled ? 0 : 14)

            if entry.quick, !entry.note.isEmpty {
                HandLine(time: nil, text: entry.note, large: true)
            }
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                switch block {
                case .photos(let fragment):
                    TapedPrints(photos: fragment.photos, leading: index.isMultiple(of: 2))
                        .padding(.vertical, 14)
                case .drawing(let fragment):
                    PinnedDrawing(fragment: fragment, leading: !index.isMultiple(of: 2))
                        .padding(.vertical, 14)
                case .line(let time, let text):
                    HandLine(time: time, text: text)
                }
            }
            if !entry.quick, !entry.note.isEmpty {
                HandLine(time: nil, text: entry.note)
            }
            // A couple of empty ruled lines so the page reads as paper, not a card.
            ForEach(0..<2, id: \.self) { _ in
                HandLine(time: nil, text: " ")
            }
        }
        .padding(.leading, 30)
        .padding(.trailing, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 6, bottomTrailingRadius: 16, topTrailingRadius: 16, style: .continuous)
                .fill(Self.paper)
                .shadow(color: .black.opacity(0.10), radius: 14, y: 6)
        )
        .overlay(alignment: .leading) { SpiralRings() }
        .environment(\.colorScheme, .light)
    }

    enum Block {
        case photos(Fragment)
        case drawing(Fragment)
        case line(String?, String)
    }

    private var blocks: [Block] {
        entry.fragments.flatMap { fragment -> [Block] in
            let time = DateText.timelineLabel(for: fragment)
            switch fragment.kind {
            case .photos:
                return [.photos(fragment)] + (fragment.caption.isEmpty ? [] : [.line(time, fragment.caption)])
            case .drawing:
                return [.drawing(fragment)]
            case .note:
                return fragment.caption.isEmpty ? [] : [.line(time, fragment.caption)]
            case .event, .reminder:
                return [.line(time, Self.sentence(for: fragment))]
            }
        }
    }

    /// "팀 스탠드업 — 😊 좋았어 10분 만에 끝나서 좋았다"; unanswered older entries keep the plain title and place.
    static func sentence(for fragment: Fragment) -> String {
        let title = fragment.title ?? (fragment.kind == .reminder ? "할 일" : "일정")
        let subject = fragment.kind == .reminder ? "\(title) 끝" : title
        let answer = [fragment.reaction, fragment.caption.isEmpty ? nil : fragment.caption].compactMap { $0 }.joined(separator: " ")
        if !answer.isEmpty { return "\(subject) — \(answer)" }
        if let place = fragment.place { return "\(subject) @ \(place)" }
        return subject
    }
}

private struct HandLine: View {
    let time: String?
    let text: String
    var large = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let time {
                Text(time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color(rgb: 0x8A7F75))
                    .frame(width: 40, alignment: .leading)
            }
            Text(text)
                .font(.system(size: large ? 22 : 17, design: .serif))
                .foregroundStyle(Color(rgb: 0x3B3029))
                .lineSpacing(10)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 10)
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(rgb: 0xE6DCCD)).frame(height: 1)
        }
    }
}

/// Photos as prints with a strip of washi tape, sitting a little left or right like they were stuck in by hand.
private struct TapedPrints: View {
    let photos: [PhotoRef]
    let leading: Bool

    var body: some View {
        PhotoCollage(photos: photos, height: 190)
            .overlay(alignment: .topLeading) {
                WashiTape(rgb: 0xF3B8C8)
                    .rotationEffect(.degrees(-28))
                    .offset(x: -14, y: 2)
            }
            .rotationEffect(.degrees(leading ? -1.5 : 1.5))
            .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
    }
}

/// A drawing page stuck onto the notebook like a note card, with its caption written underneath.
private struct PinnedDrawing: View {
    let fragment: Fragment
    let leading: Bool

    var body: some View {
        VStack(alignment: leading ? .leading : .trailing, spacing: 8) {
            if let id = fragment.drawingID {
                JournalAttachmentImage(attachmentID: id)
                    .aspectRatio(DrawingDiary.aspectRatio, contentMode: .fit)
                    .padding(6)
                    .background(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    .overlay(alignment: .top) {
                        WashiTape(rgb: 0xB8D4EC).offset(y: -9)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if let weather = fragment.weather {
                            Image(systemName: weather.symbol)
                                .foregroundStyle(weather.color)
                                .padding(10)
                        }
                    }
                    .frame(maxWidth: 280)
                    .rotationEffect(.degrees(leading ? -2 : 2))
                    .accessibilityLabel("그림")
            }
            if !fragment.caption.isEmpty {
                Text(fragment.caption)
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(Color(rgb: 0x3B3029))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
    }
}

private struct WashiTape: View {
    let rgb: UInt32

    var body: some View {
        Rectangle()
            .fill(Color(rgb: rgb).opacity(0.78))
            .frame(width: 62, height: 18)
            .accessibilityHidden(true)
    }
}

/// The spiral binding down the left edge, as many rings as the page is tall.
private struct SpiralRings: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 26
            while y < size.height - 16 {
                let ring = Path(roundedRect: CGRect(x: 0, y: y, width: 26, height: 10), cornerRadius: 5)
                context.fill(ring, with: .color(Color(rgb: 0x6B5E7A)))
                y += 46
            }
        }
        .frame(width: 26)
        .offset(x: -10)
        .accessibilityHidden(true)
    }
}
