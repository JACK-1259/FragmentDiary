#if DEBUG
import EventKit
import Foundation
import Photos

/// Simulators have no CLI for calendar data or deleting photos. Launch arguments:
/// `-seedSampleEvents` adds sample events around today; `-removeSampleData` removes those events
/// and the sample photos (added with `simctl addmedia` as sample_*.jpg / yesterday_*.jpg).
enum DebugSeeder {
    private static let samples: [(title: String, location: String?, dayOffset: Int, hour: Int, minute: Int, minutes: Int)] = [
        ("팀 스탠드업", "3층 회의실", 0, 10, 0, 30),
        ("민지랑 점심", "성수동 파스타집", 0, 12, 0, 60),
        ("요가 클래스", nil, 0, 19, 30, 60),
        ("수진이 생일 저녁", "을지로 이자카야", -1, 19, 0, 150),
    ]
    /// Finished reminders: (title, days ago, completion hour, minute).
    private static let sampleReminders: [(title: String, dayOffset: Int, hour: Int, minute: Int)] = [
        ("치과 예약", 0, 9, 20),
        ("택배 반품하기", -1, 18, 40),
    ]
    private static let samplePhotoPrefixes = ["sample_", "yesterday_"]

    static func seedIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-seedSampleEvents"),
              EKEventStore.authorizationStatus(for: .event) == .fullAccess
        else { return }

        let store = EKEventStore()
        guard let calendar = store.defaultCalendarForNewEvents else { return }
        let today = Calendar.current.startOfDay(for: .now)
        // Keyed by day too: yesterday's copy of a sample must not suppress today's.
        let existing = Set(sampleWindowEvents(in: store).map { "\($0.title ?? "")@\(Calendar.current.startOfDay(for: $0.startDate))" })

        for sample in samples {
            guard let day = Calendar.current.date(byAdding: .day, value: sample.dayOffset, to: today),
                  !existing.contains("\(sample.title)@\(day)") else { continue }
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = sample.title
            event.location = sample.location
            event.startDate = Calendar.current.date(bySettingHour: sample.hour, minute: sample.minute, second: 0, of: day)
            event.endDate = event.startDate.addingTimeInterval(TimeInterval(sample.minutes * 60))
            try? store.save(event, span: .thisEvent)
        }
        seedReminders(in: store)
    }

    private static func seedReminders(in store: EKEventStore) {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess,
              let list = store.defaultCalendarForNewReminders() else { return }
        let today = Calendar.current.startOfDay(for: .now)
        // Reminders can only be fetched asynchronously, so a per-day marker keeps relaunches from adding duplicates.
        let marker = "seededReminders@\(today.timeIntervalSince1970)"
        guard !UserDefaults.standard.bool(forKey: marker) else { return }
        UserDefaults.standard.set(true, forKey: marker)
        for sample in sampleReminders {
            guard let day = Calendar.current.date(byAdding: .day, value: sample.dayOffset, to: today),
                  let done = Calendar.current.date(bySettingHour: sample.hour, minute: sample.minute, second: 0, of: day),
                  done <= .now else { continue }
            let reminder = EKReminder(eventStore: store)
            reminder.calendar = list
            reminder.title = sample.title
            reminder.completionDate = done
            try? store.save(reminder, commit: false)
        }
        try? store.commit()
    }

    static func removeSampleDataIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("-removeSampleData") else { return }

        if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            let store = EKEventStore()
            let titles = Set(samples.map(\.title))
            let matches = sampleWindowEvents(in: store).filter { titles.contains($0.title) }
            for event in matches {
                try? store.remove(event, span: .thisEvent, commit: false)
            }
            try? store.commit()
            print("[DebugSeeder] removed \(matches.count) sample events")
        }

        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else { return }
        let all = PHAsset.fetchAssets(with: .image, options: nil)
        var matches: [String] = []
        all.enumerateObjects { asset, _, _ in
            let names = PHAssetResource.assetResources(for: asset).map(\.originalFilename)
            if names.contains(where: { name in samplePhotoPrefixes.contains { name.hasPrefix($0) } }) {
                matches.append(asset.localIdentifier)
            }
        }
        print("[DebugSeeder] found \(matches.count) sample photos")
        guard !matches.isEmpty else { return }
        do {
            try await deleteAssets(matches)
            print("[DebugSeeder] deleted \(matches.count) sample photos")
        } catch {
            print("[DebugSeeder] photo deletion failed: \(error)")
        }
    }

    /// Photos runs the change block on its own queue, so it must not inherit the app's default main-actor isolation.
    private nonisolated static func deleteAssets(_ identifiers: [String]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil))
        }
    }

    private static func sampleWindowEvents(in store: EKEventStore) -> [EKEvent] {
        let today = Calendar.current.startOfDay(for: .now)
        let start = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        let end = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        return store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
    }
}
#endif
