import SwiftUI

struct TodayView: View {
    @Environment(JournalStore.self) private var store
    @Environment(FragmentCollector.self) private var collector
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft: DraftModel?
    @State private var collected: [Fragment] = []
    @State private var isEditing = false
    @State private var saveError: String?
    @State private var savedTick = 0
    @State private var missedDay: (day: Date, count: Int)?
    @State private var backfillTarget: BackfillTarget?
    @State private var lookBackEntry: UUID?
    @AppStorage("backfillDismissedThrough") private var backfillDismissedThrough: Double = 0

    private static let backfillLookbackDays = 7

    var body: some View {
        Group {
            if let entry = store.entry(on: .now), !isEditing {
                CompletedTodayView(
                    entry: entry,
                    newCount: newFragments(for: entry).filter { !$0.kind.isQuestion }.count,
                    questionCount: newFragments(for: entry).filter(\.kind.isQuestion).count
                ) {
                    startEditing(entry)
                } onAnswer: {
                    NotificationRouter.shared.openQuestions = true
                    startEditing(entry)
                } accessory: {
                    topAccessories
                }
            } else if let draft {
                ComposerView(
                    draft: draft,
                    saveTitle: isEditing ? "수정 완료" : "오늘 기록 완성",
                    onSave: save,
                    onCancel: isEditing ? { cancelEditing() } : nil,
                    opensQuestionsFromNotification: true
                ) {
                    if !isEditing { topAccessories }
                }
            } else {
                Color.paper.ignoresSafeArea()
            }
        }
        .sensoryFeedback(.success, trigger: savedTick)
        .task {
            refresh()
            await collector.refreshReminders()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refresh()
            Task { await collector.refreshReminders() }
        }
        .onChange(of: collector.finishedReminders) { refresh() }
        .onChange(of: store.entries) { refresh() }
        .onChange(of: collector.photoStatus) { refresh() }
        .onChange(of: collector.calendarStatus) { refresh() }
        .sheet(item: Binding(get: { lookBackEntry.map(IdentifiedID.init) }, set: { lookBackEntry = $0?.id })) { target in
            NavigationStack {
                EntryDetailView(entryID: target.id)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("닫기") { lookBackEntry = nil }
                        }
                    }
            }
        }
        .sheet(item: $backfillTarget) { target in
            BackfillComposer(day: target.day) { backfillTarget = nil }
        }
        .alert(
            "저장하지 못했어요",
            isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    @ViewBuilder
    private var topAccessories: some View {
        if let match = LookBack.match(in: store) {
            LookBackStrip(match: match) { lookBackEntry = match.entry.id }
        }
        missedDayBanner
    }

    @ViewBuilder
    private var missedDayBanner: some View {
        if let missedDay {
            MissedDayBanner(day: missedDay.day, count: missedDay.count) {
                backfillTarget = BackfillTarget(day: missedDay.day)
            } onDismiss: {
                backfillDismissedThrough = missedDay.day.timeIntervalSince1970
                withAnimation(.snappy) { self.missedDay = nil }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// Most recent unwritten day in the past week that still has fragments to offer.
    private func findMissedDay() -> (day: Date, count: Int)? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        for offset in 1...Self.backfillLookbackDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if day.timeIntervalSince1970 <= backfillDismissedThrough { break }
            if store.entry(on: day) != nil { continue }
            let count = collector.collect(on: day).count
            if count > 0 { return (day, count) }
        }
        return nil
    }

    private func refresh() {
        #if DEBUG
        DebugSeeder.seedIfRequested()
        #endif
        collector.refreshStatus()
        collected = collector.collect(on: .now)
        let entry = store.entry(on: .now)

        if let draft, Calendar.current.isDateInToday(draft.day) {
            draft.merge(collected)
        } else {
            draft = nil
            isEditing = false
        }
        if draft == nil && entry == nil {
            draft = DraftModel(day: .now, existing: nil, collected: collected)
        }
        missedDay = findMissedDay()

        WidgetPublisher.publish(fragmentCount: collected.count, store: store)
        let today = collected
        Task { await ReminderScheduler.reschedule(today: today) }
    }

    /// Collected since the entry was saved: new photos, plus questions that haven't been answered yet.
    private func newFragments(for entry: DiaryEntry) -> [Fragment] {
        let saved = Set(entry.fragments.map(\.sourceID))
        return collected.filter { !saved.contains($0.sourceID) && (!entry.quick || $0.kind.isQuestion) }
    }

    private func startEditing(_ entry: DiaryEntry) {
        draft = DraftModel(day: entry.day, existing: entry, collected: collected)
        withAnimation(.snappy) { isEditing = true }
    }

    private func cancelEditing() {
        withAnimation(.snappy) {
            isEditing = false
            draft = nil
        }
    }

    private func save(_ entry: DiaryEntry) {
        do {
            try store.save(entry)
            UserDefaults.standard.set(entry.day, forKey: ReminderSettings.lastEntryDayKey)
            withAnimation(.snappy) {
                draft = nil
                isEditing = false
            }
            savedTick += 1
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct CompletedTodayView<Accessory: View>: View {
    let entry: DiaryEntry
    let newCount: Int
    let questionCount: Int
    let onEdit: () -> Void
    let onAnswer: () -> Void
    @ViewBuilder var accessory: Accessory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DayHeader(day: entry.day, subtitle: "오늘의 기록이 완성됐어요")
                accessory
                if questionCount > 0 {
                    Button(action: onAnswer) {
                        HStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.text.bubble.right")
                            Text("아직 답하지 않은 질문 \(questionCount)개")
                            Spacer()
                            Text("답하기").fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.tint.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
                if newCount > 0 {
                    Button(action: onEdit) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("새 조각 \(newCount)개가 더 모였어요")
                            Spacer()
                            Text("더하기").fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.tint.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
                JournalPageView(entry: entry)
                Button("수정하기", action: onEdit)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .readableColumn()
        }
        .background(Color.paper)
    }
}
