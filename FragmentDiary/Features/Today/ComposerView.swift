import Photos
import PhotosUI
import SwiftUI

struct ComposerView<Accessory: View>: View {
    @Bindable var draft: DraftModel
    let saveTitle: String
    let onSave: (DiaryEntry) -> Void
    var onCancel: (() -> Void)?
    @ViewBuilder var accessory: Accessory

    @Environment(FragmentCollector.self) private var collector
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var appeared = false

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
        .onAppear { appeared = true }
        .onChange(of: pickedPhotos) { _, items in addPicked(items) }
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
        VStack(alignment: .leading, spacing: 0) {
            if draft.items.isEmpty {
                EmptyFragmentsCard(isToday: Calendar.current.isDateInToday(draft.day)) { draft.mode = .oneLine }
                    .padding(.bottom, 20)
            }
            ForEach($draft.items) { $item in
                let index = draft.items.firstIndex { $0.id == item.id } ?? 0
                TimelineRow(label: DateText.timelineLabel(for: item.fragment)) {
                    FragmentCard(item: $item, onRemove: item.isRemovable ? { remove(item.id) } : nil)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .animation(.spring(duration: 0.5).delay(Double(index) * 0.06), value: appeared)
            }
            addRow
                .padding(.leading, draft.items.isEmpty ? 0 : 56)
                .padding(.bottom, 28)
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

    private var addRow: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.snappy) { draft.addNote() }
            } label: {
                Label("메모 조각", systemImage: "text.quote")
            }
            if collector.canReadPhotos {
                PhotosPicker(selection: $pickedPhotos, maxSelectionCount: 12, matching: .images, photoLibrary: .shared()) {
                    Label("사진 더하기", systemImage: "photo.badge.plus")
                }
            }
        }
        .buttonStyle(ChipButtonStyle())
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

private struct FragmentCard: View {
    @Binding var item: DraftModel.Item
    var onRemove: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                content
                Spacer(minLength: 0)
                accessory
            }
            if item.fragment.kind != .note && item.fragment.kind != .drawing && item.included {
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
            DrawingFragmentPreview(fragment: item.fragment)
        case .event:
            EventSummary(fragment: item.fragment, isNew: item.isNew)
        case .note:
            TextField("지금 떠오르는 생각", text: $item.fragment.caption, axis: .vertical)
                .lineLimit(1...8)
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
