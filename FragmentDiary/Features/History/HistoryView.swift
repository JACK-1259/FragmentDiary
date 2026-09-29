import SwiftUI

struct HistoryView: View {
    @Environment(JournalStore.self) private var store
    @State private var showBackfill = false
    @State private var path: [UUID] = []
    @State private var backfillTarget: BackfillTarget?

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
                }
            }
            .background(Color.paper)
            .navigationTitle("기록")
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

            VStack(alignment: .leading, spacing: 10) {
                if !entry.previewText.isEmpty {
                    Text(entry.previewText)
                        .font(entry.quick ? .system(.body, design: .serif) : .subheadline)
                        .foregroundStyle(Color.ink)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                if !entry.photoIDs.isEmpty {
                    MiniCollage(assetIDs: entry.photoIDs)
                }
                meta
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .cardStyle()
        .contentShape(Rectangle())
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

/// First photo wider than the rest — an uneven strip rather than a uniform grid.
private struct MiniCollage: View {
    let assetIDs: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(assetIDs.prefix(3).enumerated()), id: \.element) { index, id in
                AssetThumbnail(assetID: id)
                    .frame(width: index == 0 ? 96 : 60, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}
