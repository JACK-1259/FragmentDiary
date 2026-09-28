import EventKit
import Observation
import Photos

enum PermissionState {
    case granted, limited, notDetermined, denied
}

/// Builds a day's fragments from the photo library and calendar. Everything is read on-device; nothing is copied out.
@Observable
final class FragmentCollector {
    private(set) var photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    private(set) var calendarStatus = EKEventStore.authorizationStatus(for: .event)

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

    var canReadPhotos: Bool { photoState == .granted || photoState == .limited }

    func refreshStatus() {
        photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let newCalendarStatus = EKEventStore.authorizationStatus(for: .event)
        if newCalendarStatus != calendarStatus {
            eventStore = EKEventStore()
            calendarStatus = newCalendarStatus
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

    func collect(on day: Date, now: Date = .now) -> [Fragment] {
        (photoFragments(on: day) + eventFragments(on: day, now: now)).sorted { $0.start < $1.start }
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
            // Upcoming events are plans, not memories.
            .filter { $0.startDate <= now && $0.calendar.type != .birthday }
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
