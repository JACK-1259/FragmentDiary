import SwiftUI

nonisolated enum Mood: Int, Codable, CaseIterable, Identifiable, Sendable {
    case heavy, low, calm, good, bright

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .heavy: "무거움"
        case .low: "가라앉음"
        case .calm: "잔잔함"
        case .good: "좋음"
        case .bright: "반짝임"
        }
    }

    var color: Color {
        switch self {
        case .heavy: Color(rgb: 0x5E6B75)
        case .low: Color(rgb: 0x86A0B4)
        case .calm: Color(rgb: 0x9DB08F)
        case .good: Color(rgb: 0xE2B660)
        case .bright: Color(rgb: 0xEE8A5E)
        }
    }
}

nonisolated enum FragmentKind: String, Codable, Sendable {
    case photos, event, note
}

nonisolated struct Fragment: Codable, Hashable, Identifiable, Sendable {
    var sourceID: String
    var kind: FragmentKind
    var start: Date
    var end: Date?
    var title: String?
    var place: String?
    var assetIDs: [String] = []
    var caption: String = ""

    var id: String { sourceID }

    var summaryLine: String {
        let base: String
        switch kind {
        case .photos:
            base = "사진 \(assetIDs.count)장"
        case .event:
            base = [title, place.map { "@ \($0)" }].compactMap { $0 }.joined(separator: " ")
        case .note:
            return caption
        }
        return caption.isEmpty ? base : "\(base) — \(caption)"
    }
}

nonisolated struct DiaryEntry: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var day: Date
    var mood: Mood?
    var note: String
    var quick: Bool
    var fragments: [Fragment]
    var createdAt: Date
    var updatedAt: Date

    var photoIDs: [String] { fragments.flatMap(\.assetIDs) }

    var isBackfilled: Bool { !Calendar.current.isDate(createdAt, inSameDayAs: day) }

    var previewText: String {
        if !note.isEmpty { return note }
        if let caption = fragments.map(\.caption).first(where: { !$0.isEmpty }) { return caption }
        return fragments.compactMap(\.title).joined(separator: " · ")
    }
}
