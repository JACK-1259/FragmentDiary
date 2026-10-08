import SwiftUI

/// A saved day as one page of a spiral notebook: prints and drawings stuck on a scrapbook area the user
/// can rearrange freely, answers and notes written on the ruled lines below.
struct JournalPageView: View {
    let entry: DiaryEntry

    @Environment(JournalStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("pageArrangeHintSeen") private var arrangeHintSeen = false

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
                CollageBoard(media: media, baseHeight: baseHeight) { fragment, x, y, scale in
                    arrangeHintSeen = true
                    try? store.placeOnPage(fragment.id, in: entry.id, x: x, y: y, scale: scale)
                }
                .padding(.vertical, 12)
                HStack {
                    if !arrangeHintSeen {
                        Label("길게 눌러 끌면 옮겨지고, 두 손가락으로 크기를 바꿔요. 겹쳐도 돼요.", systemImage: "hand.draw")
                    }
                    Spacer(minLength: 0)
                    if media.contains(where: { $0.pageX != nil }) {
                        Button("자동 정렬") { try? store.resetPageLayout(of: entry.id) }
                            .foregroundStyle(.tint)
                    }
                }
                .font(.caption)
                .foregroundStyle(Self.muted)
                .padding(.bottom, 6)
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
    private var baseHeight: CGFloat { sizeClass == .regular ? 190 : 118 }

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

/// The scrapbook area of the page. Prints the user hasn't touched flow in rows; once moved, a print keeps
/// its own spot, size and stacking order, so photos and drawings can overlap like a real collage.
private struct CollageBoard: View {
    let media: [Fragment]
    let baseHeight: CGFloat
    let onPlace: (Fragment, Double, Double, Double) -> Void

    @State private var width: CGFloat = 0

    struct Placed: Identifiable {
        let fragment: Fragment
        let index: Int
        let center: CGPoint
        let scale: Double
        var id: String { fragment.id }
    }

    var body: some View {
        let placed = width > 0 ? layout(width: width) : []
        let height = placed.map { $0.center.y + PrintGeometry.size(of: $0.fragment, height: printHeight($0.fragment, $0.scale)).height / 2 }.max() ?? baseHeight
        ZStack(alignment: .topLeading) {
            ForEach(placed.sorted { ($0.fragment.pageZ ?? Double($0.index)) < ($1.fragment.pageZ ?? Double($1.index)) }) { item in
                CollagePrint(
                    fragment: item.fragment,
                    center: item.center,
                    scale: item.scale,
                    tilt: item.index.isMultiple(of: 2) ? -2 : 2,
                    boardWidth: width,
                    height: { scale in printHeight(item.fragment, scale) }
                ) { center, scale in
                    onPlace(item.fragment, center.x / width, center.y / width, scale)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: height + 10)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, new in width = new }
            }
        }
    }

    /// Free sizing, limited only so a print can't vanish or outgrow the page.
    private func printHeight(_ fragment: Fragment, _ scale: Double) -> CGFloat {
        let wanted = baseHeight * CGFloat(scale)
        let widest = width / PrintGeometry.widthPerHeight(fragment)
        return min(max(wanted, 48), max(widest, 48))
    }

    /// Untouched prints flow left to right in centered rows; moved ones keep their stored spot.
    private func layout(width: CGFloat) -> [Placed] {
        let spacing: CGFloat = 16
        var result: [Placed] = []
        var row: [(Int, CGSize)] = []
        var y: CGFloat = 0

        func flush() {
            guard !row.isEmpty else { return }
            let rowWidth = row.map(\.1.width).reduce(0, +) + spacing * CGFloat(row.count - 1)
            let rowHeight = row.map(\.1.height).max() ?? 0
            var x = (width - rowWidth) / 2
            for (index, size) in row {
                let fragment = media[index]
                result.append(Placed(fragment: fragment, index: index, center: CGPoint(x: x + size.width / 2, y: y + rowHeight / 2), scale: fragment.pageScale ?? 1))
                x += size.width + spacing
            }
            y += rowHeight + spacing
            row = []
        }

        for (index, fragment) in media.enumerated() where fragment.pageX == nil {
            let size = PrintGeometry.size(of: fragment, height: printHeight(fragment, fragment.pageScale ?? 1))
            let rowWidth = row.map(\.1.width).reduce(0, +) + spacing * CGFloat(row.count)
            if rowWidth + size.width > width { flush() }
            row.append((index, size))
        }
        flush()

        for (index, fragment) in media.enumerated() {
            if let x = fragment.pageX, let y = fragment.pageY {
                result.append(Placed(fragment: fragment, index: index, center: CGPoint(x: x * width, y: y * width), scale: fragment.pageScale ?? 1))
            }
        }
        return result
    }
}

/// One print on the board: hold and drag to move it, pinch to resize it freely.
private struct CollagePrint: View {
    let fragment: Fragment
    let center: CGPoint
    let scale: Double
    let tilt: Double
    let boardWidth: CGFloat
    let height: (Double) -> CGFloat
    let onPlace: (CGPoint, Double) -> Void

