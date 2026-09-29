import SwiftUI

/// The puzzle-cover spiral diary shared by the app icon, widget and in-app art.
/// Geometry is in the icon's 1024-unit space so every rendering matches the icon.
private enum Notebook {
    static let bounds = CGRect(x: 163, y: 140, width: 690, height: 840)
    static let cover = CGRect(x: 205, y: 140, width: 630, height: 750)
    static let coverRadius: CGFloat = 46

    static let pages = Color(light: 0xFFF8EE, dark: 0x3A3348)
    static let seam = Color(light: 0xFFFFFF, dark: 0x231E30)
    static let rings = Color(light: 0x6B5E7A, dark: 0xB8AECB)
    static let ribbon = Color(light: 0xE85D6F, dark: 0xE0677A)
}

/// Frame (ribbon, back pages, rings) around a cover the caller draws, clipped to the cover shape.
/// The cover closure gets a seam width in icon units that stays near one point at any size.
private struct NotebookCanvas: View {
    let width: CGFloat
    let drawCover: (inout GraphicsContext, CGFloat) -> Void

    var body: some View {
        Canvas { context, size in
            let k = size.width / Notebook.bounds.width
            context.scaleBy(x: k, y: k)
            context.translateBy(x: -Notebook.bounds.minX, y: -Notebook.bounds.minY)

            var ribbon = Path()
            ribbon.move(to: CGPoint(x: 690, y: 700))
            ribbon.addLines([CGPoint(x: 760, y: 700), CGPoint(x: 760, y: 980), CGPoint(x: 725, y: 945), CGPoint(x: 690, y: 980)])
            ribbon.closeSubpath()
            context.fill(ribbon, with: .color(Notebook.ribbon))
            context.fill(Path(roundedRect: Notebook.cover.offsetBy(dx: 18, dy: 18), cornerRadius: Notebook.coverRadius),
                         with: .color(Notebook.pages))

            let seamWidth = max(10, 0.9 / k)
            context.drawLayer { layer in
                layer.clip(to: Path(roundedRect: Notebook.cover, cornerRadius: Notebook.coverRadius))
                drawCover(&layer, seamWidth)
            }

            for i in 0..<6 {
                let y = Notebook.cover.minY + 90 + CGFloat(i) * 118
                context.fill(Path(roundedRect: CGRect(x: Notebook.cover.minX - 42, y: y, width: 96, height: 30), cornerRadius: 15),
                             with: .color(Notebook.rings))
            }
        }
        .frame(width: width, height: width * Notebook.bounds.height / Notebook.bounds.width)
    }
}

/// The app icon itself: a pastel 3x3 jigsaw cover with a title label on the center piece.
struct MiniNotebook: View {
    var scale: CGFloat = 1

    private static let colors: [Color] = [
        Color(light: 0xFFC9B0, dark: 0xE8B29C), Color(light: 0xFFE3A0, dark: 0xE8CD8E), Color(light: 0xC7E8C0, dark: 0xAED0A8),
        Color(light: 0xF3B8C8, dark: 0xDCA2B2), Color(light: 0xFFFBF3, dark: 0xEDE6DA), Color(light: 0xB0E0D8, dark: 0x9CC9C1),
        Color(light: 0xFFD8BF, dark: 0xE8C2AA), Color(light: 0xB8D4EC, dark: 0xA3BDD6), Color(light: 0xD8C7EE, dark: 0xC2B1DA),
    ]
    private static let title = Color(light: 0xC9B8A8, dark: 0x8E8070)
    private static let subtitle = Color(light: 0xDDD0C3, dark: 0xB2A594)

    var body: some View {
        NotebookCanvas(width: 28 * scale) { layer, seam in
            for (i, piece) in PuzzleLayout.icon.pieces(in: Notebook.cover).enumerated() {
                layer.fill(piece, with: .color(Self.colors[i]))
                layer.stroke(piece, with: .color(Notebook.seam), lineWidth: seam)
            }
            let cover = Notebook.cover
            layer.fill(Path(roundedRect: CGRect(x: cover.midX - 80, y: cover.midY - 30, width: 160, height: 20), cornerRadius: 10),
                       with: .color(Self.title))
            layer.fill(Path(roundedRect: CGRect(x: cover.midX - 55, y: cover.midY + 12, width: 110, height: 16), cornerRadius: 8),
                       with: .color(Self.subtitle))
        }
        .accessibilityHidden(true)
    }
}

