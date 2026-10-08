import SwiftUI

/// A saved day as one page of a spiral notebook: small prints and drawings stuck along the top,
/// answers and notes written on the ruled lines below — compact enough to read the day at a glance.
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
            if !media.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 14)], spacing: 18) {
                    ForEach(Array(media.enumerated()), id: \.element.id) { index, fragment in
                        Group {
                            if fragment.kind == .drawing {
                                PinnedDrawing(fragment: fragment)
                            } else {
                                TapedPrints(photos: fragment.photos)
                            }
                        }
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -2 : 2))
                    }
                }
                .padding(.vertical, 10)
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HandLine(time: line.time, text: line.text)
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

    /// Photos and drawings, stuck on in the order they happened.
    private var media: [Fragment] {
        entry.fragments.filter { ($0.kind == .photos && !$0.assetIDs.isEmpty) || ($0.kind == .drawing && $0.drawingID != nil) }
    }

    /// Everything written: answers, notes and the captions of photos and drawings.
    private var lines: [(time: String?, text: String)] {
        entry.fragments.compactMap { fragment in
            let time = DateText.timelineLabel(for: fragment)
            switch fragment.kind {
            case .photos, .drawing, .note:
                return fragment.caption.isEmpty ? nil : (time, fragment.caption)
            case .event, .reminder:
                return (time, Self.sentence(for: fragment))
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

/// A photo moment as small overlapping prints with a strip of washi tape.
private struct TapedPrints: View {
    let photos: [PhotoRef]

    var body: some View {
        PhotoCollage(photos: photos, height: 118)
            .overlay(alignment: .topLeading) {
                WashiTape(rgb: 0xF3B8C8)
                    .rotationEffect(.degrees(-28))
                    .offset(x: -12, y: 2)
            }
            .frame(maxWidth: .infinity)
    }
}

/// A drawing page stuck on like a small note card.
private struct PinnedDrawing: View {
    let fragment: Fragment

    var body: some View {
        if let id = fragment.drawingID {
            JournalAttachmentImage(attachmentID: id)
                .aspectRatio(DrawingDiary.aspectRatio, contentMode: .fit)
                .padding(4)
                .background(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
                .overlay(alignment: .top) {
                    WashiTape(rgb: 0xB8D4EC).scaleEffect(0.8).offset(y: -8)
                }
                .overlay(alignment: .bottomTrailing) {
                    if let weather = fragment.weather {
                        Image(systemName: weather.symbol)
                            .font(.caption)
                            .foregroundStyle(weather.color)
                            .padding(6)
                    }
                }
                .frame(maxHeight: 118)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("그림")
        }
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
