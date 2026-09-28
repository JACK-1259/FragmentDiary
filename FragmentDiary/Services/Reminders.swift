import BackgroundTasks
import Foundation
import UserNotifications

enum ReminderSettings {
    static let enabledKey = "reminderEnabled"
    static let minutesKey = "reminderMinutes"
    static let lastEntryDayKey = "lastEntryDay"
    static let defaultMinutes = 21 * 60 + 30

    static var minutes: Int {
        UserDefaults.standard.object(forKey: minutesKey) as? Int ?? defaultMinutes
    }

    static func date(fromMinutes minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    static func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 21) * 60 + (components.minute ?? 30)
    }
}

/// Schedules a week of one-shot reminders so today's copy can reflect how many fragments are waiting.
enum ReminderScheduler {
    private static let identifiers = (0..<7).map { "reminder-\($0)" }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func reschedule(todayFragmentCount: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard UserDefaults.standard.bool(forKey: ReminderSettings.enabledKey) else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let calendar = Calendar.current
        let now = Date.now
        let today = calendar.startOfDay(for: now)
        let lastEntryDay = UserDefaults.standard.object(forKey: ReminderSettings.lastEntryDayKey) as? Date
        let wroteToday = lastEntryDay.map { calendar.isDate($0, inSameDayAs: now) } ?? false

        for offset in 0..<identifiers.count {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fireDate = calendar.date(byAdding: .minute, value: ReminderSettings.minutes, to: day)
            else { continue }
            if offset == 0 && (wroteToday || fireDate <= now) { continue }

            let copy = offset == 0 ? todayCopy(fragmentCount: todayFragmentCount) : upcomingCopy
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: identifiers[offset], content: content, trigger: trigger))
        }
    }

    private static func todayCopy(fragmentCount: Int) -> (title: String, body: String) {
        if fragmentCount > 0 {
            return ("오늘 \(fragmentCount)개의 조각이 모였어요", "사진과 일정이 미리 정리돼 있어요. 30초면 기록 끝.")
        }
        return ("오늘 하루는 어땠나요?", "한 줄만 남겨도 충분해요.")
    }

    private static let upcomingCopy = (title: "오늘의 조각이 기다리고 있어요", body: "하루가 미리 모여 있어요. 골라서 한 줄만 더해보세요.")
}

enum BackgroundRefresh {
    static let taskID = "com.jonghwa.fragmentdiary.collect"

    /// Aims for an hour before the reminder so the notification can quote a fresh fragment count.
    static func schedule() {
        let calendar = Calendar.current
        let lead = max(ReminderSettings.minutes - 60, 0)
        guard var target = calendar.date(byAdding: .minute, value: lead, to: calendar.startOfDay(for: .now)) else { return }
        if target <= .now {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = target
        try? BGTaskScheduler.shared.submit(request)
    }

    static func run() async {
        schedule()
        let count = FragmentCollector().collect(on: .now).count
        WidgetPublisher.publish(fragmentCount: count, store: nil)
        await ReminderScheduler.reschedule(todayFragmentCount: count)
    }
}
