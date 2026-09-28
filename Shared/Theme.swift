import SwiftUI
import UIKit

extension Color {
    static let paper = Color(light: 0xF7F3EC, dark: 0x171412)
    static let card = Color(light: 0xFFFDF9, dark: 0x221E1B)
    static let ink = Color(light: 0x2A2420, dark: 0xEFE8DF)
    static let inkMuted = Color(light: 0x8A7F75, dark: 0x9A8F86)
    static let hairline = Color(light: 0xE4DBCF, dark: 0x352F2A)
    /// Same values as the app's AccentColor asset, for targets that don't ship that catalog.
    static let terracotta = Color(light: 0xC1552C, dark: 0xE27A52)

    nonisolated init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    nonisolated init(rgb: UInt32) {
        self.init(uiColor: UIColor(rgb: rgb))
    }
}

extension UIColor {
    nonisolated convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum DateText {
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = format
        return formatter
    }

    private static let dayFormatter = formatter("M월 d일")
    private static let weekdayFormatter = formatter("EEEE")
    private static let shortWeekdayFormatter = formatter("E")
    private static let dayNumberFormatter = formatter("d")
    private static let timeFormatter = formatter("HH:mm")
    private static let monthFormatter = formatter("yyyy년 M월")
    private static let fullFormatter = formatter("yyyy년 M월 d일 (E)")

    static func day(_ date: Date) -> String { dayFormatter.string(from: date) }
    static func weekday(_ date: Date) -> String { weekdayFormatter.string(from: date) }
    static func shortWeekday(_ date: Date) -> String { shortWeekdayFormatter.string(from: date) }
    static func dayNumber(_ date: Date) -> String { dayNumberFormatter.string(from: date) }
    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }
    static func month(_ date: Date) -> String { monthFormatter.string(from: date) }
    static func full(_ date: Date) -> String { fullFormatter.string(from: date) }

    static func relativeDay(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInYesterday(date) { return "어제" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: .now)).day
        if days == 2 { return "그저께" }
        return "\(day(date)) \(weekday(date))"
    }
}

nonisolated extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// Deterministic tilt so collage tiles don't jitter between renders (String.hashValue is seeded per launch).
nonisolated func stableAngle(for seed: String, maxDegrees: Double) -> Double {
    var hash: UInt64 = 1469598103934665603
    for byte in seed.utf8 {
        hash = (hash ^ UInt64(byte)) &* 1099511628211
    }
    return (Double(hash % 1000) / 999 * 2 - 1) * maxDegrees
}
