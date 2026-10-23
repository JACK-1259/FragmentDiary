import SwiftUI

/// One photo moment or drawing as it sits on a notebook page, wherever it came from (journal or shared folder).
struct PagePrint: Identifiable {
    let id: String
    let isDrawing: Bool
    /// The photos of a moment, or the single image of a drawing.
    let images: [PhotoRef]
    /// A drawing page keeps its whole notebook frame: date, weather and the words in the squares.
    var day: Date = .now
    var weather: Weather?
    var caption: String = ""
    var x: Double?
    var y: Double?
    var scale: Double?
    var rotation: Double?
    var z: Double?
}

/// Where the user left a print: center as a fraction of the page width, size, and turn in degrees.
struct PagePlacement {
    let x: Double
    let y: Double
    let scale: Double
    let rotation: Double
}

/// A page line: an answer, a note, or a caption, with the time it belongs to.
struct PageLine {
    let time: String?
    let text: String
}

/// A day as one page of a spiral notebook: prints and drawings on a scrapbook area that can be rearranged
/// freely (when `onPlace` is given), and answers and notes written on the ruled lines below.
struct ScrapbookPage<Header: View>: View {
    let prints: [PagePrint]
    let lines: [PageLine]
    var leadNote: String?
    var trailNote: String?
    /// Nil makes the page read-only, e.g. someone else's post in a shared folder.
    var onPlace: ((String, PagePlacement) -> Void)?
    var onReset: (() -> Void)?
    @ViewBuilder var header: Header

    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("pageArrangeHintSeen") private var arrangeHintSeen = false

    private static var muted: Color { Color(rgb: 0x8A7F75) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let leadNote, !leadNote.isEmpty {
                HandLine(time: nil, text: leadNote, large: true)
            }
            if !prints.isEmpty {
                CollageBoard(prints: prints, baseHeight: baseHeight, onPlace: onPlace.map { place in
                    { id, placement in
                        arrangeHintSeen = true
                        place(id, placement)
                    }
                })
                .padding(.vertical, 12)
                if onPlace != nil {
                    HStack {
                        if !arrangeHintSeen {
                            Label("길게 눌러 끌면 옮겨지고, 두 손가락으로 크기와 방향을 바꿔요. 겹쳐도 돼요.", systemImage: "hand.draw")
                        }
                        Spacer(minLength: 0)
                        if let onReset, prints.contains(where: { $0.x != nil }) {
                            Button("자동 정렬", action: onReset)
                                .foregroundStyle(.tint)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Self.muted)
                    .padding(.bottom, 6)
                }
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HandLine(time: line.time, text: line.text)
            }
            if let trailNote, !trailNote.isEmpty {
                HandLine(time: nil, text: trailNote)
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
                .fill(Color(rgb: 0xFFFDF6))
                .shadow(color: .black.opacity(0.10), radius: 14, y: 6)
        )
        .overlay(alignment: .leading) { SpiralRings() }
        .environment(\.colorScheme, .light)
    }

    /// iPad pages have room to spare, so prints start larger there.
    private var baseHeight: CGFloat { sizeClass == .regular ? 190 : 118 }
}

/// A saved journal day on a notebook page; the owner can arrange its prints.
struct JournalPageView: View {
    let entry: DiaryEntry

    @Environment(JournalStore.self) private var store

    var body: some View {
        ScrapbookPage(
            prints: Self.prints(of: entry.fragments),
            lines: Self.lines(of: entry.fragments),
            leadNote: entry.quick ? entry.note : nil,
            trailNote: entry.quick ? nil : entry.note,
            onPlace: { id, placement in try? store.placeOnPage(id, in: entry.id, placement) },
            onReset: { try? store.resetPageLayout(of: entry.id) }
        ) {
            HStack(spacing: 8) {
                if let mood = entry.mood {
                    MoodChip(mood: mood, day: entry.day)
                }
                Spacer(minLength: 0)
                if entry.isBackfilled {
                    Text("나중에 채움")
                        .font(.caption)
                        .foregroundStyle(Color(rgb: 0x8A7F75))
                }
            }
            .padding(.bottom, entry.mood == nil && !entry.isBackfilled ? 0 : 14)
        }
    }

