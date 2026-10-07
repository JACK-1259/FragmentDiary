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

/// Where a displayed image comes from: the photo library, a shared-folder copy, or a sealed journal attachment (decorated photo or drawing).
nonisolated enum PhotoRef: Hashable, Sendable {
    case asset(String)
    case attachment(UUID)
    case journal(UUID)

    var seed: String {
        switch self {
        case .asset(let id): id
        case .attachment(let id), .journal(let id): id.uuidString
        }
    }
}

nonisolated enum FragmentKind: String, Codable, Sendable {
    case photos, event, note, drawing, reminder

    /// Calendar events and finished reminders are asked about rather than shown as-is.
    var isQuestion: Bool { self == .event || self == .reminder }
}

nonisolated enum Weather: String, Codable, CaseIterable, Identifiable, Sendable {
    case sunny, cloudy, rainy, snowy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sunny: "맑음"
        case .cloudy: "흐림"
        case .rainy: "비"
        case .snowy: "눈"
        }
    }

    var symbol: String {
        switch self {
        case .sunny: "sun.max.fill"
        case .cloudy: "cloud.fill"
        case .rainy: "cloud.rain.fill"
        case .snowy: "snowflake"
        }
    }

    var color: Color {
        switch self {
        case .sunny: Color(rgb: 0xF2B33D)
        case .cloudy: Color(rgb: 0x9AA6B2)
        case .rainy: Color(rgb: 0x6E9BD1)
        case .snowy: Color(rgb: 0x8CC4E0)
        }
    }
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
    /// A drawing page's sealed attachment (rendered image + editable strokes).
    var drawingID: UUID?
    var weather: Weather?
    /// Photos the user decorated, keyed by library asset ID. The value is a sealed attachment that replaces the original on display.
    var decorations: [String: UUID]?
    /// A one-tap answer to a question card, e.g. "😌 후련해".
    var reaction: String?

    var id: String { sourceID }

    var isAnswered: Bool { reaction != nil || !caption.trimmed.isEmpty }

    var photos: [PhotoRef] {
        assetIDs.map { assetID in decorations?[assetID].map(PhotoRef.journal) ?? .asset(assetID) }
    }

    /// Every sealed attachment this fragment owns, so they can be cleaned up when it goes away.
    var attachmentIDs: [UUID] {
        [drawingID].compactMap { $0 } + (decorations.map { Array($0.values) } ?? [])
    }

    var summaryLine: String {
        let base: String
        switch kind {
        case .photos:
            let decorated = decorations?.isEmpty == false ? " (꾸밈)" : ""
            base = "사진 \(assetIDs.count)장\(decorated)"
        case .event:
            base = [title, place.map { "@ \($0)" }].compactMap { $0 }.joined(separator: " ")
        case .note:
            return caption
        case .drawing:
            base = ["그림일기", weather.map { "날씨 \($0.label)" }].compactMap { $0 }.joined(separator: " · ")
        case .reminder:
            base = "끝낸 일: \(title ?? "")"
        }
        let answer = [reaction, caption.isEmpty ? nil : caption].compactMap { $0 }.joined(separator: " ")
        return answer.isEmpty ? base : "\(base) — \(answer)"
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

    /// Thumbnails for list rows: drawings first, then (decorated) photos.
    var previewPhotos: [PhotoRef] {
        fragments.compactMap { $0.drawingID.map(PhotoRef.journal) } + fragments.flatMap(\.photos)
    }

    var drawing: Fragment? { fragments.first { $0.kind == .drawing } }

    var attachmentIDs: Set<UUID> { Set(fragments.flatMap(\.attachmentIDs)) }

    var isBackfilled: Bool { !Calendar.current.isDate(createdAt, inSameDayAs: day) }

    var previewText: String {
        if !note.isEmpty { return note }
        if let caption = fragments.map(\.caption).first(where: { !$0.isEmpty }) { return caption }
        return fragments.compactMap(\.title).joined(separator: " · ")
    }
}
