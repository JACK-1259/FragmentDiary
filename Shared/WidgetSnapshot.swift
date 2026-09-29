import Foundation

nonisolated enum DayState: Sendable, Equatable {
    case written, today, missed, future
}

/// The only data the widget ever sees: counts and dates, never diary content.
nonisolated struct WidgetSnapshot: Codable, Sendable {
    static let appGroup = "group.com.jonghwa.fragmentdiary"
    private static let key = "widgetSnapshot"

    var countDay: Date
    var fragmentCount: Int
    var lastEntryDay: Date?
    var streak: Int
    /// Days with an entry, recent enough to cover this week and last.
    var writtenDays: [Date]

    /// Monday-first week containing `date`, one state per day.
    static func week(containing date: Date, writtenDays: [Date]) -> [DayState] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let today = calendar.startOfDay(for: date)
        let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let written = Set(writtenDays.map { calendar.startOfDay(for: $0) })
        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            if written.contains(day) { return .written }
            if day == today { return .today }
            return day < today ? .missed : .future
        }
    }

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.key)
    }

    /// Nil once the day rolls over and the app hasn't counted the new day yet.
    func fragmentCount(on day: Date) -> Int? {
        Calendar.current.isDate(countDay, inSameDayAs: day) ? fragmentCount : nil
    }

    func wrote(on day: Date) -> Bool {
        lastEntryDay.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false
    }

    func streak(on day: Date) -> Int {
        guard let lastEntryDay else { return 0 }
        let calendar = Calendar.current
        let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastEntryDay), to: calendar.startOfDay(for: day)).day ?? .max
        return gap <= 1 ? streak : 0
    }
}
