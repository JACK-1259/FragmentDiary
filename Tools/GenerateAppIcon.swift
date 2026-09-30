// Renders the app icon (light, dark, tinted) into the asset catalog.
// Usage: swift Tools/GenerateAppIcon.swift [output-directory]
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func col(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

enum Edge { case flat, tab, blank }

/// Arc direction is defined in path space: clockwise=false bulges outward (tab), true cuts inward (blank).
func piecePath(w: CGFloat, h: CGFloat, r: CGFloat, top: Edge, right: Edge, bottom: Edge, left: Edge) -> CGPath {
    let p = CGMutablePath()
    p.move(to: .zero)
    if top != .flat {
        p.addLine(to: CGPoint(x: w / 2 - r, y: 0))
        p.addArc(center: CGPoint(x: w / 2, y: 0), radius: r, startAngle: .pi, endAngle: 0, clockwise: top == .blank)
    }
    p.addLine(to: CGPoint(x: w, y: 0))
    if right != .flat {
        p.addLine(to: CGPoint(x: w, y: h / 2 - r))
        p.addArc(center: CGPoint(x: w, y: h / 2), radius: r, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: right == .blank)
    }
    p.addLine(to: CGPoint(x: w, y: h))
    if bottom != .flat {
        p.addLine(to: CGPoint(x: w / 2 + r, y: h))
        p.addArc(center: CGPoint(x: w / 2, y: h), radius: r, startAngle: 0, endAngle: .pi, clockwise: bottom == .blank)
    }
    p.addLine(to: CGPoint(x: 0, y: h))
    if left != .flat {
        p.addLine(to: CGPoint(x: 0, y: h / 2 + r))
        p.addArc(center: CGPoint(x: 0, y: h / 2), radius: r, startAngle: .pi / 2, endAngle: -.pi / 2, clockwise: left == .blank)
    }
    p.closeSubpath()
    return p
}

func fillPath(_ ctx: CGContext, _ path: CGPath, _ fill: UInt32, stroke: UInt32? = nil, width: CGFloat = 0) {
    ctx.addPath(path); ctx.setFillColor(col(fill)); ctx.fillPath()
    if let stroke { ctx.addPath(path); ctx.setStrokeColor(col(stroke)); ctx.setLineWidth(width); ctx.strokePath() }
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

struct Palette {
    var bg: UInt32
    var pages: UInt32
    var pieces: [UInt32]
    var seam: UInt32
    var titleLine: UInt32
    var subtitleLine: UInt32
    var rings: UInt32
    var ribbon: UInt32
}

/// A spiral diary whose cover is a pastel 3x3 jigsaw, with a bookmark ribbon.
func render(_ p: Palette, to url: URL) {
    let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.translateBy(x: 0, y: 1024); ctx.scaleBy(x: 1, y: -1)
    ctx.setFillColor(col(p.bg)); ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    let cover = CGRect(x: 205, y: 140, width: 630, height: 750)
    let radius: CGFloat = 46

    let ribbon = CGMutablePath()
    ribbon.move(to: CGPoint(x: 690, y: 700))
    ribbon.addLine(to: CGPoint(x: 760, y: 700))
    ribbon.addLine(to: CGPoint(x: 760, y: 980))
    ribbon.addLine(to: CGPoint(x: 725, y: 945))
    ribbon.addLine(to: CGPoint(x: 690, y: 980))
    ribbon.closeSubpath()
    fillPath(ctx, ribbon, p.ribbon)

    fillPath(ctx, rounded(cover.offsetBy(dx: 18, dy: 18), radius), p.pages)

    let rows = 3, cols = 3
    let vTab = [[true, false], [false, true], [true, true]]
    let hTab = [[true, false, true], [false, true, false]]
    let cw = cover.width / CGFloat(cols), ch = cover.height / CGFloat(rows)
    let knob = min(cw, ch) * 0.2
    ctx.saveGState()
    ctx.addPath(rounded(cover, radius)); ctx.clip()
    for r in 0..<rows {
        for c in 0..<cols {
            let top: Edge = r == 0 ? .flat : (hTab[r - 1][c] ? .blank : .tab)
            let left: Edge = c == 0 ? .flat : (vTab[r][c - 1] ? .blank : .tab)
            let right: Edge = c == cols - 1 ? .flat : (vTab[r][c] ? .tab : .blank)
            let bottom: Edge = r == rows - 1 ? .flat : (hTab[r][c] ? .tab : .blank)
            ctx.saveGState()
            ctx.translateBy(x: cover.minX + CGFloat(c) * cw, y: cover.minY + CGFloat(r) * ch)
            fillPath(ctx, piecePath(w: cw, h: ch, r: knob, top: top, right: right, bottom: bottom, left: left),
                     p.pieces[r * cols + c], stroke: p.seam, width: 10)
            ctx.restoreGState()
        }
    }
    ctx.restoreGState()

    fillPath(ctx, rounded(CGRect(x: cover.midX - 80, y: cover.midY - 30, width: 160, height: 20), 10), p.titleLine)
    fillPath(ctx, rounded(CGRect(x: cover.midX - 55, y: cover.midY + 12, width: 110, height: 16), 8), p.subtitleLine)

    for i in 0..<6 {
        let y = cover.minY + 90 + CGFloat(i) * 118
        fillPath(ctx, rounded(CGRect(x: cover.minX - 42, y: y, width: 96, height: 30), 15), p.rings)
    }

    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil); CGImageDestinationFinalize(d)
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1
              ? CommandLine.arguments[1]
              : "FragmentDiary/Assets.xcassets/AppIcon.appiconset")

render(Palette(bg: 0xDCD3F2, pages: 0xFFF8EE,
               pieces: [0xFFC9B0, 0xFFE3A0, 0xC7E8C0, 0xF3B8C8, 0xFFFBF3, 0xB0E0D8, 0xFFD8BF, 0xB8D4EC, 0xD8C7EE],
               seam: 0xFFFFFF, titleLine: 0xC9B8A8, subtitleLine: 0xDDD0C3, rings: 0x6B5E7A, ribbon: 0xE85D6F),
       to: out.appendingPathComponent("AppIcon.png"))

// Dark: deep plum background, the same pastels dimmed slightly so they don't glare, dark seams.
render(Palette(bg: 0x231E30, pages: 0x3A3348,
               pieces: [0xE8B29C, 0xE8CD8E, 0xAED0A8, 0xDCA2B2, 0xEDE6DA, 0x9CC9C1, 0xE8C2AA, 0xA3BDD6, 0xC2B1DA],
               seam: 0x231E30, titleLine: 0x8E8070, subtitleLine: 0xB2A594, rings: 0xB8AECB, ribbon: 0xE0677A),
       to: out.appendingPathComponent("AppIcon-Dark.png"))

// Tinted: grayscale on black; iOS applies the user's tint over the luminance.
render(Palette(bg: 0x000000, pages: 0x3A3A3A,
               pieces: [0xB8B8B8, 0xD6D6D6, 0xC8C8C8, 0xAEAEAE, 0xF0F0F0, 0xC2C2C2, 0xCCCCCC, 0xBDBDBD, 0xB3B3B3],
               seam: 0x000000, titleLine: 0x8A8A8A, subtitleLine: 0xA8A8A8, rings: 0x6E6E6E, ribbon: 0x9A9A9A),
       to: out.appendingPathComponent("AppIcon-Tinted.png"))
print("done")
