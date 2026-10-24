import Photos
import PhotosUI
import SwiftUI

struct ComposerView<Accessory: View>: View {
    @Bindable var draft: DraftModel
    let saveTitle: String
    let onSave: (DiaryEntry) -> Void
    var onCancel: (() -> Void)?
    /// Only the Today composer answers a tapped evening reminder by opening the questions.
    var opensQuestionsFromNotification = false
    @ViewBuilder var accessory: Accessory

    @Environment(FragmentCollector.self) private var collector
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var appeared = false
    @State private var showQuestions = false
    @State private var drawingTarget: DrawingTarget?
    @State private var emojiTarget: EmojiTarget?
    @Environment(JournalStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                DayHeader(day: draft.day, subtitle: subtitle)
                accessory
                Picker("기록 방식", selection: $draft.mode.animation(.snappy)) {
                    Text("조각으로").tag(DraftModel.Mode.fragments)
                    Text("한 줄로").tag(DraftModel.Mode.oneLine)
                }
                .pickerStyle(.segmented)
                MoodPicker(selection: $draft.mood, day: draft.day)
                if !draft.questionIDs.isEmpty {
                    QuestionSummaryRow(draft: draft) { showQuestions = true }
                }
                switch draft.mode {
                case .fragments: fragmentsSection
                case .oneLine: oneLineSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .readableColumn()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.paper)
        .safeAreaInset(edge: .bottom) { saveBar }
        .onAppear {
            appeared = true
            openQuestionsIfRequested()
        }
        .onChange(of: NotificationRouter.shared.openQuestions) { openQuestionsIfRequested() }
        .onChange(of: pickedPhotos) { _, items in addPicked(items) }
        .fullScreenCover(item: $drawingTarget) { target in
            DrawingEditorView(
                day: draft.day,
                existing: target.fragment,
                layers: target.fragment?.drawingID.flatMap(store.layers)
            ) { fragment in
                withAnimation(.snappy) { draft.upsertDrawing(fragment) }
                drawingTarget = nil
            } onCancel: {
                drawingTarget = nil
            }
        }
        .sheet(item: $emojiTarget) { target in
            EmojiPickerSheet(initial: target.id.flatMap { id in draft.items.first { $0.id == id }?.fragment.caption } ?? "") { emoji in
                guard emoji != EmojiPickerSheet.unchanged else {
                    emojiTarget = nil
                    return
                }
                withAnimation(.snappy) {
                    if let id = target.id, let index = draft.items.firstIndex(where: { $0.id == id }) {
                        if emoji.isEmpty { draft.remove(id) } else { draft.items[index].fragment.caption = emoji }
                    } else if !emoji.isEmpty {
                        _ = draft.addEmoji(emoji)
                    }
                }
                emojiTarget = nil
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showQuestions) {
            QuestionDeckSheet(draft: draft) { showQuestions = false }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var isToday: Bool { Calendar.current.isDateInToday(draft.day) }

    private var subtitle: String {
        let count = draft.items.count
        if Calendar.current.isDateInToday(draft.day) {
            return count > 0 ? "오늘의 조각 \(count)개가 모였어요" : "아직 모인 조각이 없어요"
        }
        if draft.isEditingExisting { return "조각 \(count)개" }
        return count > 0 ? "이 날의 조각 \(count)개가 남아 있어요" : "남아 있는 조각이 없어요"
    }

    private var fragmentsSection: some View {
        // Questions live behind the summary row, so the timeline is only photos, notes and drawings.
        let hasTimeline = draft.items.contains { !$0.fragment.kind.isQuestion }
        return VStack(alignment: .leading, spacing: 0) {
            // Adding a memo, photo or drawing sits above the timeline so it's visible without scrolling.
            addRow
                .padding(.bottom, 20)
            if draft.items.isEmpty {
                EmptyFragmentsCard(isToday: Calendar.current.isDateInToday(draft.day)) { draft.mode = .oneLine }
                    .padding(.bottom, 20)
            }
            ForEach($draft.items.filter { !$0.wrappedValue.fragment.kind.isQuestion }) { $item in
                let index = draft.items.firstIndex { $0.id == item.id } ?? 0
                TimelineRow(label: DateText.timelineLabel(for: item.fragment)) {
                    FragmentCard(
                        item: $item,
                        onRemove: item.isRemovable ? { remove(item.id) } : nil,
                        onOpenDrawing: { drawingTarget = DrawingTarget(fragment: item.fragment) },
                        onOpenEmoji: { emojiTarget = EmojiTarget(id: item.id) }
                    )
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .animation(.spring(duration: 0.5).delay(Double(index) * 0.06), value: appeared)
            }
            Spacer().frame(height: hasTimeline ? 12 : 0)
            VStack(alignment: .leading, spacing: 8) {
                Text("더 남기고 싶은 말")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.inkMuted)
                TextField("선택 사항이에요", text: $draft.note, axis: .vertical)
                    .lineLimit(3...10)
                    .padding(14)
                    .cardStyle()
            }
        }
    }

    /// Short labels so all three fit on one row, even beside the timeline on the smallest iPhone.
    private var addRow: some View {
        HStack(spacing: 6) {
            noteButton
            photoButton
            drawButton
            emojiButton
        }
        .labelStyle(CompactChipLabelStyle())
        .buttonStyle(ChipButtonStyle(horizontalPadding: 11))
    }

    private var noteButton: some View {
        Button {
            withAnimation(.snappy) { draft.addNote() }
        } label: {
            Label("메모", systemImage: "text.quote")
        }
    }

    @ViewBuilder
    private var photoButton: some View {
        if collector.canReadPhotos {
            PhotosPicker(selection: $pickedPhotos, maxSelectionCount: 12, matching: .images, photoLibrary: .shared()) {
                Label("사진", systemImage: "photo.badge.plus")
            }
        }
    }

    private var emojiButton: some View {
        Button {
            emojiTarget = EmojiTarget(id: nil)
        } label: {
            Label("이모지", systemImage: "face.smiling")
        }
    }

    private var drawButton: some View {
        Button {
            drawingTarget = DrawingTarget(fragment: nil)
        } label: {
            Label("그림", systemImage: "scribble.variable")
        }
    }

    private var oneLineSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            TextField(isToday ? "오늘을 한 줄로 남긴다면?" : "그날을 한 줄로 남긴다면?", text: $draft.note, axis: .vertical)
                .font(.system(.title3, design: .serif))
                .lineLimit(1...4)
                .padding(18)
                .cardStyle()
            if let cover = draft.coverItem {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $draft.showCover.animation(.snappy)) {
                        Text(isToday ? "오늘의 커버 사진" : "그날의 커버 사진")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.ink)
                    }
                    if draft.showCover {
                        PhotoCollage(photos: cover.fragment.photos, height: 170)
                    }
                }
            }
            if !draft.keptInOneLine.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("함께 남는 조각 \(draft.keptInOneLine.count)개")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.ink)
                    ForEach(draft.keptInOneLine) { item in
                        KeptFragmentRow(fragment: item.fragment)
                    }
                }
            }
            Label("바쁜 날엔 이것만으로 충분해요. 기록은 그대로 이어져요.", systemImage: "leaf")
                .font(.footnote)
                .foregroundStyle(Color.inkMuted)
        }
    }

    private var saveBar: some View {
        VStack(spacing: 10) {
            Button(saveTitle) { onSave(draft.makeEntry()) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!draft.canSave)
            if let onCancel {
                Button("취소", action: onCancel)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
        .readableColumn()
        .background {
            LinearGradient(colors: [Color.paper.opacity(0), Color.paper], startPoint: .top, endPoint: .init(x: 0.5, y: 0.35))
                .ignoresSafeArea()
        }
    }

    private func openQuestionsIfRequested() {
        guard opensQuestionsFromNotification, NotificationRouter.shared.openQuestions else { return }
        NotificationRouter.shared.openQuestions = false
        if !draft.questionIDs.isEmpty { showQuestions = true }
    }

    private func addPicked(_ items: [PhotosPickerItem]) {
        let ids = items.compactMap(\.itemIdentifier)
        guard let first = ids.first else { return }
        let takenAt = PHAsset.fetchAssets(withLocalIdentifiers: [first], options: nil).firstObject?.creationDate
        withAnimation(.snappy) { draft.addPhotos(ids, takenAt: takenAt) }
        pickedPhotos = []
    }

    private func remove(_ id: String) {
        withAnimation(.snappy) { draft.remove(id) }
    }
}

/// A compact reminder, in the one-line mode, of something the user wrote or made that will be kept.
private struct KeptFragmentRow: View {
    let fragment: Fragment

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(.tint)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .cardStyle(cornerRadius: 14)
    }

    private var symbol: String {
        switch fragment.kind {
        case .note: "text.quote"
        case .emoji: "face.smiling"
        case .drawing: "scribble.variable"
        case .photos: "photo"
        case .event: "calendar"
        case .reminder: "checklist"
        }
    }

    private var text: String {
        switch fragment.kind {
        case .note, .emoji: fragment.caption
        case .drawing: fragment.caption.isEmpty ? "그림일기" : "그림일기 · \(fragment.caption)"
        case .photos: fragment.caption.isEmpty ? "사진 \(fragment.assetIDs.count)장" : fragment.caption
        case .event, .reminder: JournalPageView.sentence(for: fragment)
        }
    }
}

