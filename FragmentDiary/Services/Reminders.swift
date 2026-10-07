import BackgroundTasks
import Foundation
import UIKit
import UserNotifications

enum ReminderSettings {
    static let enabledKey = "reminderEnabled"
    static let minutesKey = "reminderMinutes"
    static let lastEntryDayKey = "lastEntryDay"
    /// Off by default: event and reminder titles would otherwise show on the Lock Screen.
    static let showsTitlesKey = "notificationShowsTitles"
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

    static func reschedule(today fragments: [Fragment]) async {
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

            let copy = offset == 0 ? todayCopy(fragments) : upcomingCopy
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: identifiers[offset], content: content, trigger: trigger))
        }
    }

    private static func todayCopy(_ fragments: [Fragment]) -> (title: String, body: String) {
        let events = fragments.filter { $0.kind == .event }
        let reminders = fragments.filter { $0.kind == .reminder }
        let photos = fragments.filter { $0.kind == .photos }.count
        if UserDefaults.standard.bool(forKey: ReminderSettings.showsTitlesKey),
           let first = (events + reminders).sorted(by: { $0.start < $1.start }).first {
            return (Question.prompt(for: first), "질문에 답하면 30초면 기록 끝.")
        }
        let parts = [events.isEmpty ? nil : "일정 \(events.count)개", reminders.isEmpty ? nil : "끝낸 일 \(reminders.count)개"].compactMap { $0 }
        if !parts.isEmpty {
            let photoNote = photos > 0 ? " 사진 조각 \(photos)개도 모여 있어요." : ""
            return ("오늘 \(parts.joined(separator: "와 "))가 있었어요", "한 줄 남겨볼까요?\(photoNote)")
        }
        if !fragments.isEmpty {
            return ("오늘 \(fragments.count)개의 조각이 모였어요", "사진이 미리 정리돼 있어요. 30초면 기록 끝.")
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
        let collector = FragmentCollector()
        await collector.refreshReminders()
        let fragments = collector.collect(on: .now)
        WidgetPublisher.publish(fragmentCount: fragments.count, store: nil)
        await ReminderScheduler.reschedule(today: fragments)
    }
}

/// Carries "the user tapped the evening reminder" from the notification delegate to the composer.
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()
    var openQuestions = false
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.notification.request.identifier.hasPrefix("reminder-") else { return }
        await MainActor.run { NotificationRouter.shared.openQuestions = true }
    }
}
