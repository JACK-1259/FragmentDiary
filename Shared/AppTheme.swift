import SwiftUI
import UIKit

nonisolated enum ThemePreset: String, CaseIterable, Identifiable, Sendable {
    case terracotta, sage, indigo, wine, mustard, ink

    var id: String { rawValue }

    var name: String {
        switch self {
        case .terracotta: "벽돌색"
        case .sage: "쑥색"
        case .indigo: "쪽빛"
        case .wine: "자주색"
        case .mustard: "겨자색"
        case .ink: "먹색"
        }
    }

    var lightRGB: UInt32 {
        switch self {
        case .terracotta: 0xC1552C
        case .sage: 0x5F7F57
        case .indigo: 0x3E5C8A
        case .wine: 0x8E3048
        case .mustard: 0xA8741A
        case .ink: 0x3B3632
        }
    }

    var darkRGB: UInt32 {
        switch self {
        case .terracotta: 0xE27A52
        case .sage: 0x9DB890
        case .indigo: 0x8FA9D6
        case .wine: 0xD9798F
        case .mustard: 0xE2B660
        case .ink: 0xD9D0C5
        }
    }
}

/// The user-chosen accent. Stored in the App Group so the widget matches the app.
nonisolated enum AppTheme: Hashable, Sendable {
    case preset(ThemePreset)
    case custom(UInt32)

    static let storageKey = "themeColor"
    static let `default` = AppTheme.preset(.terracotta)

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: WidgetSnapshot.appGroup) ?? .standard
    }

    static var current: AppTheme {
        AppTheme(storageValue: sharedDefaults.string(forKey: storageKey) ?? AppTheme.default.storageValue)
    }

    init(storageValue: String) {
        if let preset = ThemePreset(rawValue: storageValue) {
            self = .preset(preset)
        } else if storageValue.hasPrefix("#"), let rgb = UInt32(storageValue.dropFirst(), radix: 16) {
            self = .custom(rgb)
        } else {
            self = .default
        }
    }

    var storageValue: String {
        switch self {
        case .preset(let preset): preset.rawValue
        case .custom(let rgb): String(format: "#%06X", rgb)
        }
    }

    private var rgbPair: (light: UInt32, dark: UInt32) {
        switch self {
        case .preset(let preset): (preset.lightRGB, preset.darkRGB)
        case .custom(let rgb):
            (Self.ensureContrast(rgb, against: Self.paperLight, toward: 0x000000),
             Self.ensureContrast(rgb, against: Self.paperDark, toward: 0xFFFFFF))
        }
    }

    var accentUIColor: UIColor {
        let pair = rgbPair
        return UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? pair.dark : pair.light)
        }
    }

    var accent: Color { Color(uiColor: accentUIColor) }

    /// Whichever of white or ink reads better on the accent, per appearance.
    var onAccent: Color {
        let pair = rgbPair
        return Color(uiColor: UIColor { traits in
            UIColor(rgb: Self.readableText(on: traits.userInterfaceStyle == .dark ? pair.dark : pair.light))
        })
    }

    private static let white: UInt32 = 0xFFFFFF
    private static let ink: UInt32 = 0x221E1B

    static func readableText(on rgb: UInt32) -> UInt32 {
        contrast(rgb, white) >= contrast(rgb, ink) ? white : ink
    }

    private static let paperLight: UInt32 = 0xF7F3EC
    private static let paperDark: UInt32 = 0x171412
    /// The accent doubles as text and icon color, so it needs the WCAG 3:1 minimum for large text and UI against the paper.
    private static let minimumContrast = 3.0

    /// Mixes a custom color toward black (light mode) or white (dark mode) just enough to stay legible on the paper.
    private static func ensureContrast(_ rgb: UInt32, against background: UInt32, toward target: UInt32) -> UInt32 {
        var mixed = rgb
        var step = 0
        while contrast(mixed, background) < minimumContrast && step < 20 {
            step += 1
            mixed = mix(rgb, target, amount: Double(step) / 20)
        }
        return mixed
    }

    private static func mix(_ a: UInt32, _ b: UInt32, amount: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let from = Double((a >> shift) & 0xFF), to = Double((b >> shift) & 0xFF)
            return UInt32((from + (to - from) * amount).rounded()) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }

    private static func luminance(_ rgb: UInt32) -> Double {
        func linear(_ channel: UInt32) -> Double {
            let value = Double(channel) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear((rgb >> 16) & 0xFF) + 0.7152 * linear((rgb >> 8) & 0xFF) + 0.0722 * linear(rgb & 0xFF)
    }

    private static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
