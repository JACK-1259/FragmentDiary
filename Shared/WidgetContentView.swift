import SwiftUI
import WidgetKit

nonisolated struct FragmentsEntry: TimelineEntry {
    let date: Date
    let fragmentCount: Int?
    let wrote: Bool
    let streak: Int
}

struct FragmentsWidgetView: View {
    let entry: FragmentsEntry
    /// Set only by the debug preview screen, which can't write the read-only `\.widgetFamily` key.
    var previewFamily: WidgetFamily?
    @Environment(\.widgetFamily) private var envFamily
    private let accent = AppTheme.current.accent

    private var family: WidgetFamily { previewFamily ?? envFamily }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: Text(inlineText)
        case .systemMedium: medium
        default: small
        }
    }

    private var countText: String {
        entry.fragmentCount.map(String.init) ?? "·"
    }

    private var statusText: String {
        if entry.wrote { return "오늘 기록 완료" }
        guard let count = entry.fragmentCount else { return "앱을 열면 조각이 모여요" }
        return count > 0 ? "30초면 기록 끝" : "한 줄만 남겨도 충분해요"
    }

    private var streakText: String? {
        entry.streak >= 2 ? "\(entry.streak)일째 이어가는 중" : nil
    }

    private var inlineText: String {
        if entry.wrote { return "조각일기 · 오늘 기록 완료" }
        if let count = entry.fragmentCount { return "조각일기 · 조각 \(count)개 모임" }
        return "조각일기"
    }

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(DateText.weekday(entry.date))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent)
            Text(DateText.day(entry.date))
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(Color.ink)
        }
    }

    @ViewBuilder
    private var countBlock: some View {
        if entry.wrote {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 34))
                .foregroundStyle(accent)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(countText)
                    .font(.system(size: 42, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.ink)
                    .contentTransition(.numericText())
                Text("조각")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.inkMuted)
            }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                dateHeader
                Spacer(minLength: 0)
                MiniNotebook()
            }
            Spacer(minLength: 4)
            countBlock
            Text(streakText.map { entry.wrote ? $0 : statusText } ?? statusText)
                .font(.caption2)
                .foregroundStyle(Color.inkMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                dateHeader
                Spacer(minLength: 4)
                countBlock
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 8) {
                MiniNotebook(scale: 1.6)
                    .padding(.top, 6)
                Spacer(minLength: 0)
                if let streakText {
                    Text(streakText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                }
                Text("일기 내용은 앱 안에만 있어요")
                    .font(.caption2)
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.wrote {
                Image(systemName: "checkmark")
                    .font(.title2.weight(.bold))
            } else {
                VStack(spacing: -2) {
                    Text(countText)
                        .font(.system(.title2, design: .serif, weight: .semibold))
                    Text("조각")
                        .font(.system(size: 10, weight: .medium))
                }
            }
        }
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("조각일기")
                .font(.headline)
                .widgetAccentable()
            Text(entry.wrote ? "오늘 기록 완료" : entry.fragmentCount.map { "오늘 조각 \($0)개" } ?? "오늘의 조각 모으는 중")
                .font(.subheadline)
            Text(streakText ?? statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The app icon — a spiral diary whose cover is a pastel 3x3 jigsaw — drawn small for widget corners.
/// Geometry is in the icon's 1024-unit space so it stays identical to the app icon.
struct MiniNotebook: View {
    var scale: CGFloat = 1

    private static let bounds = CGRect(x: 163, y: 140, width: 690, height: 840)
    private static let cover = CGRect(x: 205, y: 140, width: 630, height: 750)
    private static let coverRadius: CGFloat = 46
    private static let vTab = [[true, false], [false, true], [true, true]]
    private static let hTab = [[true, false, true], [false, true, false]]

    private static let pieces: [Color] = [
        Color(light: 0xFFC9B0, dark: 0xE8B29C), Color(light: 0xFFE3A0, dark: 0xE8CD8E), Color(light: 0xC7E8C0, dark: 0xAED0A8),
        Color(light: 0xF3B8C8, dark: 0xDCA2B2), Color(light: 0xFFFBF3, dark: 0xEDE6DA), Color(light: 0xB0E0D8, dark: 0x9CC9C1),
        Color(light: 0xFFD8BF, dark: 0xE8C2AA), Color(light: 0xB8D4EC, dark: 0xA3BDD6), Color(light: 0xD8C7EE, dark: 0xC2B1DA),
    ]
    private static let pages = Color(light: 0xFFF8EE, dark: 0x3A3348)
    private static let seam = Color(light: 0xFFFFFF, dark: 0x231E30)
    private static let rings = Color(light: 0x6B5E7A, dark: 0xB8AECB)
    private static let ribbon = Color(light: 0xE85D6F, dark: 0xE0677A)
    private static let title = Color(light: 0xC9B8A8, dark: 0x8E8070)

    var body: some View {
        let width = 28 * scale
        let height = width * Self.bounds.height / Self.bounds.width
        Canvas { context, size in
            let k = size.width / Self.bounds.width
            context.scaleBy(x: k, y: k)
            context.translateBy(x: -Self.bounds.minX, y: -Self.bounds.minY)
            draw(in: &context, unitsPerPoint: 1 / k)
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, unitsPerPoint: CGFloat) {
        let cover = Self.cover

        var ribbon = Path()
        ribbon.move(to: CGPoint(x: 690, y: 700))
        ribbon.addLines([CGPoint(x: 760, y: 700), CGPoint(x: 760, y: 980), CGPoint(x: 725, y: 945), CGPoint(x: 690, y: 980)])
        ribbon.closeSubpath()
        context.fill(ribbon, with: .color(Self.ribbon))

        context.fill(Path(roundedRect: cover.offsetBy(dx: 18, dy: 18), cornerRadius: Self.coverRadius), with: .color(Self.pages))

        let cw = cover.width / 3, ch = cover.height / 3
        let knob = min(cw, ch) * 0.2
        // Seams would vanish at widget size if scaled with the art, so they're held near one point wide.
        let seamWidth = max(10, unitsPerPoint * 0.9)
        context.drawLayer { layer in
            layer.clip(to: Path(roundedRect: cover, cornerRadius: Self.coverRadius))
            for r in 0..<3 {
                for c in 0..<3 {
                    let top: PuzzleEdge = r == 0 ? .flat : (Self.hTab[r - 1][c] ? .blank : .tab)
                    let left: PuzzleEdge = c == 0 ? .flat : (Self.vTab[r][c - 1] ? .blank : .tab)
                    let right: PuzzleEdge = c == 2 ? .flat : (Self.vTab[r][c] ? .tab : .blank)
                    let bottom: PuzzleEdge = r == 2 ? .flat : (Self.hTab[r][c] ? .tab : .blank)
                    let rect = CGRect(x: cover.minX + CGFloat(c) * cw, y: cover.minY + CGFloat(r) * ch, width: cw, height: ch)
                    let piece = puzzlePiece(rect, knob: knob, top: top, right: right, bottom: bottom, left: left)
                    layer.fill(piece, with: .color(Self.pieces[r * 3 + c]))
                    layer.stroke(piece, with: .color(Self.seam), lineWidth: seamWidth)
                }
            }
        }

        context.fill(Path(roundedRect: CGRect(x: cover.midX - 80, y: cover.midY - 30, width: 160, height: 20), cornerRadius: 10),
                     with: .color(Self.title))
        for i in 0..<6 {
            let y = cover.minY + 90 + CGFloat(i) * 118
            context.fill(Path(roundedRect: CGRect(x: cover.minX - 42, y: y, width: 96, height: 30), cornerRadius: 15),
                         with: .color(Self.rings))
        }
    }
}

private enum PuzzleEdge { case flat, tab, blank }

/// Arc direction is defined in path space: clockwise=false bulges outward (tab), true cuts inward (blank).
private func puzzlePiece(_ rect: CGRect, knob r: CGFloat, top: PuzzleEdge, right: PuzzleEdge, bottom: PuzzleEdge, left: PuzzleEdge) -> Path {
    let x0 = rect.minX, y0 = rect.minY, x1 = rect.maxX, y1 = rect.maxY, mx = rect.midX, my = rect.midY
    var p = Path()
    p.move(to: CGPoint(x: x0, y: y0))
    if top != .flat {
        p.addLine(to: CGPoint(x: mx - r, y: y0))
        p.addArc(center: CGPoint(x: mx, y: y0), radius: r, startAngle: .radians(.pi), endAngle: .radians(0), clockwise: top == .blank)
    }
    p.addLine(to: CGPoint(x: x1, y: y0))
    if right != .flat {
        p.addLine(to: CGPoint(x: x1, y: my - r))
        p.addArc(center: CGPoint(x: x1, y: my), radius: r, startAngle: .radians(-.pi / 2), endAngle: .radians(.pi / 2), clockwise: right == .blank)
    }
    p.addLine(to: CGPoint(x: x1, y: y1))
    if bottom != .flat {
        p.addLine(to: CGPoint(x: mx + r, y: y1))
        p.addArc(center: CGPoint(x: mx, y: y1), radius: r, startAngle: .radians(0), endAngle: .radians(.pi), clockwise: bottom == .blank)
    }
    p.addLine(to: CGPoint(x: x0, y: y1))
    if left != .flat {
        p.addLine(to: CGPoint(x: x0, y: my + r))
        p.addArc(center: CGPoint(x: x0, y: my), radius: r, startAngle: .radians(.pi / 2), endAngle: .radians(-.pi / 2), clockwise: left == .blank)
    }
    p.closeSubpath()
    return p
}
