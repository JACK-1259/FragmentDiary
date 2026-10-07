import EventKit
import Observation
import Photos

enum PermissionState {
    case granted, limited, notDetermined, denied
}

/// Builds a day's fragments from the photo library, calendar and finished reminders. Everything is read on-device; nothing is copied out.
@Observable
final class FragmentCollector {
    private(set) var photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    private(set) var calendarStatus = EKEventStore.authorizationStatus(for: .event)
    private(set) var remindersStatus = EKEventStore.authorizationStatus(for: .reminder)
    /// Reminders can only be fetched asynchronously, so the past week's finished ones are cached and
    /// folded into the synchronous `collect`. Views watch this to refresh once a fetch lands.
    private(set) var finishedReminders: [Fragment] = []

    @ObservationIgnored private var eventStore = EKEventStore()

    /// Photos taken within this gap of each other are treated as one moment.
    private static let photoClusterGap: TimeInterval = 60 * 60
    private static let maxPhotosPerFragment = 30

    var photoState: PermissionState {
        switch photoStatus {
        case .authorized: .granted
        case .limited: .limited
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    var calendarState: PermissionState {
        switch calendarStatus {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    var remindersState: PermissionState {
        switch remindersStatus {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    var canReadPhotos: Bool { photoState == .granted || photoState == .limited }

    func refreshStatus() {
        photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let newCalendarStatus = EKEventStore.authorizationStatus(for: .event)
        let newRemindersStatus = EKEventStore.authorizationStatus(for: .reminder)
        if newCalendarStatus != calendarStatus || newRemindersStatus != remindersStatus {
            eventStore = EKEventStore()
            calendarStatus = newCalendarStatus
            remindersStatus = newRemindersStatus
        }
    }

    func requestPhotos() async {
        photoStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func requestCalendar() async {
        _ = try? await EKEventStore().requestFullAccessToEvents()
        eventStore = EKEventStore()
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestReminders() async {
        _ = try? await EKEventStore().requestFullAccessToReminders()
        eventStore = EKEventStore()
        remindersStatus = EKEventStore.authorizationStatus(for: .reminder)
        await refreshReminders()
    }

    /// Loads reminders completed in the past week (the backfill window) into the cache.
    func refreshReminders(now: Date = .now) async {
        guard remindersState == .granted else {
            if !finishedReminders.isEmpty { finishedReminders = [] }
            return
        }
        let today = Calendar.current.startOfDay(for: now)
        let start = Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
        let predicate = eventStore.predicateForCompletedReminders(withCompletionDateStarting: start, ending: now, calendars: nil)
        let fetched = await Self.fetch(predicate, in: eventStore)
        if fetched != finishedReminders { finishedReminders = fetched }
    }

    /// EventKit calls back on its own queue; only plain values cross back.
    private nonisolated static func fetch(_ predicate: NSPredicate, in store: EKEventStore) async -> [Fragment] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let fragments = (reminders ?? []).compactMap { reminder -> Fragment? in
                    guard let done = reminder.completionDate else { return nil }
                    return Fragment(
                        sourceID: "reminder:\(reminder.calendarItemIdentifier)",
                        kind: .reminder,
                        start: done,
                        title: reminder.title
                    )
                }
                continuation.resume(returning: fragments.sorted { $0.start < $1.start })
            }
        }
    }

    func collect(on day: Date, now: Date = .now) -> [Fragment] {
        let reminders = finishedReminders.filter { Calendar.current.isDate($0.start, inSameDayAs: day) && $0.start <= now }
        return (photoFragments(on: day) + eventFragments(on: day, now: now) + reminders).sorted { $0.start < $1.start }
    }

    /// The events and finished reminders of a day, as questions.
    func questions(on day: Date, now: Date = .now) -> [Fragment] {
        collect(on: day, now: now).filter(\.kind.isQuestion)
    }

    private func dayBounds(_ day: Date) -> (start: Date, end: Date) {
        let start = Calendar.current.startOfDay(for: day)
        return (start, Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start)
    }

    private func photoFragments(on day: Date) -> [Fragment] {
        guard canReadPhotos else { return [] }
        let bounds = dayBounds(day)
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", bounds.start as NSDate, bounds.end as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(with: .image, options: options)

        var clusters: [[(id: String, date: Date)]] = []
        for index in 0..<result.count {
            let asset = result.object(at: index)
            guard let date = asset.creationDate, !asset.mediaSubtypes.contains(.photoScreenshot) else { continue }
            if let last = clusters.last?.last, date.timeIntervalSince(last.date) <= Self.photoClusterGap {
                clusters[clusters.count - 1].append((asset.localIdentifier, date))
            } else {
                clusters.append([(asset.localIdentifier, date)])
            }
        }

        return clusters.compactMap { cluster in
            guard let first = cluster.first, let last = cluster.last else { return nil }
            return Fragment(
                sourceID: "photo:\(first.id)",
                kind: .photos,
                start: first.date,
                end: cluster.count > 1 ? last.date : nil,
                assetIDs: cluster.prefix(Self.maxPhotosPerFragment).map(\.id)
            )
        }
    }

    private func eventFragments(on day: Date, now: Date) -> [Fragment] {
        guard calendarState == .granted else { return [] }
        let bounds = dayBounds(day)
        let predicate = eventStore.predicateForEvents(withStart: bounds.start, end: bounds.end, calendars: nil)
        return eventStore.events(matching: predicate)
            // Upcoming events are plans, not memories; holiday and other subscribed calendars aren't personal.
            .filter { $0.startDate <= now && $0.calendar.type != .birthday && $0.calendar.type != .subscription }
            .map { event in
                Fragment(
                    sourceID: "event:\(event.calendarItemIdentifier)@\(Int(event.startDate.timeIntervalSince1970))",
                    kind: .event,
                    start: event.isAllDay ? bounds.start : event.startDate,
                    end: event.isAllDay ? nil : event.endDate,
                    title: event.title,
                    place: event.location.flatMap { $0.trimmed.isEmpty ? nil : $0 }
                )
            }
    }
}