/// The diary with a seven-piece cover, Monday through Sunday; a day's piece fills in once it's written.
struct WeekNotebook: View {
    let days: [DayState]
    let accent: Color
    var width: CGFloat

    private static let colors: [Color] = [
        Color(light: 0xFFC9B0, dark: 0xE8B29C), Color(light: 0xFFE3A0, dark: 0xE8CD8E), Color(light: 0xC7E8C0, dark: 0xAED0A8),
        Color(light: 0xB0E0D8, dark: 0x9CC9C1), Color(light: 0xB8D4EC, dark: 0xA3BDD6), Color(light: 0xD8C7EE, dark: 0xC2B1DA),
        Color(light: 0xF3B8C8, dark: 0xDCA2B2),
    ]
    private static let emptyFill = Color(light: 0xFFF8EE, dark: 0x2E283A)
    private static let todayFill = Color(light: 0xFFF3EA, dark: 0x352E3F)
    private static let missedDash = Color(light: 0xB9A898, dark: 0x8A7F9A)
    private static let futureDash = Color(light: 0xDDD0C3, dark: 0x4F4760)

    var body: some View {
        NotebookCanvas(width: width) { layer, seam in
            let pieces = PuzzleLayout.week.pieces(in: Notebook.cover)
            let dash = [seam * 2.6, seam * 1.8]
            func state(_ i: Int) -> DayState { days.indices.contains(i) ? days[i] : .future }
            // Empty slots first so a written neighbor's seam is drawn over the dashes they share.
            for (i, piece) in pieces.enumerated() where state(i) != .written {
                switch state(i) {
                case .today:
                    layer.fill(piece, with: .color(Self.todayFill))
                    layer.stroke(piece, with: .color(accent), style: StrokeStyle(lineWidth: seam * 1.6, dash: dash))
                case .missed:
                    layer.fill(piece, with: .color(Self.emptyFill))
                    layer.stroke(piece, with: .color(Self.missedDash), style: StrokeStyle(lineWidth: seam * 1.3, dash: dash))
                default:
                    layer.fill(piece, with: .color(Self.emptyFill))
                    layer.stroke(piece, with: .color(Self.futureDash), style: StrokeStyle(lineWidth: seam * 1.3, dash: dash))
                }
            }
            for (i, piece) in pieces.enumerated() where state(i) == .written {
                layer.fill(piece, with: .color(Self.colors[i]))
                layer.stroke(piece, with: .color(Notebook.seam), lineWidth: seam)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("이번 주 \(days.filter { $0 == .written }.count)일 기록")
    }
}

/// Rows of pieces with a knob on every shared edge; each knob is a tab on one side and the matching blank on the other,
/// so the pieces tile the cover with no gaps.
struct PuzzleLayout {
    struct Knob {
        /// Along the seam, in icon units from the cover's left edge.
        let x: CGFloat
        let upperTab: Bool
    }

    var rows: [Int]
    /// [row][seam]: true when the left piece carries the tab.
    var vertical: [[Bool]]
    /// [boundary between row i and i+1]: knobs placed where both rows have a piece.
    var horizontal: [[Knob]]
    var knob: CGFloat

    static let icon = PuzzleLayout(
        rows: [3, 3, 3],
        vertical: [[true, false], [false, true], [true, true]],
        horizontal: [
            [Knob(x: 105, upperTab: true), Knob(x: 315, upperTab: false), Knob(x: 525, upperTab: true)],
            [Knob(x: 105, upperTab: false), Knob(x: 315, upperTab: true), Knob(x: 525, upperTab: false)],
        ],
        knob: 42)

    /// 월화 / 수목금 / 토일 — the weekend shares the bottom row.
    static let week = PuzzleLayout(
        rows: [2, 3, 2],
        vertical: [[true], [false, true], [true]],
        horizontal: [
            [Knob(x: 105, upperTab: true), Knob(x: 525, upperTab: false)],
            [Knob(x: 105, upperTab: false), Knob(x: 525, upperTab: true)],
        ],
        knob: 42)

    /// Piece outlines in reading order.
    func pieces(in cover: CGRect) -> [Path] {
        let rowHeight = cover.height / CGFloat(rows.count)
        let cells: [[CGRect]] = rows.enumerated().map { r, count in
            let w = cover.width / CGFloat(count)
            return (0..<count).map { CGRect(x: cover.minX + CGFloat($0) * w, y: cover.minY + CGFloat(r) * rowHeight, width: w, height: rowHeight) }
        }
        var edges = cells.map { $0.map { _ in PieceEdges() } }
        for r in cells.indices {
            for c in 0..<(cells[r].count - 1) {
                let y = cells[r][c].midY, leftTab = vertical[r][c]
                edges[r][c].right.append(.init(at: y, tab: leftTab))
                edges[r][c + 1].left.append(.init(at: y, tab: !leftTab))
            }
        }
        for (b, knobs) in horizontal.enumerated() {
            for knob in knobs {
                let x = cover.minX + knob.x
                guard let upper = cells[b].firstIndex(where: { $0.minX < x && x < $0.maxX }),
                      let lower = cells[b + 1].firstIndex(where: { $0.minX < x && x < $0.maxX }) else { continue }
                edges[b][upper].bottom.append(.init(at: x, tab: knob.upperTab))
                edges[b + 1][lower].top.append(.init(at: x, tab: !knob.upperTab))
            }
        }
        return cells.indices.flatMap { r in cells[r].indices.map { c in piecePath(cells[r][c], edges[r][c]) } }
    }

    private struct Feature { let at: CGFloat; let tab: Bool }
    private struct PieceEdges { var top: [Feature] = [], right: [Feature] = [], bottom: [Feature] = [], left: [Feature] = [] }

    /// Walks the outline clockwise. Arc direction is in path space: clockwise=false bulges out (tab), true cuts in (blank).
    private func piecePath(_ rect: CGRect, _ e: PieceEdges) -> Path {
        let r = knob, x0 = rect.minX, y0 = rect.minY, x1 = rect.maxX, y1 = rect.maxY
        var p = Path()
        p.move(to: CGPoint(x: x0, y: y0))
        for f in e.top.sorted(by: { $0.at < $1.at }) {
            p.addLine(to: CGPoint(x: f.at - r, y: y0))
            p.addArc(center: CGPoint(x: f.at, y: y0), radius: r, startAngle: .radians(.pi), endAngle: .radians(0), clockwise: !f.tab)
        }
        p.addLine(to: CGPoint(x: x1, y: y0))
        for f in e.right.sorted(by: { $0.at < $1.at }) {
            p.addLine(to: CGPoint(x: x1, y: f.at - r))
            p.addArc(center: CGPoint(x: x1, y: f.at), radius: r, startAngle: .radians(-.pi / 2), endAngle: .radians(.pi / 2), clockwise: !f.tab)
        }
        p.addLine(to: CGPoint(x: x1, y: y1))
        for f in e.bottom.sorted(by: { $0.at > $1.at }) {
            p.addLine(to: CGPoint(x: f.at + r, y: y1))
            p.addArc(center: CGPoint(x: f.at, y: y1), radius: r, startAngle: .radians(0), endAngle: .radians(.pi), clockwise: !f.tab)
        }
        p.addLine(to: CGPoint(x: x0, y: y1))
        for f in e.left.sorted(by: { $0.at > $1.at }) {
            p.addLine(to: CGPoint(x: x0, y: f.at + r))
            p.addArc(center: CGPoint(x: x0, y: f.at), radius: r, startAngle: .radians(.pi / 2), endAngle: .radians(-.pi / 2), clockwise: !f.tab)
        }
        p.closeSubpath()
        return p
    }
}
