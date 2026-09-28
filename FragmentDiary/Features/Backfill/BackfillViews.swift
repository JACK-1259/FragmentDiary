import SwiftUI

struct BackfillTarget: Identifiable {
    let day: Date
    var id: Date { day }
}

/// Composes an entry for a past day from whatever photos and events that day left behind.
struct BackfillComposer: View {
    let day: Date
    let onClose: () -> Void

    @Environment(JournalStore.self) private var store
    @Environment(FragmentCollector.self) private var collector
    @State private var draft: DraftModel?
    @State private var errorText: String?
    @State private var savedTick = 0

    var body: some View {
        Group {
            if let draft {
                ComposerView(draft: draft, saveTitle: "이 날 기록 완성", onSave: save, onCancel: onClose)
            } else {
                Color.paper.ignoresSafeArea()
            }
        }
        .interactiveDismissDisabled()
        .sensoryFeedback(.success, trigger: savedTick)
        .task {
            if draft == nil {
                draft = DraftModel(day: day, existing: store.entry(on: day), collected: collector.collect(on: day))
            }
        }
        .alert(
            "저장하지 못했어요",
            isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private func save(_ entry: DiaryEntry) {
        do {
            try store.save(entry)
            savedTick += 1
            onClose()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct BackfillPickerView: View {
    let onClose: () -> Void

    @Environment(JournalStore.self) private var store
    @Environment(FragmentCollector.self) private var collector
    @State private var day = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now)) ?? .now
    @State private var fragmentCount = 0
    @State private var isComposing = false

    private var latestSelectableDay: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    private var alreadyWritten: Bool { store.entry(on: day) != nil }

    private func mostRecentUnwrittenDay() -> Date {
        let calendar = Calendar.current
        for offset in 0..<365 {
            guard let candidate = calendar.date(byAdding: .day, value: -offset, to: latestSelectableDay) else { break }
            if store.entry(on: candidate) == nil { return candidate }
        }
        return latestSelectableDay
    }

    var body: some View {
        if isComposing {
            BackfillComposer(day: day, onClose: onClose)
        } else {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        DatePicker("날짜", selection: $day, in: ...latestSelectableDay, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(Color.accentColor)
                            .environment(\.locale, Locale(identifier: "ko_KR"))
                            .padding(8)
                            .cardStyle()

                        status

                        Button("이 날 채우기") {
                            withAnimation(.snappy) { isComposing = true }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(alreadyWritten)
                    }
                    .padding(20)
                }
                .background(Color.paper)
                .navigationTitle("놓친 날 채우기")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기", action: onClose)
                    }
                }
                .onAppear { day = mostRecentUnwrittenDay() }
                .task(id: day) {
                    fragmentCount = collector.collect(on: day).count
                }
            }
        }
    }

    private var status: some View {
        HStack(spacing: 12) {
            Image(systemName: alreadyWritten ? "checkmark.seal" : "square.stack")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(DateText.full(day))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .cardStyle(cornerRadius: 14)
    }

    private var statusMessage: String {
        if alreadyWritten { return "이미 기록한 날이에요. 기록 탭에서 수정할 수 있어요." }
        if fragmentCount > 0 { return "이 날의 조각 \(fragmentCount)개가 남아 있어요" }
        return "남은 조각은 없지만, 무드와 한 줄만으로도 채울 수 있어요"
    }
}

struct MissedDayBanner: View {
    let day: Date
    let count: Int
    let onFill: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onFill) {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(DateText.relativeDay(day))의 조각 \(count)개가 남아 있어요")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ink)
                        Text("지금 채우면 30초면 돼요")
                            .font(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    Spacer(minLength: 0)
                    Text("채우기")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("알림 닫기")
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.accentColor.opacity(0.1)))
    }
}
