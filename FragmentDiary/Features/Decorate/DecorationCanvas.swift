import PencilKit
import SwiftUI

/// Pen, colors and the current mode shared by the canvas and its toolbar.
@Observable
final class InkTools {
    enum Brush: CaseIterable, Identifiable {
        case pencil, crayon, marker, pen, eraser

        var id: Self { self }

        var label: String {
            switch self {
            case .pencil: "연필"
            case .crayon: "크레용"
            case .marker: "형광펜"
            case .pen: "펜"
            case .eraser: "지우개"
            }
        }

        var symbol: String {
            switch self {
            case .pencil: "pencil"
            case .crayon: "paintbrush.pointed.fill"
            case .marker: "highlighter"
            case .pen: "pencil.tip"
            case .eraser: "eraser"
            }
        }
    }

    enum Mode: Hashable {
        case draw, stickers
    }

    static let palette: [UInt32] = [0x2A2420, 0xE0705A, 0xF4C04E, 0x7DB36A, 0x6E9BD1, 0x9B7BD0, 0xF29BB8, 0xFFFFFF]

    var brush: Brush = .pencil
    var color: UInt32 = 0x2A2420
    var width: CGFloat = 1
    var mode: Mode = .draw
    /// The brush to return to when an Apple Pencil double-tap toggles the eraser off.
    var brushBeforeEraser: Brush = .pencil
    @ObservationIgnored weak var canvas: PKCanvasView?

    func undo() { canvas?.undoManager?.undo() }
    func redo() { canvas?.undoManager?.redo() }

    var tool: PKTool {
        let uiColor = UIColor(rgb: color)
        switch brush {
        case .pencil: return PKInkingTool(.pencil, color: uiColor, width: 6 * width)
        case .crayon: return PKInkingTool(.crayon, color: uiColor, width: 18 * width)
        case .marker: return PKInkingTool(.marker, color: uiColor, width: 26 * width)
        case .pen: return PKInkingTool(.pen, color: uiColor, width: 5 * width)
        case .eraser: return PKEraserTool(.bitmap, width: 28 * width)
        }
    }

    func toggleEraser() {
        if brush == .eraser {
            brush = brushBeforeEraser
        } else {
            brushBeforeEraser = brush
            brush = .eraser
        }
    }
}

enum DecorationCanvas {
    /// Strokes are recorded at this width no matter the screen, so a drawing reopens identically on iPhone and iPad.
    static let logicalWidth: CGFloat = 1000
}

/// A PencilKit canvas locked to a fixed logical size and scaled to fit its frame.
struct InkCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let aspectRatio: CGFloat
    let tools: InkTools
    var undoTick: Int = 0

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> FixedScaleCanvasView {
        let canvas = FixedScaleCanvasView()
        canvas.logicalSize = CGSize(width: DecorationCanvas.logicalWidth, height: DecorationCanvas.logicalWidth / aspectRatio)
        canvas.pendingDrawing = drawing
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        // Strokes are stored as drawn; dark mode would otherwise invert ink colors on screen.
        canvas.overrideUserInterfaceStyle = .light
        canvas.drawingPolicy = Self.policy
        canvas.isScrollEnabled = false
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.tool = tools.tool
        tools.canvas = canvas

        let pencil = UIPencilInteraction()
        pencil.delegate = context.coordinator
        canvas.addInteraction(pencil)
        return canvas
    }

    /// iPhone always draws with a finger. iPad follows the system "Only Draw with Apple Pencil" setting,
    /// so a resting palm doesn't scribble for Pencil users. (`.default` ignored finger input on iPhone.)
    private static var policy: PKCanvasViewDrawingPolicy {
        if UIDevice.current.userInterfaceIdiom == .phone { return .anyInput }
        return UIPencilInteraction.prefersPencilOnlyDrawing ? .pencilOnly : .anyInput
    }

    func updateUIView(_ canvas: FixedScaleCanvasView, context: Context) {
        context.coordinator.parent = self
        canvas.drawingPolicy = Self.policy
        canvas.tool = tools.tool
        canvas.drawingGestureRecognizer.isEnabled = tools.mode == .draw
        canvas.logicalSize = CGSize(width: DecorationCanvas.logicalWidth, height: DecorationCanvas.logicalWidth / aspectRatio)
        if canvas.isScaled, canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {
        var parent: InkCanvas

        init(_ parent: InkCanvas) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            if parent.drawing != canvasView.drawing {
                parent.drawing = canvasView.drawing
            }
        }

        @available(iOS 17.5, *)
        func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
            parent.tools.toggleEraser()
        }

        // Pre-17.5 path; newer systems call the method above instead.
        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            parent.tools.toggleEraser()
        }
    }
}

