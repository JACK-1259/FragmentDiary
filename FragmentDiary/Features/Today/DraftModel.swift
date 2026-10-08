import Foundation
import Observation

@Observable
final class DraftModel: Identifiable {
    enum Mode: Hashable {
        case fragments, oneLine
    }

    struct Item: Identifiable {
        var fragment: Fragment
        var included: Bool
        var isNew: Bool

        var id: String { fragment.sourceID }
        var isRemovable: Bool { fragment.kind == .note || fragment.kind == .drawing || fragment.sourceID.hasPrefix("manual:") }
    }

    let id = UUID()
    let day: Date
    var mode: Mode
    var mood: Mood?
    var note: String
    var items: [Item]
    var showCover: Bool
    private let existing: DiaryEntry?
    private let preselectCollected: Bool

    /// `preselectCollected: false` makes every collected fragment opt-in, for drafts that will be shared with others.
    init(day: Date, existing: DiaryEntry?, collected: [Fragment], preselectCollected: Bool = true) {
        self.day = Calendar.current.startOfDay(for: day)
        self.existing = existing
        self.preselectCollected = preselectCollected
        mode = existing?.quick == true ? .oneLine : .fragments
        mood = existing?.mood
        note = existing?.note ?? ""
        items = (existing?.fragments ?? []).map { Item(fragment: $0, included: true, isNew: false) }
        showCover = existing.map { !$0.quick || !$0.fragments.isEmpty } ?? true
        merge(collected)
    }

    /// Folds freshly collected fragments in without losing captions. On a fresh day everything is pre-selected;
    /// when editing a saved entry, late arrivals are offered but left unchecked.
    func merge(_ collected: [Fragment]) {
        for fragment in collected {
            if let index = items.firstIndex(where: { $0.id == fragment.sourceID }) {
                var refreshed = fragment
                refreshed.caption = items[index].fragment.caption
                refreshed.reaction = items[index].fragment.reaction
                refreshed.pageScale = items[index].fragment.pageScale
                refreshed.pageX = items[index].fragment.pageX
                refreshed.pageY = items[index].fragment.pageY
                refreshed.pageZ = items[index].fragment.pageZ
                // Decorations belong to the user, not the collector; keep them for photos still in the moment.
                refreshed.decorations = items[index].fragment.decorations?.filter { refreshed.assetIDs.contains($0.key) }
                if refreshed.decorations?.isEmpty == true { refreshed.decorations = nil }
                items[index].fragment = refreshed
            } else {
                // Questions join the diary only once answered; everything else follows the preselect rule.
                let included = !fragment.kind.isQuestion && existing == nil && preselectCollected
                items.append(Item(fragment: fragment, included: included, isNew: existing != nil))
            }
        }
        items.sort { $0.fragment.start < $1.fragment.start }
    }

    func addNote() {
        let fragment = Fragment(sourceID: "note:\(UUID().uuidString)", kind: .note, start: manualTimestamp())
        items.append(Item(fragment: fragment, included: true, isNew: false))
        items.sort { $0.fragment.start < $1.fragment.start }
    }

    func addPhotos(_ assetIDs: [String], takenAt date: Date?) {
        let start = date.flatMap { Calendar.current.isDate($0, inSameDayAs: day) ? $0 : nil } ?? manualTimestamp()
        let fragment = Fragment(sourceID: "manual:\(UUID().uuidString)", kind: .photos, start: start, assetIDs: assetIDs)
        items.append(Item(fragment: fragment, included: true, isNew: false))
        items.sort { $0.fragment.start < $1.fragment.start }
    }

    var questionIDs: [String] {
        items.filter { $0.fragment.kind.isQuestion }.map(\.id)
    }

    var answeredQuestionCount: Int {
        items.filter { $0.fragment.kind.isQuestion && $0.included }.count
    }

    /// Answering puts a question into the diary; clearing the answer takes it out again.
    func syncInclusion(of id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].fragment.kind.isQuestion else { return }
        items[index].included = items[index].fragment.isAnswered
    }

    func dropAnswer(_ id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].fragment.reaction = nil
        items[index].fragment.caption = ""
        items[index].included = false
    }

    /// A finished drawing page: replaces the one being edited, or joins the timeline as a new fragment.
    func upsertDrawing(_ fragment: Fragment) {
        if let index = items.firstIndex(where: { $0.id == fragment.sourceID }) {
            items[index].fragment = fragment
            items[index].included = true
        } else {
            items.append(Item(fragment: fragment, included: true, isNew: false))
            items.sort { $0.fragment.start < $1.fragment.start }
        }
    }

    func remove(_ id: String) {
        items.removeAll { $0.id == id }
    }

    var isEditingExisting: Bool { existing != nil }

    var coverItem: Item? {
        items.filter { $0.fragment.kind == .photos }.max { $0.fragment.assetIDs.count < $1.fragment.assetIDs.count }
    }

    var includedCount: Int {
        items.filter(\.included).count
    }

    var canSave: Bool {
        if mood != nil || !note.trimmed.isEmpty { return true }
        guard mode == .fragments else { return false }
        return items.contains { $0.included && ($0.fragment.kind != .note || !$0.fragment.caption.trimmed.isEmpty) }
    }

    func makeEntry() -> DiaryEntry {
        let chosen: [Fragment]
        switch mode {
        case .fragments:
            chosen = items.filter(\.included).map(\.fragment)
        case .oneLine:
            // A drawing page is its own record of the day, so the one-line mode keeps it alongside the cover.
            let kept = items.filter { $0.included && ($0.fragment.kind == .drawing || $0.fragment.kind.isQuestion) }.map(\.fragment)
            chosen = ((showCover ? [coverItem?.fragment].compactMap { $0 } : []) + kept).sorted { $0.start < $1.start }
        }
        let fragments = chosen.compactMap { fragment -> Fragment? in
            var fragment = fragment
            fragment.caption = fragment.caption.trimmed
            return fragment.kind == .note && fragment.caption.isEmpty ? nil : fragment
        }
        return DiaryEntry(
            id: existing?.id ?? UUID(),
            day: day,
            mood: mood,
            note: note.trimmed,
            quick: mode == .oneLine,
            fragments: fragments,
            createdAt: existing?.createdAt ?? .now,
            updatedAt: .now
        )
    }

    private func manualTimestamp() -> Date {
        Calendar.current.isDateInToday(day) ? .now : day.addingTimeInterval(20 * 3600)
    }
}