    /// Photos and drawings, stuck on in the order they happened.
    static func prints(of fragments: [Fragment]) -> [PagePrint] {
        fragments.compactMap { fragment in
            switch fragment.kind {
            case .photos where !fragment.assetIDs.isEmpty:
                PagePrint(id: fragment.id, isDrawing: false, images: fragment.photos, x: fragment.pageX, y: fragment.pageY, scale: fragment.pageScale, rotation: fragment.pageRotation, z: fragment.pageZ)
            case .drawing:
                fragment.drawingID.map {
                    PagePrint(
                        id: fragment.id, isDrawing: true, images: [.journal($0)], day: fragment.start, weather: fragment.weather, caption: fragment.caption,
                        x: fragment.pageX, y: fragment.pageY, scale: fragment.pageScale, rotation: fragment.pageRotation, z: fragment.pageZ
                    )
                }
            default: nil
            }
        }
    }

    /// Everything written: answers, notes and the captions of photos and drawings.
    static func lines(of fragments: [Fragment]) -> [PageLine] {
        fragments.compactMap { fragment in
            let time = DateText.timelineLabel(for: fragment)
            switch fragment.kind {
            // A drawing's words stay in its own squares, on the print.
            case .drawing:
                return nil
            case .photos, .note:
                return fragment.caption.isEmpty ? nil : PageLine(time: time, text: fragment.caption)
            case .event, .reminder:
                return PageLine(time: time, text: sentence(for: fragment))
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
    let prints: [PagePrint]
    let baseHeight: CGFloat
    let onPlace: ((String, PagePlacement) -> Void)?

    @State private var width: CGFloat = 0

    struct Placed: Identifiable {
        let fragment: PagePrint
        let index: Int
        let center: CGPoint
        let scale: Double
        var id: String { fragment.id }
    }

    var body: some View {
        let placed = width > 0 ? layout(width: width) : []
        let height = placed.map { item in
            let size = PrintGeometry.size(of: item.fragment, height: printHeight(item.fragment, item.scale))
            return item.center.y + PrintGeometry.turned(size, degrees: item.fragment.rotation ?? 2).height / 2
        }.max() ?? baseHeight
        ZStack(alignment: .topLeading) {
            ForEach(placed.sorted { ($0.fragment.z ?? Double($0.index)) < ($1.fragment.z ?? Double($1.index)) }) { item in
                CollagePrint(
                    fragment: item.fragment,
                    center: item.center,
                    scale: item.scale,
                    tilt: item.index.isMultiple(of: 2) ? -2 : 2,
                    boardWidth: width,
                    height: { scale in printHeight(item.fragment, scale) },
                    scaleRange: scaleRange(item.fragment),
                    onPlace: onPlace.map { place in
                        { center, scale, rotation in
                            place(item.fragment.id, PagePlacement(x: center.x / width, y: center.y / width, scale: scale, rotation: rotation))
                        }
                    }
                )
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

    private static let smallestHeight: CGFloat = 56

    /// Free sizing, limited only so a print can't vanish or outgrow the page.
    private func printHeight(_ fragment: PagePrint, _ scale: Double) -> CGFloat {
        let range = scaleRange(fragment)
        return baseHeight * CGFloat(min(max(scale, range.lowerBound), range.upperBound))
    }

    /// The scales that actually change the print's size. Pinching is clamped to these, so there's no dead zone
    /// where fingers move but the print doesn't (e.g. after over-stretching past the page width).
    private func scaleRange(_ fragment: PagePrint) -> ClosedRange<Double> {
        // Measured as turned: a tilted print takes more width than an upright one.
        let upright = PrintGeometry.size(of: fragment, height: baseHeight)
        let turned = PrintGeometry.turned(upright, degrees: fragment.rotation ?? 2)
        let widest = max(baseHeight * width / turned.width, Self.smallestHeight)
        return Double(Self.smallestHeight / baseHeight)...Double(widest / baseHeight)
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
                let fragment = prints[index]
                result.append(Placed(fragment: fragment, index: index, center: CGPoint(x: x + size.width / 2, y: y + rowHeight / 2), scale: fragment.scale ?? 1))
                x += size.width + spacing
            }
            y += rowHeight + spacing
            row = []
        }

        for (index, fragment) in prints.enumerated() where fragment.x == nil {
            let size = PrintGeometry.size(of: fragment, height: printHeight(fragment, fragment.scale ?? 1))
            let rowWidth = row.map(\.1.width).reduce(0, +) + spacing * CGFloat(row.count)
            if rowWidth + size.width > width { flush() }
            row.append((index, size))
        }
        flush()

        for (index, fragment) in prints.enumerated() {
            if let x = fragment.x, let y = fragment.y {
                result.append(Placed(fragment: fragment, index: index, center: CGPoint(x: x * width, y: y * width), scale: fragment.scale ?? 1))
            }
        }
        return result
    }
}

/// One print on the board: hold and drag to move it, pinch to resize it freely.
private struct CollagePrint: View {
    let fragment: PagePrint
    let center: CGPoint
    let scale: Double
    let tilt: Double
    let boardWidth: CGFloat
    let height: (Double) -> CGFloat
    let scaleRange: ClosedRange<Double>
    let onPlace: ((CGPoint, Double, Double) -> Void)?

    @State private var drag: CGSize = .zero
    @State private var pinch: CGFloat = 1
    @State private var twist: Angle = .zero
    @State private var lifted = false

    /// Starts from the size actually shown, so a pinch responds from its first movement.
    private var liveScale: Double {
        let start = min(max(scale, scaleRange.lowerBound), scaleRange.upperBound)
        return min(max(start * Double(pinch), scaleRange.lowerBound), scaleRange.upperBound)
    }

    /// The saved turn, or the gentle default tilt for prints never rotated.
    private var savedRotation: Double { fragment.rotation ?? tilt }

    private var liveRotation: Double {
        let degrees = (savedRotation + twist.degrees).truncatingRemainder(dividingBy: 360)
        // Settle within a couple of degrees of straight, so lining a print up square is easy.
        return abs(degrees) < 2 && twist != .zero ? 0 : degrees
    }

    var body: some View {
        let printHeight = height(liveScale)
        let size = PrintGeometry.size(of: fragment, height: printHeight)
        Group {
            if fragment.isDrawing, let image = fragment.images.first {
                PinnedDrawing(print: fragment, image: image, size: size)
            } else {
                TapedPrints(photos: fragment.images, height: printHeight)
            }
        }
        .frame(width: size.width, height: size.height)
        .rotationEffect(.degrees(liveRotation))
        .scaleEffect(lifted ? 1.04 : 1)
        .shadow(color: .black.opacity(lifted ? 0.22 : 0), radius: 14, y: 8)
        // A margin around small prints so both fingers of a pinch land on them.
        .padding(18)
        .contentShape(Rectangle())
        .padding(-18)
        .position(liveCenter(size: size))
        .gesture(move.simultaneously(with: transform), isEnabled: onPlace != nil)
        .zIndex(lifted || pinch != 1 || twist != .zero ? 1 : 0)
        .animation(.snappy(duration: 0.2), value: lifted)
        .sensoryFeedback(.impact(weight: .light), trigger: lifted) { _, new in new }
        .accessibilityElement(children: .combine)
        .accessibilityAdjustableAction { direction in
            guard onPlace != nil else { return }
            switch direction {
            case .increment: commit(scale: min(liveScale + 0.25, scaleRange.upperBound))
            case .decrement: commit(scale: max(liveScale - 0.25, scaleRange.lowerBound))
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

    /// Pinch and twist as one gesture, committed once when the fingers lift, so neither half
    /// overwrites the other with a stale value.
    private var transform: some Gesture {
        SimultaneousGesture(MagnifyGesture(), RotateGesture(minimumAngleDelta: .degrees(3)))
            .onChanged { value in
                pinch = value.first?.magnification ?? 1
                twist = value.second?.rotation ?? .zero
            }
            .onEnded { _ in
                commit(scale: liveScale)
                pinch = 1
                twist = .zero
            }
    }

    private func liveCenter(size: CGSize) -> CGPoint {
        clamped(CGPoint(x: center.x + drag.width, y: center.y + drag.height), size: PrintGeometry.turned(size, degrees: liveRotation))
    }

    /// Keeps the print, as turned, on the paper so it never covers the binding or spills off the page.
    private func clamped(_ point: CGPoint, size: CGSize) -> CGPoint {
        let x = size.width >= boardWidth ? boardWidth / 2 : min(max(point.x, size.width / 2), boardWidth - size.width / 2)
        return CGPoint(x: x, y: max(point.y, size.height / 2))
    }

    private func commit(scale: Double, offset: CGSize = .zero) {
        var scale = scale
        var size = PrintGeometry.turned(PrintGeometry.size(of: fragment, height: height(scale)), degrees: liveRotation)
        // Turning a big print can make it wider than the page; shrink it just enough to fit.
        if size.width > boardWidth {
            let fit = Double(boardWidth / size.width)
            scale *= fit
            size = CGSize(width: size.width * fit, height: size.height * fit)
        }
        let point = clamped(CGPoint(x: center.x + offset.width, y: center.y + offset.height), size: size)
        onPlace?(point, scale, liveRotation)
    }
}

enum PrintGeometry {
    /// Mirrors PhotoCollage's geometry: up to three tilted tiles, each overlapping the last.
    static func widthPerHeight(_ fragment: PagePrint) -> CGFloat {
        if fragment.isDrawing { return DrawingPrint.width / DrawingPrint.height }
        let shown = CGFloat(min(max(fragment.images.count, 1), 3))
        return shown == 1 ? 1.3 : 0.78 * (1 + 0.62 * (shown - 1))
    }

    /// The upright box a turned print occupies.
    static func turned(_ size: CGSize, degrees: Double) -> CGSize {
        let radians = degrees * .pi / 180
        let c = abs(cos(radians)), s = abs(sin(radians))
        return CGSize(width: size.width * c + size.height * s, height: size.width * s + size.height * c)
    }

    static func size(of fragment: PagePrint, height: CGFloat) -> CGSize {
        if fragment.isDrawing {
            return CGSize(width: height * widthPerHeight(fragment), height: height)
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

/// A drawing page as a print: the whole picture-diary page — date and weather on top, the picture,
/// and the words still sitting in their squares — laid out at one size and scaled, so it reads the same at any size.
private struct PinnedDrawing: View {
    let print: PagePrint
    let image: PhotoRef
    let size: CGSize

    var body: some View {
        NotebookPage(day: print.day, weather: print.weather, text: print.caption) {
            WholeImage(photo: image)
        }
        .frame(width: DrawingPrint.width, height: DrawingPrint.height)
        .scaleEffect(size.height / DrawingPrint.height, anchor: .topLeading)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
        .overlay(alignment: .top) {
            WashiTape(rgb: 0xB8D4EC).scaleEffect(0.8).offset(y: -8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(print.caption.isEmpty ? "그림일기" : "그림일기, \(print.caption)")
    }
}

/// The drawing page's layout size: header, picture box and four rows of squares at a fixed width.
enum DrawingPrint {
    static let width: CGFloat = 320
    static var height: CGFloat {
        40 + 1.5 + width / DrawingDiary.aspectRatio + 1.5 + width * CGFloat(DrawingDiary.rows) / CGFloat(DrawingDiary.columns)
    }
}

/// A drawing shown uncropped, from the journal or from a shared folder.
private struct WholeImage: View {
    let photo: PhotoRef
    @Environment(FolderStore.self) private var folderStore

    var body: some View {
        switch photo {
        case .journal(let id):
            JournalAttachmentImage(attachmentID: id)
        case .attachment(let id):
            if let image = folderStore.thumbnail(for: id) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Color(rgb: DrawingDiary.paperRGB)
            }
        case .asset:
            PhotoRefThumbnail(photo: photo)
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
