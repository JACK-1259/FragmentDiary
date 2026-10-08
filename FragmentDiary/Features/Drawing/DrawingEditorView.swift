import PencilKit
import SwiftUI

/// Draw the day on a notebook page, pick the weather and write a few words in the squares.
/// The page goes back to the composer as a drawing fragment; the composer decides when the entry is saved.
struct DrawingEditorView: View {
    let day: Date
    let existing: Fragment?
    let onSave: (Fragment) -> Void
    let onCancel: () -> Void

    @Environment(JournalStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var session: DecorationSession
    @State private var weather: Weather?
    @State private var text: String
    @State private var errorText: String?
    @State private var confirmDiscard = false
    /// The writing bar is shown first, then focused once it exists.
    @State private var writing = false
    @FocusState private var fieldFocused: Bool
    private let initialDrawing: PKDrawing
    private let initialStickers: [Sticker]

    init(day: Date, existing: Fragment?, layers: DecorationLayers?, onSave: @escaping (Fragment) -> Void, onCancel: @escaping () -> Void) {
        self.day = day
        self.existing = existing
        self.onSave = onSave
        self.onCancel = onCancel
        let session = DecorationSession(layers: layers, aspectRatio: DrawingDiary.aspectRatio)
        _session = State(initialValue: session)
        initialDrawing = session.drawing
        initialStickers = session.stickers
        _weather = State(initialValue: existing?.weather)
        _text = State(initialValue: existing?.caption ?? "")
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let isWide = sizeClass == .regular && proxy.size.width > proxy.size.height
                Group {
                    if isWide {
                        HStack(alignment: .top, spacing: 24) {
                            page.frame(maxWidth: 640)
                            VStack(spacing: 16) {
                                DecorationControls(session: session)
                                Spacer()
                            }
                            .frame(width: 320)
                            .padding(16)
                            .cardStyle()
                        }
                    } else {
                        VStack(spacing: 14) {
                            page
                            if !writing {
                                DecorationControls(session: session)
                                    .padding(.horizontal, 4)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: 640)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)
            }
            .background(Color.paper)
            .safeAreaInset(edge: .bottom) {
                if writing { writingBar }
            }
            .navigationTitle(Calendar.current.isDateInToday(day) ? "오늘의 그림일기" : DateText.day(day))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        if hasChanges { confirmDiscard = true } else { onCancel() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료", action: save)
                        .disabled(session.isEmpty && text.trimmed.isEmpty)
                }
            }
            .confirmationDialog("그린 내용을 버릴까요?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("버리기", role: .destructive, action: onCancel)
            }
            .alert("저장하지 못했어요", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
        .interactiveDismissDisabled()
    }

    private var page: some View {
        NotebookPage(day: day, weather: weather, text: text, onSelectWeather: { weather = $0 }, onTapText: { withAnimation(.snappy) { writing = true } }) {
            DecorationSurface(session: session) {
                Color(rgb: DrawingDiary.paperRGB)
            }
        }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .overlay(alignment: .bottomTrailing) {
            if text.isEmpty && !writing {
                Label("눌러서 쓰기", systemImage: "character.cursor.ibeam")
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
    }

    private var writingBar: some View {
        HStack(spacing: 10) {
            TextField("오늘 있었던 일을 짧게", text: $text, axis: .vertical)
                .lineLimit(1...3)
                .focused($fieldFocused)
                .onAppear { fieldFocused = true }
                .onChange(of: fieldFocused) { _, focused in
                    if !focused { withAnimation(.snappy) { writing = false } }
                }
                .onChange(of: text) { _, new in
                    let fitted = DrawingDiary.fitting(new)
                    if fitted != new { text = fitted }
                }
            Text("\(text.filter { !$0.isNewline }.count)/\(DrawingDiary.capacity)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.inkMuted)
            Button("완료") { fieldFocused = false }
                .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(Color.card)
        .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 0.5) }
    }

    private var hasChanges: Bool {
        session.drawing != initialDrawing || session.stickers != initialStickers
            || text != (existing?.caption ?? "") || weather != existing?.weather
    }

    private func save() {
        fieldFocused = false
        let id = UUID()
        let image = DecorationRenderer.render(base: nil, paper: UIColor(rgb: DrawingDiary.paperRGB), layers: session.layers, outputWidth: 1600)
        do {
            try store.saveAttachment(id, image: image, layers: session.layers)
            var fragment = existing ?? Fragment(
                sourceID: "drawing:\(UUID().uuidString)",
                kind: .drawing,
                start: Calendar.current.isDateInToday(day) ? .now : day.addingTimeInterval(20 * 3600)
            )
            fragment.drawingID = id
            fragment.caption = text.trimmed
            fragment.weather = weather
            onSave(fragment)
        } catch {
            errorText = error.localizedDescription
        }
    }
}
