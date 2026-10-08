import SwiftUI

struct EntryDetailView: View {
    let entryID: UUID

    @Environment(JournalStore.self) private var store
    @Environment(FragmentCollector.self) private var collector
    @Environment(\.dismiss) private var dismiss
    @State private var editingDraft: DraftModel?
    @State private var confirmDelete = false
    @State private var errorText: String?

    private var entry: DiaryEntry? {
        store.entries.first { $0.id == entryID }
    }

    var body: some View {
        Group {
            if let entry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        DayHeader(day: entry.day)
                        JournalPageView(entry: entry)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                    .readableColumn()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("수정하기", systemImage: "pencil") {
                                editingDraft = DraftModel(day: entry.day, existing: entry, collected: collector.collect(on: entry.day))
                            }
                            Button("삭제하기", systemImage: "trash", role: .destructive) {
                                confirmDelete = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("더 보기")
                    }
                }
            } else {
                ContentUnavailableView("기록을 찾을 수 없어요", systemImage: "book.closed")
            }
        }
        .background(Color.paper)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingDraft) { draft in
            ComposerView(draft: draft, saveTitle: "수정 완료", onSave: saveEdit, onCancel: { editingDraft = nil })
                .interactiveDismissDisabled()
        }
        .confirmationDialog("이 날의 기록을 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { deleteEntry() }
        } message: {
            Text("삭제한 기록은 되돌릴 수 없어요.")
        }
        .alert(
            "문제가 생겼어요",
            isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private func saveEdit(_ updated: DiaryEntry) {
        do {
            try store.save(updated)
            editingDraft = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func deleteEntry() {
        guard let entry else { return }
        do {
            try store.delete(entry)
            if Calendar.current.isDateInToday(entry.day) {
                UserDefaults.standard.removeObject(forKey: ReminderSettings.lastEntryDayKey)
            }
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