    @State private var drag: CGSize = .zero
    @State private var pinch: CGFloat = 1
    @State private var lifted = false

    private var liveScale: Double { min(max(scale * Double(pinch), 0.4), 4) }

    var body: some View {
        let printHeight = height(liveScale)
        let size = PrintGeometry.size(of: fragment, height: printHeight)
        Group {
            if fragment.kind == .drawing {
                PinnedDrawing(fragment: fragment, height: printHeight)
            } else {
                TapedPrints(photos: fragment.photos, height: printHeight)
            }
        }
        .frame(width: size.width, height: size.height)
        .rotationEffect(.degrees(tilt))
        .scaleEffect(lifted ? 1.04 : 1)
        .shadow(color: .black.opacity(lifted ? 0.22 : 0), radius: 14, y: 8)
        .contentShape(Rectangle())
        .position(x: liveX(width: size.width), y: max(center.y + drag.height, size.height / 2))
        .gesture(move.simultaneously(with: resize))
        .zIndex(lifted || pinch != 1 ? 1 : 0)
        .animation(.snappy(duration: 0.2), value: lifted)
        .sensoryFeedback(.impact(weight: .light), trigger: lifted) { _, new in new }
        .accessibilityElement(children: .combine)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: commit(scale: min(scale + 0.25, 4))
            case .decrement: commit(scale: max(scale - 0.25, 0.4))
            @unknown default: break
            }
        }
    }

    /// Holding first keeps a plain swipe free to scroll the page.
    private var move: some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onChanged { value in
                if case .second(true, let dragValue) = value {
                    lifted = true
                    drag = dragValue?.translation ?? .zero
                }
            }
            .onEnded { value in
                if case .second(true, let dragValue) = value {
                    let moved = dragValue?.translation ?? .zero
                    lifted = false
                    commit(scale: liveScale, offset: moved)
                    drag = .zero
                } else {
                    lifted = false
                }
            }
    }

    private var resize: some Gesture {
        MagnifyGesture()
            .onChanged { pinch = $0.magnification }
            .onEnded { _ in
                commit(scale: liveScale)
                pinch = 1
            }
    }

    private func liveX(width: CGFloat) -> CGFloat {
        guard width < boardWidth else { return boardWidth / 2 }
        return min(max(center.x + drag.width, width / 2), boardWidth - width / 2)
    }

    private func commit(scale: Double, offset: CGSize = .zero) {
        let size = PrintGeometry.size(of: fragment, height: height(scale))
        // Keep the print on the paper so it never covers the binding or spills off the page.
        let x = size.width >= boardWidth
            ? boardWidth / 2
            : min(max(center.x + offset.width, size.width / 2), boardWidth - size.width / 2)
        let y = max(center.y + offset.height, size.height / 2)
        onPlace(CGPoint(x: x, y: y), scale)
    }
}

enum PrintGeometry {
    /// Mirrors PhotoCollage's geometry: up to three tilted tiles, each overlapping the last.
    static func widthPerHeight(_ fragment: Fragment) -> CGFloat {
        if fragment.kind == .drawing { return DrawingDiary.aspectRatio }
        let shown = CGFloat(min(max(fragment.assetIDs.count, 1), 3))
        return shown == 1 ? 1.3 : 0.78 * (1 + 0.62 * (shown - 1))
    }

    static func size(of fragment: Fragment, height: CGFloat) -> CGSize {
        if fragment.kind == .drawing {
            return CGSize(width: (height - 8) * DrawingDiary.aspectRatio + 8, height: height)
        }
        return CGSize(width: (height - 16) * widthPerHeight(fragment) + 4, height: height)
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
