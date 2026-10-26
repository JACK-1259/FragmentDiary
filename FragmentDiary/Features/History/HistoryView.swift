import SwiftUI

struct HistoryView: View {
    @Environment(JournalStore.self) private var store
    @State private var showBackfill = false
    @State private var path: [UUID] = []
    @State private var backfillTarget: BackfillTarget?
    @State private var query = ""
    @State private var scope = JournalSearch.Scope.all

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.entries.isEmpty {
                    ScrollView { emptyState }
                } else if !query.trimmed.isEmpty {
                    ScrollView {
                        SearchResultsView(query: query, entries: store.entries, scope: $scope)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                            .readableColumn()
                    }
                } else {
                    JournalBook(entries: store.entries, summary: summary) { day in
                        backfillTarget = BackfillTarget(day: day)
                    }
                }
            }
            .background(Color.paper)
            .navigationTitle("기록")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "한 줄, 메모, 일정 찾기")
            .navigationDestination(for: UUID.self) { id in
                EntryDetailView(entryID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBackfill = true
                    } label: {
                        Label("놓친 날 채우기", systemImage: "calendar.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showBackfill) {
                BackfillPickerView { showBackfill = false }
            }
            .sheet(item: $backfillTarget) { target in
                BackfillComposer(day: target.day) { backfillTarget = nil }
            }
        }
    }

    /// "기록한 날 51", under each month's calendar; the calendar itself already counts that month's days.
    private var summary: String {
        "기록한 날 \(store.entries.count)"
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            MiniNotebook(scale: 4.2)
                .padding(.bottom, 8)
            Text("아직 기록이 없어요")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Color.ink)
            Text("오늘 탭에서 첫 조각을 모으거나,\n오른쪽 위 버튼으로 지난 날을 채워보세요.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
