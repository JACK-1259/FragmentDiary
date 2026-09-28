import CryptoKit
import Foundation
import Observation

/// The whole journal is one AES-GCM sealed JSON file, so dates, moods and captions are all encrypted at rest.
@Observable
final class JournalStore {
    enum StoreError: LocalizedError {
        case locked

        var errorDescription: String? { "일기가 잠겨 있어요." }
    }

    private(set) var entries: [DiaryEntry] = []
    private(set) var isUnlocked = false

    @ObservationIgnored private var key: SymmetricKey?
    @ObservationIgnored private let fileURL = URL.applicationSupportDirectory.appending(path: "journal.sealed")

    func unlock(key: SymmetricKey) throws {
        entries = (try SealedFile.read([DiaryEntry].self, from: fileURL, key: key) ?? []).sorted { $0.day > $1.day }
        self.key = key
        isUnlocked = true
    }

    func lock() {
        entries = []
        key = nil
        isUnlocked = false
    }

    func entry(on day: Date) -> DiaryEntry? {
        entries.first { Calendar.current.isDate($0.day, inSameDayAs: day) }
    }

    func save(_ entry: DiaryEntry) throws {
        var updated = entries
        if let index = updated.firstIndex(where: { $0.id == entry.id || Calendar.current.isDate($0.day, inSameDayAs: entry.day) }) {
            updated[index] = entry
        } else {
            updated.append(entry)
        }
        updated.sort { $0.day > $1.day }
        try persist(updated)
        entries = updated
    }

    func delete(_ entry: DiaryEntry) throws {
        let updated = entries.filter { $0.id != entry.id }
        try persist(updated)
        entries = updated
    }

    /// Crypto-shreds: the old key is destroyed along with the file, so any leftover copy is unreadable.
    func eraseEverything() throws {
        if FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: fileURL)
        }
        KeyVault.deleteKey()
        key = try KeyVault.loadOrCreateKey()
        entries = []
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
