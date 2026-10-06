import SwiftUI

/// The picture-diary notebook page: date and weather on top, the picture, then manuscript squares for a few words.
struct NotebookPage<Picture: View>: View {
    let day: Date
    let weather: Weather?
    let text: String
    var onSelectWeather: ((Weather?) -> Void)?
    var onTapText: (() -> Void)?
    @ViewBuilder var picture: Picture

    static var rule: Color { Color(rgb: 0xC9B9A6) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Self.rule).frame(height: 1.5)
            picture
                .aspectRatio(DrawingDiary.aspectRatio, contentMode: .fit)
                .background(Color(rgb: DrawingDiary.paperRGB))
            Rectangle().fill(Self.rule).frame(height: 1.5)
            ManuscriptGrid(text: text)
                .contentShape(Rectangle())
                .onTapGesture { onTapText?() }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text.isEmpty ? "글 칸, 비어 있음" : text)
                .accessibilityAddTraits(onTapText == nil ? [] : .isButton)
        }
        .background(Color(rgb: DrawingDiary.paperRGB))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Self.rule, lineWidth: 1.5))
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        HStack(spacing: 0) {
            // Narrow cards (e.g. inside the timeline) drop the year rather than truncating.
            ViewThatFits(in: .horizontal) {
                Text(DateText.full(day))
                Text("\(DateText.day(day)) \(DateText.shortWeekday(day))")
            }
            .font(.system(.subheadline, design: .serif, weight: .medium))
            .foregroundStyle(Color(rgb: 0x2A2420))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(Self.rule).frame(width: 1.5)
            HStack(spacing: 8) {
                Text("날씨")
                    .font(.footnote)
                    .foregroundStyle(Color(rgb: 0x8A7F75))
                    .fixedSize()
                ForEach(Weather.allCases) { option in
                    let isOn = weather == option
                    Image(systemName: option.symbol)
                        .font(.system(size: 15))
                        .foregroundStyle(isOn ? option.color : Color(rgb: 0xCFC6BA))
                        .scaleEffect(isOn ? 1.15 : 1)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard let onSelectWeather else { return }
                            withAnimation(.snappy) { onSelectWeather(isOn ? nil : option) }
                        }
                        .accessibilityLabel(option.label)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 40)
    }
}

/// 원고지 squares; each character takes one square, a line break jumps to the next row.
struct ManuscriptGrid: View {
    let text: String

    var body: some View {
        GeometryReader { proxy in
            let cell = proxy.size.width / CGFloat(DrawingDiary.columns)
            ZStack(alignment: .topLeading) {
                Path { path in
                    for column in 1..<DrawingDiary.columns {
                        let x = CGFloat(column) * cell
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    }
                    for row in 1..<DrawingDiary.rows {
                        let y = CGFloat(row) * cell
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                }
                .stroke(Color(rgb: 0xE2D4C2), lineWidth: 1)

                ForEach(DrawingDiary.layout(text)) { glyph in
                    Text(String(glyph.character))
                        .font(.system(size: cell * 0.6, weight: .regular, design: .serif))
                        .foregroundStyle(Color(rgb: 0x3B3029))
                        .frame(width: cell, height: cell)
                        .offset(x: CGFloat(glyph.column) * cell, y: CGFloat(glyph.row) * cell)
                }
            }
        }
        .aspectRatio(CGFloat(DrawingDiary.columns) / CGFloat(DrawingDiary.rows), contentMode: .fit)
    }
}

enum DrawingDiary {
    /// Same proportion as the picture box in a printed 그림일기 notebook.
    static let aspectRatio: CGFloat = 1000 / 720
    static let paperRGB: UInt32 = 0xFFFEFA
    static let columns = 12
    static let rows = 4

    struct Glyph: Identifiable {
        let id: Int
        let character: Character
        let row: Int
        let column: Int
    }

    static func layout(_ text: String) -> [Glyph] {
        var glyphs: [Glyph] = []
        var row = 0
        var column = 0
        for character in text {
            if character.isNewline {
                row += 1
                column = 0
            } else {
                if column == columns {
                    row += 1
                    column = 0
                }
                guard row < rows else { break }
                glyphs.append(Glyph(id: glyphs.count, character: character, row: row, column: column))
                column += 1
            }
            if row >= rows { break }
        }
        return glyphs
    }

    /// Trims text that wouldn't fit in the squares.
    static func fitting(_ text: String) -> String {
        guard let last = layout(text).last else { return text.filter { !$0.isNewline } }
        var count = 0
        var result = ""
        for character in text {
            if count > last.id && !character.isNewline { break }
            result.append(character)
            if !character.isNewline { count += 1 }
        }
        return result
    }

    static var capacity: Int { columns * rows }
}

/// A saved drawing page, read-only.
struct DrawingPageView: View {
    let fragment: Fragment
    let day: Date

    var body: some View {
        NotebookPage(day: day, weather: fragment.weather, text: fragment.caption) {
            if let id = fragment.drawingID {
                JournalAttachmentImage(attachmentID: id)
            }
        }
    }
}

/// A sealed journal image shown whole (not cropped), used for drawing pages.
struct JournalAttachmentImage: View {
    let attachmentID: UUID
    @Environment(JournalStore.self) private var store

    var body: some View {
        if let image = store.attachmentImage(attachmentID) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("그림")
        } else {
            Color(rgb: DrawingDiary.paperRGB)
        }
    }
}
