import PencilKit
import UIKit

/// Flattens a base (photo or blank paper), PencilKit strokes and stickers into one image for display and sharing.
enum DecorationRenderer {
    static func render(base: UIImage?, paper: UIColor, layers: DecorationLayers, outputWidth: CGFloat) -> UIImage {
        let size = CGSize(width: outputWidth, height: (outputWidth / layers.aspectRatio).rounded())
        let unit = outputWidth / DecorationCanvas.logicalWidth
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let bounds = CGRect(origin: .zero, size: size)
            paper.setFill()
            context.fill(bounds)
            base?.draw(in: aspectFill(base?.size ?? size, into: bounds))

            if let drawing = try? PKDrawing(data: layers.drawing) {
                let logical = CGRect(x: 0, y: 0, width: DecorationCanvas.logicalWidth, height: DecorationCanvas.logicalWidth / layers.aspectRatio)
                // PencilKit adapts ink to the current appearance; strokes were drawn on a light canvas.
                UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
                    drawing.image(from: logical, scale: unit).draw(in: bounds)
                }
            }

            for sticker in layers.stickers {
                draw(sticker, in: context.cgContext, canvas: size, unit: unit)
            }
        }
    }

    private static func aspectFill(_ imageSize: CGSize, into rect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
    }

    private static func draw(_ sticker: Sticker, in cg: CGContext, canvas: CGSize, unit: CGFloat) {
        cg.saveGState()
        cg.translateBy(x: sticker.x * canvas.width, y: sticker.y * canvas.height)
        cg.rotate(by: sticker.rotation)

        if sticker.isWord {
            let fontSize = StickerMetrics.wordFontSize * sticker.scale * unit
            var font = UIFont.systemFont(ofSize: fontSize, weight: .heavy)
            if let rounded = font.fontDescriptor.withDesign(.rounded) {
                font = UIFont(descriptor: rounded, size: fontSize)
            }
            let text = NSAttributedString(string: sticker.content, attributes: [.font: font, .foregroundColor: UIColor(rgb: StickerMetrics.wordInk)])
            let textSize = text.size()
            let pill = CGRect(
                x: -textSize.width / 2 - StickerMetrics.wordPaddingX * sticker.scale * unit,
                y: -textSize.height / 2 - StickerMetrics.wordPaddingY * sticker.scale * unit,
                width: textSize.width + 2 * StickerMetrics.wordPaddingX * sticker.scale * unit,
                height: textSize.height + 2 * StickerMetrics.wordPaddingY * sticker.scale * unit
            )
            let path = UIBezierPath(roundedRect: pill, cornerRadius: pill.height / 2)
            UIColor(rgb: StickerMetrics.wordPaper).setFill()
            path.fill()
            UIColor(rgb: StickerMetrics.wordInk).setStroke()
            path.lineWidth = max(1, 4 * sticker.scale * unit)
            path.stroke()
            text.draw(at: CGPoint(x: -textSize.width / 2, y: -textSize.height / 2))
        } else {
            let font = UIFont.systemFont(ofSize: StickerMetrics.emojiFontSize * sticker.scale * unit)
            let text = NSAttributedString(string: sticker.content, attributes: [.font: font])
            let textSize = text.size()
            text.draw(at: CGPoint(x: -textSize.width / 2, y: -textSize.height / 2))
        }
        cg.restoreGState()
    }
}
