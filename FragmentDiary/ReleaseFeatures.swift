import Foundation

/// What this release ships. 함께 (shared folders) waits for iCloud sync: until then a folder never leaves the
/// device, so showing it would promise sharing that can't happen.
enum ReleaseFeatures {
    static let sharedFolders = false
}

/// Test builds once filled the journal with made-up days and remembered their ids under this key. The first
/// unlock after updating removes exactly those days; installs that never had samples skip straight past.
enum SampleCleanup {
    private static let idsKey = "sampleJournalEntryIDs"

    @MainActor
    static func run(_ store: JournalStore) {
        guard let ids = UserDefaults.standard.stringArray(forKey: idsKey) else { return }
        let samples = Set(ids)
        do {
            for entry in store.entries where samples.contains(entry.id.uuidString) {
                try store.delete(entry)
            }
            UserDefaults.standard.removeObject(forKey: idsKey)
        } catch {
            // Left for the next unlock to finish.
        }
    }
}
