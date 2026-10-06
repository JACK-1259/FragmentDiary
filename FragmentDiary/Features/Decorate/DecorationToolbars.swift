import PencilKit
import SwiftUI

/// Everything an editor needs to decorate one surface: strokes, stickers and the active tools.
@Observable
final class DecorationSession {
    var drawing: PKDrawing
    var stickers: [Sticker]
    var selectedSticker: UUID?
    let tools = InkTools()
    let aspectRatio: CGFloat

    init(layers: DecorationLayers?, aspectRatio: CGFloat) {
        self.aspectRatio = CGFloat(layers?.aspectRatio ?? aspectRatio)
        drawing = layers.flatMap { try? PKDrawing(data: $0.drawing) } ?? PKDrawing()
        stickers = layers?.stickers ?? []
    }

    var isEmpty: Bool { drawing.strokes.isEmpty && stickers.isEmpty }

    var layers: DecorationLayers {
        DecorationLayers(drawing: drawing.dataRepresentation(), stickers: stickers, aspectRatio: Double(aspectRatio))
    }

    func add(_ content: String, isWord: Bool) {
        // Fan new stickers out a little so several taps don't stack exactly on top of each other.
        let step = Double(stickers.count % 5)
        let sticker = Sticker(id: UUID(), content: content, isWord: isWord, x: 0.5 + step * 0.06, y: 0.5 + step * 0.04, scale: 1, rotation: isWord ? -0.08 : 0)
        stickers.append(sticker)
        selectedSticker = sticker.id
    }
}

/// The drawing surface: a base layer, ink on top, stickers above that.
struct DecorationSurface<Base: View>: View {
    @Bindable var session: DecorationSession
    @ViewBuilder var base: Base

    var body: some View {
        ZStack {
            base
            InkCanvas(drawing: $session.drawing, aspectRatio: session.aspectRatio, tools: session.tools)
            StickerLayer(stickers: $session.stickers, selection: $session.selectedSticker, isEditing: session.tools.mode == .stickers)
        }
        .aspectRatio(session.aspectRatio, contentMode: .fit)
        .clipped()
    }
}

struct DecorationModePicker: View {
    @Bindable var tools: InkTools

    var body: some View {
        Picker("꾸미기 방식", selection: $tools.mode.animation(.snappy)) {
            Label("그리기", systemImage: "pencil.and.scribble").tag(InkTools.Mode.draw)
            Label("스티커", systemImage: "face.smiling").tag(InkTools.Mode.stickers)
        }
        .pickerStyle(.segmented)
    }
}

/// Brushes, colors, thickness and undo — compact enough to sit under the canvas on an iPhone.
struct InkToolbar: View {
    @Bindable var tools: InkTools

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(InkTools.Brush.allCases) { brush in
                    Button {
                        tools.brush = brush
                    } label: {
                        Image(systemName: brush.symbol)
                            .font(.system(size: 17, weight: .medium))
                            .frame(width: 40, height: 36)
                            .foregroundStyle(tools.brush == brush ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.ink))
                            .background(RoundedRectangle(cornerRadius: 10).fill(tools.brush == brush ? Color.hairline : .clear))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(brush.label)
                    .accessibilityAddTraits(tools.brush == brush ? .isSelected : [])
                }
                Spacer(minLength: 4)
                Button { tools.undo() } label: {
                    Image(systemName: "arrow.uturn.backward").frame(width: 36, height: 36)
                }
                .accessibilityLabel("되돌리기")
                Button { tools.redo() } label: {
                    Image(systemName: "arrow.uturn.forward").frame(width: 36, height: 36)
                }
                .accessibilityLabel("다시 하기")
            }
            .foregroundStyle(Color.ink)

            HStack(spacing: 0) {
                ForEach(InkTools.palette, id: \.self) { rgb in
                    let isSelected = tools.color == rgb && tools.brush != .eraser
                    Button {
                        tools.color = rgb
                        if tools.brush == .eraser { tools.brush = tools.brushBeforeEraser }
                    } label: {
                        Circle()
                            .fill(Color(rgb: rgb))
                            .overlay(Circle().stroke(Color.hairline, lineWidth: rgb == 0xFFFFFF ? 1 : 0))
                            .frame(width: 26, height: 26)
                            .overlay(Circle().stroke(Color.ink, lineWidth: isSelected ? 2 : 0).padding(-4))
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("색 \(String(format: "#%06X", rgb))")
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "circle.fill").font(.system(size: 6))
                Slider(value: $tools.width, in: 0.4...2.6)
                Image(systemName: "circle.fill").font(.system(size: 14))
            }
            .foregroundStyle(Color.inkMuted)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("굵기")
        }
    }
}

struct StickerTray: View {
    let onPick: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.fixed(44)), GridItem(.fixed(44))], spacing: 6) {
                    ForEach(StickerLibrary.emoji, id: \.self) { emoji in
                        Button { onPick(emoji, false) } label: {
                            Text(emoji)
                                .font(.system(size: 30))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StickerLibrary.words, id: \.self) { word in
                        Button { onPick(word, true) } label: {
                            Text(word)
                                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                .foregroundStyle(Color(rgb: StickerMetrics.wordInk))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color(rgb: StickerMetrics.wordPaper)))
                                .overlay(Capsule().stroke(Color(rgb: StickerMetrics.wordInk), lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            Text("스티커를 끌어서 옮기고, 두 손가락으로 크기와 방향을 바꿔요.")
                .font(.caption)
                .foregroundStyle(Color.inkMuted)
        }
    }
}

/// Toolbar area under a surface: mode switch, then either brushes or the sticker tray.
struct DecorationControls: View {
    let session: DecorationSession

    var body: some View {
        VStack(spacing: 14) {
            DecorationModePicker(tools: session.tools)
            switch session.tools.mode {
            case .draw: InkToolbar(tools: session.tools)
            case .stickers: StickerTray { content, isWord in session.add(content, isWord: isWord) }
            }
        }
    }
}
