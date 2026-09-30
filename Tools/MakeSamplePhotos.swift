// Makes sample JPEGs timestamped today for simulator testing.
// Usage: swift Tools/MakeSamplePhotos.swift <dir> && xcrun simctl addmedia booted <dir>/*.jpg
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Sample JPEGs with EXIF DateTimeOriginal set to times today, for simulator testing.
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

struct Shot { let hour: Int; let minute: Int; let top: (CGFloat, CGFloat, CGFloat); let bottom: (CGFloat, CGFloat, CGFloat) }
let shots: [Shot] = [
    Shot(hour: 8, minute: 42, top: (0.98, 0.84, 0.62), bottom: (0.85, 0.52, 0.34)),
    Shot(hour: 8, minute: 47, top: (0.95, 0.90, 0.80), bottom: (0.62, 0.45, 0.33)),
    Shot(hour: 12, minute: 31, top: (0.55, 0.78, 0.95), bottom: (0.30, 0.55, 0.38)),
    Shot(hour: 12, minute: 36, top: (0.62, 0.82, 0.96), bottom: (0.42, 0.62, 0.30)),
    Shot(hour: 12, minute: 58, top: (0.70, 0.86, 0.97), bottom: (0.55, 0.70, 0.45)),
    Shot(hour: 18, minute: 12, top: (0.98, 0.62, 0.40), bottom: (0.35, 0.22, 0.42)),
]

let calendar = Calendar.current
let today = calendar.startOfDay(for: Date())
let exif = DateFormatter()
exif.dateFormat = "yyyy:MM:dd HH:mm:ss"

for (index, shot) in shots.enumerated() {
    let width = 1200, height = 1500
    let space = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let colors = [CGColor(red: shot.top.0, green: shot.top.1, blue: shot.top.2, alpha: 1),
                  CGColor(red: shot.bottom.0, green: shot.bottom.1, blue: shot.bottom.2, alpha: 1)] as CFArray
    ctx.drawLinearGradient(CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!,
                           start: CGPoint(x: 0, y: CGFloat(height)), end: .zero, options: [])
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.35))
    ctx.fillEllipse(in: CGRect(x: 200 + index * 90, y: 700 + (index % 3) * 120, width: 420, height: 420))
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.12))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: 380 + index * 20))

    let date = calendar.date(bySettingHour: shot.hour, minute: shot.minute, second: 0, of: today)!
    let url = outDir.appendingPathComponent(String(format: "sample_%02d.jpg", index))
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
    let props: [CFString: Any] = [
        kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: exif.string(from: date),
                                         kCGImagePropertyExifDateTimeDigitized: exif.string(from: date)],
        kCGImageDestinationLossyCompressionQuality: 0.85,
    ]
    CGImageDestinationAddImage(dest, ctx.makeImage()!, props as CFDictionary)
    CGImageDestinationFinalize(dest)
}
print("done")
