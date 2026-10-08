import SwiftUI

/// On-device search over the unlocked journal: lines, notes, event and reminder titles, places and answers.
/// Nothing is indexed to disk; it scans the entries already decrypted in memory.
enum JournalSearch {
    enum Scope: CaseIterable, Identifiable {
        case all, writing, events

        var id: Self { self }

        var label: String {
            switch self {
            case .all: "전체"
            case .writing: "한 줄·메모"
            case .events: "일정·할 일"
            }
        }
    }

    struct Hit: Identifiable {
        let entry: DiaryEntry
        /// The line to show, and the fragment kind it came from (nil for the day's note).
        let text: String
        let kind: FragmentKind?
        let detail: String?
        var id: String { "\(entry.id)-\(text)" }

        var scope: Scope { kind == .event || kind == .reminder ? .events : .writing }
    }

    static func hits(for query: String, in entries: [DiaryEntry]) -> [Hit] {
        let needle = query.trimmed
        guard !needle.isEmpty else { return [] }
        func matches(_ text: String?) -> Bool { text?.localizedStandardContains(needle) == true }

        return entries.flatMap { entry -> [Hit] in
            var hits: [Hit] = []
            if matches(entry.note) {
                hits.append(Hit(entry: entry, text: entry.note, kind: nil, detail: entry.quick ? "한 줄" : "남기고 싶은 말"))
            }
            for fragment in entry.fragments {
                switch fragment.kind {
                case .event, .reminder:
                    guard matches(fragment.title) || matches(fragment.place) || matches(fragment.caption) || matches(fragment.reaction) else { continue }
                    let detail = [DateText.timelineLabel(for: fragment), fragment.place, fragment.reaction].compactMap { $0 }.joined(separator: " · ")
                    hits.append(Hit(entry: entry, text: JournalPageView.sentence(for: fragment), kind: fragment.kind, detail: detail))
                case .photos, .note, .drawing:
                    guard matches(fragment.caption) else { continue }
                    let detail = fragment.kind == .note ? "메모 조각" : fragment.kind == .drawing ? "그림일기" : "사진 \(fragment.assetIDs.count)장"
                    hits.append(Hit(entry: entry, text: fragment.caption, kind: fragment.kind, detail: detail))
                }
            }
            return hits
        }
    }

    /// "‘민지’가 나온 날 4일 · 3일이 좋음" — only when enough days carry a mood to say something.
    static func moodSummary(query: String, hits: [Hit]) -> String? {
        var seen = Set<UUID>()
        let days = hits.map(\.entry).filter { seen.insert($0.id).inserted }
        let moods = days.compactMap(\.mood)
        var text = "‘\(query.trimmed)’가 나온 날 \(days.count)일"
        if let top = Dictionary(grouping: moods, by: { $0 }).max(by: { $0.value.count < $1.value.count }), top.value.count >= 2 {
            text += " · \(top.value.count)일이 \(top.key.label)"
        }
        return days.isEmpty ? nil : text
    }

    /// The match is tinted so the eye lands on it in a long line.
    static func highlighted(_ text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        let needle = query.trimmed
        guard !needle.isEmpty else { return attributed }
        var searchStart = attributed.startIndex
        while let range = attributed[searchStart...].range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributed[range].backgroundColor = Color(rgb: 0xC1552C).opacity(0.18)
            attributed[range].font = .subheadline.weight(.semibold)
            searchStart = range.upperBound
        }
        return attributed
    }
}

/// The results list that replaces the calendar while a search is active.
struct SearchResultsView: View {
    let query: String
    let entries: [DiaryEntry]
    @Binding var scope: JournalSearch.Scope

    var body: some View {
        let all = JournalSearch.hits(for: query, in: entries)
        let shown = scope == .all ? all : all.filter { $0.scope == scope }
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(JournalSearch.Scope.allCases) { option in
                    let count = option == .all ? all.count : all.filter { $0.scope == option }.count
                    Button {
                        scope = option
                    } label: {
                        Text("\(option.label) \(count)")
                            .font(.subheadline.weight(scope == option ? .semibold : .regular))
                            .foregroundStyle(scope == option ? Color.white : Color.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(scope == option ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.card)))
                            .overlay(Capsule().stroke(Color.hairline, lineWidth: scope == option ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            if let summary = JournalSearch.moodSummary(query: query, hits: all) {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            if shown.isEmpty {
                ContentUnavailableView.search(text: query)
                    .padding(.top, 40)
            }
            ForEach(shown) { hit in
                NavigationLink(value: hit.entry.id) {
                    SearchHitRow(hit: hit, query: query)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SearchHitRow: View {
    let hit: JournalSearch.Hit
    let query: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(DateText.dayNumber(hit.entry.day))
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                Text(DateText.month(hit.entry.day).components(separatedBy: " ").last ?? "")
                    .font(.caption2)
                    .foregroundStyle(Color.inkMuted)
            }
            .foregroundStyle(Color.ink)
            .frame(width: 44)
            RoundedRectangle(cornerRadius: 2)
                .fill(hit.entry.mood?.color ?? Color.hairline)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(Color.inkMuted)
                    Text(JournalSearch.highlighted(hit.text, query: query))
                        .font(.subheadline)
                        .foregroundStyle(Color.ink)
                        .lineLimit(2)
                }
                if let detail = hit.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if let photo = hit.entry.previewPhotos.first {
                PhotoRefThumbnail(photo: photo)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(12)
        .cardStyle(cornerRadius: 16)
        .contentShape(Rectangle())
    }

    private var icon: String {
        switch hit.kind {
        case .event: "calendar"
        case .reminder: "checklist"
        case .drawing: "scribble.variable"
        case .photos: "photo"
        case .note, .none: "pencil.line"
        }
    }
}
