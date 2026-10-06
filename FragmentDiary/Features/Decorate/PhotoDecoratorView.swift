import SwiftUI

/// Full-screen editor for drawing and placing stickers on one library photo.
/// The original stays untouched in the photo library; the result is a sealed journal attachment.
struct PhotoDecoratorView: View {
    let assetID: String
    let existing: UUID?
    /// Called with the new attachment, or nil when the user reverts to the original photo.
    let onFinish: (UUID?) -> Void
    let onCancel: () -> Void

    @Environment(JournalStore.self) private var store
    @State private var base: UIImage?
    @State private var session: DecorationSession?
    @State private var isSaving = false
    @State private var errorText: String?

    private static let maxSide: CGFloat = 2400

    var body: some View {
        NavigationStack {
            Group {
                if let session, let base {
                    editor(session: session, base: base)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.paper)
            .navigationTitle("사진 꾸미기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료", action: save)
                        .disabled(session == nil || isSaving)
                }
                if existing != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button("원본으로 되돌리기", role: .destructive) { onFinish(nil) }
                            .font(.footnote)
                    }
                }
            }
            .alert("저장하지 못했어요", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
        .task { await load() }
    }

    private func editor(session: DecorationSession, base: UIImage) -> some View {
        VStack(spacing: 16) {
            DecorationSurface(session: session) {
                Image(uiImage: base)
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)

            DecorationControls(session: session)
                .padding(16)
                .cardStyle()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }

    private func load() async {
        guard let image = await PhotoExport.image(assetID: assetID, maxSide: Self.maxSide) else {
            errorText = "사진을 불러오지 못했어요."
            return
        }
        let aspect = image.size.width / max(image.size.height, 1)
        base = image
        session = DecorationSession(layers: existing.flatMap(store.layers), aspectRatio: aspect)
    }

    private func save() {
        guard let session, let base else { return }
        isSaving = true
        defer { isSaving = false }
        if session.isEmpty {
            onFinish(nil)
            return
        }
        let outputWidth = min(base.size.width * base.scale, 2000)
        let rendered = DecorationRenderer.render(base: base, paper: .white, layers: session.layers, outputWidth: outputWidth)
        let id = UUID()
        do {
            try store.saveAttachment(id, image: rendered, layers: session.layers)
            onFinish(id)
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// Lets the user pick which photo of a moment to decorate, then opens the editor.
struct DecoratePhotoButton: View {
    @Binding var fragment: Fragment
    @State private var choosing = false
    @State private var target: DecorateTarget?

    var body: some View {
        Button {
            if fragment.assetIDs.count == 1, let only = fragment.assetIDs.first {
                target = DecorateTarget(assetID: only)
            } else {
                choosing = true
            }
        } label: {
            Label(fragment.decorations?.isEmpty == false ? "꾸밈 수정" : "꾸미기", systemImage: "wand.and.stars")
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.borderless)
        .sheet(isPresented: $choosing) {
            PhotoChoiceSheet(fragment: fragment) { assetID in
                choosing = false
                target = DecorateTarget(assetID: assetID)
            }
            .font(.body)
            .foregroundStyle(Color.ink)
            .presentationDetents([.medium])
        }
        // The button sits in a caption-styled, muted row; the presented screens must not inherit that look.
        .fullScreenCover(item: $target) { target in
            PhotoDecoratorView(assetID: target.assetID, existing: fragment.decorations?[target.assetID]) { result in
                var decorations = fragment.decorations ?? [:]
                decorations[target.assetID] = result
                fragment.decorations = decorations.isEmpty ? nil : decorations
                self.target = nil
            } onCancel: {
                self.target = nil
            }
            .font(.body)
            .foregroundStyle(.tint)
        }
    }

    private struct DecorateTarget: Identifiable {
        let assetID: String
        var id: String { assetID }
    }
}

private struct PhotoChoiceSheet: View {
    let fragment: Fragment
    let onPick: (String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                    ForEach(Array(zip(fragment.assetIDs, fragment.photos)), id: \.0) { assetID, photo in
                        Button { onPick(assetID) } label: {
                            PhotoRefThumbnail(photo: photo)
                                .aspectRatio(1, contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    if fragment.decorations?[assetID] != nil {
                                        Image(systemName: "wand.and.stars")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(5)
                                            .background(Circle().fill(.tint))
                                            .padding(6)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color.paper)
            .navigationTitle("어떤 사진을 꾸밀까요?")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
