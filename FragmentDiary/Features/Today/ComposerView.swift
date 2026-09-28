import Photos
import PhotosUI
import SwiftUI

struct ComposerView: View {
    @Bindable var draft: DraftModel
    let saveTitle: String
    let onSave: (DiaryEntry) -> Void
    var onCancel: (() -> Void)?

    @Environment(FragmentCollector.self) private var collector
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                DayHeader(day: draft.day, subtitle: subtitle)
                Picker("기록 방식", selection: $draft.mode.animation(.snappy)) {
                    Text("조각으로").tag(DraftModel.Mode.fragments)
                    Text("한 줄로").tag(DraftModel.Mode.oneLine)
                }
                .pickerStyle(.segmented)
                MoodPicker(selection: $draft.mood)
                switch draft.mode {
                case .fragments: fragmentsSection
                case .oneLine: oneLineSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.paper)
        .safeAreaInset(edge: .bottom) { saveBar }
        .onAppear { appeared = true }
        .onChange(of: pickedPhotos) { _, items in addPicked(items) }
    }

    private var subtitle: String {
        let count = draft.items.count
        guard Calendar.current.isDateInToday(draft.day) else { return "조각 \(count)개" }
        return count > 0 ? "오늘의 조각 \(count)개가 모였어요" : "아직 모인 조각이 없어요"
    }

    private var fragmentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if draft.items.isEmpty {
                EmptyFragmentsCard { draft.mode = .oneLine }
                    .padding(.bottom, 20)
            }
            ForEach($draft.items) { $item in
                let index = draft.items.firstIndex { $0.id == item.id } ?? 0
                TimelineRow(time: item.fragment.start) {
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
            TextField("오늘을 한 줄로 남긴다면?", text: $draft.note, axis: .vertical)
                .font(.system(.title3, design: .serif))
                .lineLimit(1...4)
                .padding(18)
                .cardStyle()
            if let cover = draft.coverItem {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $draft.showCover.animation(.snappy)) {
                        Text("오늘의 커버 사진")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.ink)
                    }
                    .tint(Color.accentColor)
                    if draft.showCover {
                        PhotoCollage(assetIDs: cover.fragment.assetIDs, height: 170)
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
            if item.fragment.kind != .note && item.included {
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
                PhotoCollage(assetIDs: item.fragment.assetIDs, height: 140)
                HStack(spacing: 6) {
                    Text("사진 \(item.fragment.assetIDs.count)장")
                    if item.isNew { NewBadge() }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.inkMuted)
            }
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
                    .foregroundStyle(item.included ? Color.accentColor : Color.inkMuted)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.included ? "일기에서 빼기" : "일기에 넣기")
        }
    }
}

private struct EmptyFragmentsCard: View {
    let onOneLine: () -> Void

    @Environment(FragmentCollector.self) private var collector
    @Environment(\.openURL) private var openURL

    private var needsPermission: Bool {
        !collector.canReadPhotos || collector.calendarState != .granted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(needsPermission ? "하루의 조각을 자동으로 모으려면" : "아직 오늘의 조각이 없어요")
                .font(.headline)
                .foregroundStyle(Color.ink)
            Text(needsPermission
                 ? "사진과 캘린더를 허용하면 오늘 찍은 사진과 지나간 일정이 여기에 알아서 모여요."
                 : "사진을 찍거나 일정이 지나가면 여기에 쌓여요. 지금은 메모 조각을 더하거나 한 줄로 남겨보세요.")
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