final class FixedScaleCanvasView: PKCanvasView {
    var logicalSize = CGSize(width: DecorationCanvas.logicalWidth, height: DecorationCanvas.logicalWidth) {
        didSet { if logicalSize != oldValue { setNeedsLayout() } }
    }
    /// Strokes handed over before the first layout. Assigning them before the zoom is set leaves
    /// parts of a reopened drawing unrendered, so they wait until the canvas has its real scale.
    var pendingDrawing: PKDrawing?
    private(set) var isScaled = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        let scale = bounds.width / logicalSize.width
        if abs(zoomScale - scale) > 0.0001 || abs(minimumZoomScale - scale) > 0.0001 {
            minimumZoomScale = scale
            maximumZoomScale = scale
            zoomScale = scale
        }
        let size = CGSize(width: logicalSize.width * scale, height: logicalSize.height * scale)
        if contentSize != size {
            contentSize = size
        }
        if contentOffset != .zero {
            contentOffset = .zero
        }
        isScaled = true
        if let pendingDrawing {
            self.pendingDrawing = nil
            drawing = pendingDrawing
        }
    }
}

/// Stickers over the canvas. In sticker mode they can be dragged, pinched, rotated and removed.
struct StickerLayer: View {
    @Binding var stickers: [Sticker]
    @Binding var selection: UUID?
    let isEditing: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if isEditing {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { selection = nil }
                }
                ForEach($stickers) { $sticker in
                    StickerItemView(
                        sticker: $sticker,
                        canvasSize: proxy.size,
                        isSelected: isEditing && selection == sticker.id,
                        isEditing: isEditing,
                        onSelect: { selection = sticker.id },
                        onDelete: {
                            stickers.removeAll { $0.id == sticker.id }
                            selection = nil
                        }
                    )
                }
            }
        }
        .allowsHitTesting(isEditing)
    }
}

private struct StickerItemView: View {
    @Binding var sticker: Sticker
    let canvasSize: CGSize
    let isSelected: Bool
    let isEditing: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var pinch: CGFloat = 1
    @State private var twist: Angle = .zero

    var body: some View {
        let unit = canvasSize.width / DecorationCanvas.logicalWidth
        StickerFace(sticker: sticker, unit: unit)
            .scaleEffect(pinch)
            .rotationEffect(.radians(sticker.rotation) + twist)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.ink.opacity(0.8))
                    }
                    .offset(x: 14, y: -14)
                    .accessibilityLabel("스티커 빼기")
                }
            }
            .padding(6)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .foregroundStyle(.tint)
                }
            }
            .position(x: sticker.x * canvasSize.width + dragOffset.width, y: sticker.y * canvasSize.height + dragOffset.height)
            .gesture(isEditing ? manipulation : nil)
            .onTapGesture(perform: onSelect)
    }

    private var manipulation: some Gesture {
        let drag = DragGesture(minimumDistance: 2)
            .onChanged { value in
                onSelect()
                dragOffset = value.translation
            }
            .onEnded { value in
                sticker.x = min(max(sticker.x + value.translation.width / canvasSize.width, 0), 1)
                sticker.y = min(max(sticker.y + value.translation.height / canvasSize.height, 0), 1)
                dragOffset = .zero
            }
        let magnify = MagnifyGesture()
            .onChanged { value in pinch = value.magnification }
            .onEnded { value in
                sticker.scale = min(max(sticker.scale * value.magnification, 0.3), 5)
                pinch = 1
            }
        let rotate = RotateGesture()
            .onChanged { value in twist = value.rotation }
            .onEnded { value in
                sticker.rotation += value.rotation.radians
                twist = .zero
            }
        return drag.simultaneously(with: magnify.simultaneously(with: rotate))
    }
}

/// One sticker's look; the renderer draws the same shapes into the saved image.
struct StickerFace: View {
    let sticker: Sticker
    let unit: CGFloat

    var body: some View {
        if sticker.isWord {
            Text(sticker.content)
                .font(.system(size: StickerMetrics.wordFontSize * sticker.scale * unit, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(rgb: StickerMetrics.wordInk))
                .padding(.horizontal, StickerMetrics.wordPaddingX * sticker.scale * unit)
                .padding(.vertical, StickerMetrics.wordPaddingY * sticker.scale * unit)
                .background(Capsule().fill(Color(rgb: StickerMetrics.wordPaper)))
                .overlay(Capsule().stroke(Color(rgb: StickerMetrics.wordInk), lineWidth: max(1, 4 * sticker.scale * unit)))
                .fixedSize()
        } else {
            Text(sticker.content)
                .font(.system(size: StickerMetrics.emojiFontSize * sticker.scale * unit))
                .fixedSize()
        }
    }
}

nonisolated enum StickerMetrics {
    static let emojiFontSize: CGFloat = 120
    static let wordFontSize: CGFloat = 56
    static let wordPaddingX: CGFloat = 26
    static let wordPaddingY: CGFloat = 12
    static let wordInk: UInt32 = 0xC1552C
    static let wordPaper: UInt32 = 0xFFF8EE
}
