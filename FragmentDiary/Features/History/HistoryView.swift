import SwiftUI

struct HistoryView: View {
    @Environment(JournalStore.self) private var store
    @State private var showBackfill = false
    @State private var path: [UUID] = []
    @State private var backfillTarget: BackfillTarget?
    @State private var query = ""
    @State private var scope = JournalSearch.Scope.all

    private var months: [(month: Date, entries: [DiaryEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.entries) {
            calendar.dateInterval(of: .month, for: $0.day)?.start ?? $0.day
        }
        return grouped.keys.sorted(by: >).map { month in
            (month, grouped[month, default: []].sorted { $0.day > $1.day })
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if store.entries.isEmpty {
                    emptyState
                } else if !query.trimmed.isEmpty {
                    SearchResultsView(query: query, entries: store.entries, scope: $scope)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                        .readableColumn()
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        MonthCalendarView(entries: store.entries) { entry in
                            path.append(entry.id)
                        } onFill: { day in
                            backfillTarget = BackfillTarget(day: day)
                        }
                        stats
                        ForEach(months, id: \.month) { group in
                            Text(DateText.month(group.month))
                                .font(.system(.title3, design: .serif, weight: .semibold))
                                .foregroundStyle(Color.ink)
                                .padding(.top, 18)
                            ForEach(group.entries) { entry in
                                NavigationLink(value: entry.id) {
                                    DayCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .readableColumn()
                }
            }
            .background(Color.paper)
            .navigationTitle("기록")
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

    private var stats: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(store.entries.count)", label: "기록한 날")
            StatTile(value: "\(store.daysThisMonth)", label: "이번 달")
            if store.streak >= 2 {
                StatTile(value: "\(store.streak)일", label: "이어가는 중")
            }
        }
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

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(Color.ink)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.inkMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 14)
        .accessibilityElement(children: .combine)
    }
}

private struct DayCard: View {
    let entry: DiaryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 2) {
                Text(DateText.dayNumber(entry.day))
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.ink)
                Text(DateText.shortWeekday(entry.day))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.inkMuted)
            }
            .frame(width: 40)

            RoundedRectangle(cornerRadius: 2)
                .fill(entry.mood?.color ?? Color.hairline)
                .frame(width: 3)

            // Same order as the notebook page: what's stuck on (photos, drawings, memos, emoji) first, then the words.
            VStack(alignment: .leading, spacing: 10) {
                let stuckOn = MiniPiece.pieces(of: entry)
                if !stuckOn.isEmpty {
                    MiniCollage(pieces: stuckOn)
                }
                if !previewText.isEmpty {
                    Text(previewText)
                        .font(entry.quick ? .system(.body, design: .serif) : .subheadline)
                        .foregroundStyle(Color.ink)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                meta
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .cardStyle()
        .contentShape(Rectangle())
    }

    /// The day's own words, not a memo already shown as a sticky note above.
    private var previewText: String {
        if !entry.note.isEmpty { return entry.note }
        let written = entry.fragments.first { ($0.kind == .photos || $0.kind.isQuestion) && !$0.caption.isEmpty }
        if let written { return written.caption }
        return entry.fragments.compactMap(\.title).joined(separator: " · ")
    }

    private var meta: some View {
        HStack(spacing: 10) {
            if let mood = entry.mood {
                Text(mood.label)
            }
            if !entry.fragments.isEmpty {
                Label("\(entry.fragments.count)", systemImage: "square.stack")
            }
            if entry.quick {
                Text("한 줄")
            }
            if entry.isBackfilled {
                Text("나중에 채움")
            }
        }
        .font(.caption)
        .foregroundStyle(Color.inkMuted)
    }
}

/// One small thing stuck on a day's page, for the list's preview strip.
enum MiniPiece: Hashable {
    case photo(PhotoRef)
    case note(String, UInt32)
    case emoji(String)

    /// In page order, at most four.
    static func pieces(of entry: DiaryEntry) -> [MiniPiece] {
        let pieces = entry.fragments.compactMap { fragment -> MiniPiece? in
            switch fragment.kind {
            case .drawing: fragment.drawingID.map { .photo(.journal($0)) }
            case .photos: fragment.photos.first.map(MiniPiece.photo)
            case .note where !fragment.caption.trimmed.isEmpty:
                .note(fragment.caption, StickyNoteColor.all[StickyNoteColor.index(fragment.noteColor, id: fragment.id)].rgb)
            case .emoji where !fragment.caption.isEmpty: .emoji(fragment.caption)
            default: nil
            }
        }
        return Array(pieces.prefix(4))
    }
}

/// The first piece wider than the rest — an uneven strip rather than a uniform grid.
private struct MiniCollage: View {
    let pieces: [MiniPiece]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { index, piece in
                Group {
                    switch piece {
                    case .photo(let photo):
                        PhotoRefThumbnail(photo: photo)
                    case .note(let text, let rgb):
                        Text(text)
                            .font(.system(size: 10, design: .serif))
                            .foregroundStyle(Color(rgb: 0x3B3029))
                            .lineLimit(4)
                            .padding(6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .background(Color(rgb: rgb))
                    case .emoji(let emoji):
                        Text(emoji)
                            .font(.system(size: 26))
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .padding(4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(rgb: 0xFFFDF6))
                    }
                }
                .frame(width: index == 0 ? 96 : 60, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.hairline, lineWidth: 0.5))
            }
        }
        .accessibilityHidden(true)
    }
}
