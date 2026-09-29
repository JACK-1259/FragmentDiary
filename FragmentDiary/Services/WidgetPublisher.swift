import WidgetKit

enum WidgetPublisher {
    /// Pass the store only when it's unlocked; background refreshes update the count and keep the last known entry state.
    static func publish(fragmentCount: Int, store: JournalStore?) {
        var snapshot = WidgetSnapshot.load()
            ?? WidgetSnapshot(countDay: .now, fragmentCount: 0, lastEntryDay: nil, streak: 0, writtenDays: [])
        snapshot.countDay = .now
        snapshot.fragmentCount = fragmentCount
        if let store, store.isUnlocked {
            snapshot.lastEntryDay = store.entries.first?.day
            snapshot.streak = store.streak
            let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Calendar.current.startOfDay(for: .now)) ?? .distantPast
            snapshot.writtenDays = store.entries.map(\.day).filter { $0 >= cutoff }
        }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
