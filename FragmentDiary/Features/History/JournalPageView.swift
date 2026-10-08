import SwiftUI

/// A saved day as one page of a spiral notebook: small prints and drawings stuck along the top,
/// answers and notes written on the ruled lines below — compact enough to read the day at a glance.
struct JournalPageView: View {
    let entry: DiaryEntry

    @Environment(JournalStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("pageResizeHintSeen") private var resizeHintSeen = false

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
                PrintFlow(spacing: 16) {
                    ForEach(Array(media.enumerated()), id: \.element.id) { index, fragment in
                        ResizablePrint(fragment: fragment, metrics: metrics, tilt: index.isMultiple(of: 2) ? -2 : 2) { scale in
                            resizeHintSeen = true
                            try? store.setPageScale(scale, for: fragment.id, in: entry.id)
                        }
                    }
                }
                .padding(.vertical, 12)
                if !resizeHintSeen {
                    Label("사진과 그림은 두 손가락으로 벌리거나 길게 눌러 크기를 바꿀 수 있어요", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .foregroundStyle(Self.muted)
                        .padding(.bottom, 6)
                }
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

    /// iPad pages have room to spare, so prints start larger there.
    private var metrics: PrintMetrics {
        sizeClass == .regular
            ? PrintMetrics(baseHeight: 190, maxHeight: 420, maxWidth: 600)
            : PrintMetrics(baseHeight: 118, maxHeight: 260, maxWidth: 300)
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

struct PrintMetrics {
    let baseHeight: CGFloat
    let maxHeight: CGFloat
    /// Wider than this and a print would run off the page, so its height is capped to fit.
    let maxWidth: CGFloat
    static let scaleRange: ClosedRange<Double> = 0.6...2.2

    func height(for scale: Double, widthPerHeight: CGFloat) -> CGFloat {
        min(baseHeight * CGFloat(scale), maxHeight, maxWidth / widthPerHeight)
    }

    /// Mirrors PhotoCollage's geometry: up to three tilted tiles, each overlapping the last.
    static func collageWidthPerHeight(photoCount: Int) -> CGFloat {
        let shown = CGFloat(min(max(photoCount, 1), 3))
        return shown == 1 ? 1.3 : 0.78 * (1 + 0.62 * (shown - 1))
    }
}

/// A photo or drawing on the page that the owner can pinch, or long-press, to make smaller or bigger.
private struct ResizablePrint: View {
    let fragment: Fragment
    let metrics: PrintMetrics
    let tilt: Double
    let onResize: (Double) -> Void

    @State private var pinch: CGFloat = 1

    private var savedScale: Double { fragment.pageScale ?? 1 }

    var body: some View {
        let live = min(max(savedScale * Double(pinch), PrintMetrics.scaleRange.lowerBound), PrintMetrics.scaleRange.upperBound)
        Group {
            if fragment.kind == .drawing {
                PinnedDrawing(fragment: fragment, height: metrics.height(for: live, widthPerHeight: DrawingDiary.aspectRatio))
            } else {
                TapedPrints(photos: fragment.photos, height: metrics.height(for: live, widthPerHeight: PrintMetrics.collageWidthPerHeight(photoCount: fragment.assetIDs.count)))
            }
        }
        .rotationEffect(.degrees(tilt))
        .contentShape(Rectangle())
        .gesture(
            MagnifyGesture()
                .onChanged { pinch = $0.magnification }
                .onEnded { _ in
                    onResize(live)
                    pinch = 1
                }
        )
        .contextMenu {
            Section("크기") {
                sizeButton("작게", 0.7)
                sizeButton("보통", 1)
                sizeButton("크게", 1.5)
                sizeButton("아주 크게", 2.2)
            }
        }
        .animation(.snappy, value: savedScale)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onResize(min(savedScale + 0.3, PrintMetrics.scaleRange.upperBound))
            case .decrement: onResize(max(savedScale - 0.3, PrintMetrics.scaleRange.lowerBound))
            @unknown default: break
            }
        }
    }

    private func sizeButton(_ title: String, _ scale: Double) -> some View {
        Button {
            onResize(scale)
        } label: {
            if abs(savedScale - scale) < 0.05 {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}

/// Lays prints out left to right, wrapping to a new row when one doesn't fit — each keeps its own size.
private struct PrintFlow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            // Rows are centered so a lone big print sits in the middle of the page.
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// A photo moment as overlapping prints with a strip of washi tape.
private struct TapedPrints: View {
    let photos: [PhotoRef]
    let height: CGFloat

    var body: some View {
        PhotoCollage(photos: photos, height: height)
            .overlay(alignment: .topLeading) {
                WashiTape(rgb: 0xF3B8C8)
                    .rotationEffect(.degrees(-28))
                    .offset(x: -12, y: 2)
            }
            .fixedSize()
    }
}

/// A drawing page stuck on like a note card.
private struct PinnedDrawing: View {
    let fragment: Fragment
    let height: CGFloat

    var body: some View {
        if let id = fragment.drawingID {
            JournalAttachmentImage(attachmentID: id)
                .aspectRatio(DrawingDiary.aspectRatio, contentMode: .fit)
                .frame(width: (height - 8) * DrawingDiary.aspectRatio, height: height - 8)
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