/// Picks the sticky-note color a memo will have on the notebook page.
private struct NoteColorPicker: View {
    @Binding var fragment: Fragment

    var body: some View {
        let current = StickyNoteColor.index(fragment.noteColor, id: fragment.id)
        HStack(spacing: 9) {
            Image(systemName: "note")
                .font(.caption)
                .foregroundStyle(Color.inkMuted)
                .accessibilityLabel("포스트잇 색")
            ForEach(StickyNoteColor.all.indices, id: \.self) { index in
                let isOn = index == current
                Button {
                    fragment.noteColor = index
                } label: {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(rgb: StickyNoteColor.all[index].rgb))
                        .frame(width: 24, height: 24)
                        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(Color.black.opacity(0.08), lineWidth: 1))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.ink, lineWidth: isOn ? 2 : 0).padding(-4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(StickyNoteColor.all[index].name) 포스트잇")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.leading, 2)
        .padding(.top, 2)
    }
}

/// Icon and word kept tight and on one line, so four chips fit across an iPhone.
private struct CompactChipLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
            configuration.title
        }
        .lineLimit(1)
        .fixedSize()
    }
}

private struct EmojiTarget: Identifiable {
    /// The fragment being changed, or nil to add a new one.
    let id: String?
}

private struct DrawingTarget: Identifiable {
    let fragment: Fragment?
    var id: String { fragment?.sourceID ?? "new" }
}

