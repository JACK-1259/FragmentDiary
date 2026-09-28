#if DEBUG
import EventKit
import Foundation

/// Simulators have no CLI for calendar data; launch with `-seedSampleEvents` to add a few of today's events.
enum DebugSeeder {
    static func seedIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-seedSampleEvents"),
              EKEventStore.authorizationStatus(for: .event) == .fullAccess
        else { return }

        let store = EKEventStore()
        guard let calendar = store.defaultCalendarForNewEvents else { return }
        let today = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let existing = Set(store.events(matching: store.predicateForEvents(withStart: today, end: end, calendars: nil)).compactMap(\.title))

        let samples: [(title: String, location: String?, hour: Int, minute: Int, minutes: Int)] = [
            ("팀 스탠드업", "3층 회의실", 10, 0, 30),
            ("민지랑 점심", "성수동 파스타집", 12, 0, 60),
            ("요가 클래스", nil, 19, 30, 60),
        ]
        for sample in samples where !existing.contains(sample.title) {
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = sample.title
            event.location = sample.location
            event.startDate = Calendar.current.date(bySettingHour: sample.hour, minute: sample.minute, second: 0, of: today)
            event.endDate = event.startDate.addingTimeInterval(TimeInterval(sample.minutes * 60))
            try? store.save(event, span: .thisEvent)
        }
    }
}
#endif
