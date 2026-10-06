import CryptoKit
import Foundation
import Observation
import UIKit

/// The whole journal is one AES-GCM sealed JSON file, so dates, moods and captions are all encrypted at rest.
/// Drawings and decorated photos live beside it as sealed attachments under the same key.
@Observable
final class JournalStore {
    enum StoreError: LocalizedError {
        case locked

        var errorDescription: String? { "일기가 잠겨 있어요." }
    }

    private(set) var entries: [DiaryEntry] = []
    private(set) var isUnlocked = false
    /// Bumped when an attachment's image is replaced, so views showing the old one redraw.
    private(set) var attachmentRevision = 0

    @ObservationIgnored private var key: SymmetricKey?
    @ObservationIgnored private let fileURL = URL.applicationSupportDirectory.appending(path: "journal.sealed")
    @ObservationIgnored private let attachmentsURL = URL.applicationSupportDirectory.appending(path: "JournalAttachments", directoryHint: .isDirectory)
    @ObservationIgnored private let images = NSCache<NSString, UIImage>()

    func unlock(key: SymmetricKey) throws {
        entries = (try SealedFile.read([DiaryEntry].self, from: fileURL, key: key) ?? []).sorted { $0.day > $1.day }
        self.key = key
        isUnlocked = true
        pruneAttachments()
    }

    func lock() {
        entries = []
        key = nil
        isUnlocked = false
        images.removeAllObjects()
    }

    // MARK: Attachments

    func saveAttachment(_ id: UUID, image: UIImage, layers: DecorationLayers) throws {
        guard let key else { throw StoreError.locked }
        guard let data = image.jpegData(compressionQuality: 0.88) else { throw SealedFile.SealError.sealFailed }
        try SealedFile.writeData(data, to: attachmentURL(id, "image"), key: key)
        try SealedFile.write(layers, to: attachmentURL(id, "layers"), key: key)
        images.removeObject(forKey: id.uuidString as NSString)
        attachmentRevision += 1
    }

    /// Display-sized image; the cache keeps scrolling smooth without holding full-resolution copies.
    func attachmentImage(_ id: UUID) -> UIImage? {
        _ = attachmentRevision
        let cacheKey = id.uuidString as NSString
        if let hit = images.object(forKey: cacheKey) { return hit }
        guard let image = attachmentFullImage(id)?.preparingThumbnail(of: CGSize(width: 1400, height: 1400)) else { return nil }
        images.setObject(image, forKey: cacheKey)
        return image
    }

    func attachmentFullImage(_ id: UUID) -> UIImage? {
        guard let key, let data = try? SealedFile.readData(from: attachmentURL(id, "image"), key: key) else { return nil }
        return UIImage(data: data)
    }

    func attachmentData(_ id: UUID) -> Data? {
        guard let key else { return nil }
        return try? SealedFile.readData(from: attachmentURL(id, "image"), key: key)
    }

    func layers(_ id: UUID) -> DecorationLayers? {
        guard let key else { return nil }
        return try? SealedFile.read(DecorationLayers.self, from: attachmentURL(id, "layers"), key: key)
    }

    private func attachmentURL(_ id: UUID, _ part: String) -> URL {
        attachmentsURL.appending(path: "\(id.uuidString).\(part).sealed")
    }

    private func removeAttachments(_ ids: some Sequence<UUID>) {
        for id in ids {
            for part in ["image", "layers"] {
                try? FileManager.default.removeItem(at: attachmentURL(id, part))
            }
            images.removeObject(forKey: id.uuidString as NSString)
        }
    }

    /// Drops attachments no saved entry points to, e.g. from an editor that was cancelled. Runs at unlock, when no draft is open.
    private func pruneAttachments() {
        let referenced = Set(entries.flatMap(\.attachmentIDs))
        let files = (try? FileManager.default.contentsOfDirectory(at: attachmentsURL, includingPropertiesForKeys: nil)) ?? []
        let orphans = Set(files.compactMap { UUID(uuidString: String($0.lastPathComponent.prefix(36))) }).subtracting(referenced)
        removeAttachments(orphans)
    }

    func entry(on day: Date) -> DiaryEntry? {
        entries.first { Calendar.current.isDate($0.day, inSameDayAs: day) }
    }

    func save(_ entry: DiaryEntry) throws {
        var updated = entries
        var replaced: DiaryEntry?
        if let index = updated.firstIndex(where: { $0.id == entry.id || Calendar.current.isDate($0.day, inSameDayAs: entry.day) }) {
            replaced = updated[index]
            updated[index] = entry
        } else {
            updated.append(entry)
        }
        updated.sort { $0.day > $1.day }
        try persist(updated)
        entries = updated
        if let replaced {
            removeAttachments(replaced.attachmentIDs.subtracting(entry.attachmentIDs))
        }
    }

    /// A drawing page joins that day's entry (or starts one), so drawing-only days count as written.
    func saveDrawing(on day: Date, drawingID: UUID, caption: String, weather: Weather?) throws {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        var entry = self.entry(on: start) ?? DiaryEntry(
            id: UUID(), day: start, mood: nil, note: "", quick: false, fragments: [], createdAt: .now, updatedAt: .now
        )
        if let index = entry.fragments.firstIndex(where: { $0.kind == .drawing }) {
            entry.fragments[index].drawingID = drawingID
            entry.fragments[index].caption = caption
            entry.fragments[index].weather = weather
        } else {
            let drawnAt = calendar.isDateInToday(start) ? Date.now : start.addingTimeInterval(20 * 3600)
            entry.fragments.append(Fragment(
                sourceID: "drawing:\(UUID().uuidString)", kind: .drawing, start: drawnAt, caption: caption, drawingID: drawingID, weather: weather
            ))
            entry.fragments.sort { $0.start < $1.start }
        }
        entry.updatedAt = .now
        try save(entry)
        if calendar.isDateInToday(start) {
            UserDefaults.standard.set(start, forKey: ReminderSettings.lastEntryDayKey)
        }
    }

    func delete(_ entry: DiaryEntry) throws {
        let updated = entries.filter { $0.id != entry.id }
        try persist(updated)
        entries = updated
        removeAttachments(entry.attachmentIDs)
    }

    /// Crypto-shreds: the old key is destroyed along with the file, so any leftover copy is unreadable.
    func eraseEverything() throws {
        for url in [fileURL, attachmentsURL] where FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: url)
        }
        KeyVault.deleteKey()
        key = try KeyVault.loadOrCreateKey()
        entries = []
        images.removeAllObjects()
    }

    var streak: Int {
        let calendar = Calendar.current
        let days = Set(entries.map { calendar.startOfDay(for: $0.day) })
        var cursor = calendar.startOfDay(for: .now)
        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    var daysThisMonth: Int {
        entries.filter { Calendar.current.isDate($0.day, equalTo: .now, toGranularity: .month) }.count
    }

    private func persist(_ entries: [DiaryEntry]) throws {
        guard let key else { throw StoreError.locked }
        try SealedFile.write(entries, to: fileURL, key: key)
    }
}