private struct FragmentCard: View {
    @Binding var item: DraftModel.Item
    var onRemove: (() -> Void)?
    var onOpenDrawing: () -> Void = {}
    var onOpenEmoji: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                content
                Spacer(minLength: 0)
                accessory
            }
            if ![.note, .drawing, .emoji].contains(item.fragment.kind) && item.included {
                TextField("한 줄 덧붙이기", text: $item.fragment.caption, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...4)
                    .padding(.top, 10)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.hairline).frame(height: 0.5)
                    }
            }
        }
        .padding(14)
        .cardStyle()
        .opacity(item.included ? 1 : 0.5)
        .animation(.snappy, value: item.included)
    }

    @ViewBuilder
    private var content: some View {
        switch item.fragment.kind {
        case .photos:
            VStack(alignment: .leading, spacing: 8) {
                PhotoCollage(photos: item.fragment.photos, height: 140)
                HStack(spacing: 6) {
                    Text("사진 \(item.fragment.assetIDs.count)장")
                    if item.isNew { NewBadge() }
                    if item.included {
                        Text("·")
                        DecoratePhotoButton(fragment: $item.fragment)
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.inkMuted)
            }
        case .drawing:
            Button(action: onOpenDrawing) {
                VStack(alignment: .leading, spacing: 6) {
                    DrawingFragmentPreview(fragment: item.fragment)
                    Text("눌러서 이어 그리기")
                        .font(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
            }
            .buttonStyle(.plain)
        case .reminder:
            QuestionAnswerView(fragment: item.fragment)
        case .event:
            EventSummary(fragment: item.fragment, isNew: item.isNew)
        case .note:
            VStack(alignment: .leading, spacing: 10) {
                TextField("지금 떠오르는 생각", text: $item.fragment.caption, axis: .vertical)
                    .lineLimit(1...8)
                NoteColorPicker(fragment: $item.fragment)
            }
        case .emoji:
            Button(action: onOpenEmoji) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.fragment.caption.isEmpty ? "＋" : item.fragment.caption)
                        .font(.system(size: 40))
                        .foregroundStyle(Color.inkMuted)
                    Text("눌러서 이모지 바꾸기")
                        .font(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var accessory: some View {
        if let onRemove {
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("조각 빼기")
        } else {
            Button {
                item.included.toggle()
            } label: {
                Image(systemName: item.included ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.included ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.inkMuted))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.included ? "일기에서 빼기" : "일기에 넣기")
        }
    }
}

/// A drawing page inside the composer or a list; the page itself is edited from the 그림 tab.
struct DrawingFragmentPreview: View {
    let fragment: Fragment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let id = fragment.drawingID {
                JournalAttachmentImage(attachmentID: id)
                    .aspectRatio(DrawingDiary.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.hairline, lineWidth: 0.5))
            }
            HStack(spacing: 6) {
                Label("그림일기", systemImage: "scribble.variable")
                if let weather = fragment.weather {
                    Image(systemName: weather.symbol).foregroundStyle(weather.color)
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.inkMuted)
            if !fragment.caption.isEmpty {
                Text(fragment.caption)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(Color.ink)
            }
        }
    }
}

private struct EmptyFragmentsCard: View {
    let isToday: Bool
    let onOneLine: () -> Void

    @Environment(FragmentCollector.self) private var collector
    @Environment(\.openURL) private var openURL

    private var needsPermission: Bool {
        !collector.canReadPhotos || collector.calendarState != .granted
    }

    private var title: String {
        if needsPermission { return "하루의 조각을 자동으로 모으려면" }
        return isToday ? "아직 오늘의 조각이 없어요" : "이 날 남은 조각이 없어요"
    }

    private var message: String {
        if needsPermission { return "사진과 캘린더를 허용하면 그날 찍은 사진과 지나간 일정이 여기에 알아서 모여요." }
        return isToday
            ? "사진을 찍거나 일정이 지나가면 여기에 쌓여요. 지금은 메모 조각을 더하거나 한 줄로 남겨보세요."
            : "기억나는 걸 메모 조각으로 더하거나, 무드와 한 줄만 남겨도 충분해요."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                if collector.photoState == .notDetermined {
                    Button("사진 허용하기") { Task { await collector.requestPhotos() } }
                }
                if collector.calendarState == .notDetermined {
                    Button("캘린더 허용하기") { Task { await collector.requestCalendar() } }
                }
                if collector.photoState == .denied || collector.calendarState == .denied {
                    Button("설정에서 허용하기") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
                Button("한 줄로 남기기", action: onOneLine)
            }
            .buttonStyle(ChipButtonStyle())
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

extension ComposerView where Accessory == EmptyView {
    init(draft: DraftModel, saveTitle: String, onSave: @escaping (DiaryEntry) -> Void, onCancel: (() -> Void)? = nil) {
        self.init(draft: draft, saveTitle: saveTitle, onSave: onSave, onCancel: onCancel, accessory: { EmptyView() })
    }
}
