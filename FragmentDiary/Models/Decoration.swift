import Foundation

/// A sticker placed on a photo or drawing. Position and size are relative to the canvas so they survive any screen size.
nonisolated struct Sticker: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var content: String
    var isWord: Bool
    /// Center, as a fraction of the canvas width and height.
    var x: Double
    var y: Double
    var scale: Double
    var rotation: Double
}

/// The editable layers behind a decorated photo or drawing page, kept so it can be reopened and changed later.
nonisolated struct DecorationLayers: Codable, Sendable {
    /// PencilKit strokes in canvas coordinates (`DecorationCanvas.logicalWidth` wide).
    var drawing: Data
    var stickers: [Sticker]
    var aspectRatio: Double
}

nonisolated enum StickerLibrary {
    static let emoji = ["❤️", "⭐️", "✨", "🌸", "🍀", "☀️", "🌈", "☁️", "🎈", "🎀", "🐶", "🐱", "🍰", "☕️", "🍓", "🎵", "😊", "😆", "🥹", "😴", "👍", "🔥", "💌", "📌"]
    static let words = ["오늘", "행복", "최고!", "고마워", "기억할래", "또 가자", "냠냠", "휴식"]
}
