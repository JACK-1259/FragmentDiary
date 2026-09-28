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
        let start = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        let end = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let existing = Set(store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil)).compactMap(\.title))

        let samples: [(title: String, location: String?, dayOffset: Int, hour: Int, minute: Int, minutes: Int)] = [
            ("팀 스탠드업", "3층 회의실", 0, 10, 0, 30),
            ("민지랑 점심", "성수동 파스타집", 0, 12, 0, 60),
            ("요가 클래스", nil, 0, 19, 30, 60),
            ("수진이 생일 저녁", "을지로 이자카야", -1, 19, 0, 150),
        ]
        for sample in samples where !existing.contains(sample.title) {
            guard let day = Calendar.current.date(byAdding: .day, value: sample.dayOffset, to: today) else { continue }
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = sample.title
            event.location = sample.location
            event.startDate = Calendar.current.date(bySettingHour: sample.hour, minute: sample.minute, second: 0, of: day)
            event.endDate = event.startDate.addingTimeInterval(TimeInterval(sample.minutes * 60))
            try? store.save(event, span: .thisEvent)
        }
    }
}
#endif
