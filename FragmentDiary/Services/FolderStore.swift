import CryptoKit
import Foundation
import Observation
import UIKit

/// Shared folders and their photo attachments, sealed with the same key as the private journal.
@Observable
final class FolderStore {
    private static let maxPhotosPerFragment = 6
    private static let attachmentMaxSide: CGFloat = 1600

    private(set) var folders: [SharedFolder] = []

    let sync: any FolderSync = UnconnectedFolderSync()

    @ObservationIgnored private var key: SymmetricKey?
    @ObservationIgnored private let fileURL = URL.applicationSupportDirectory.appending(path: "folders.sealed")
    @ObservationIgnored private let attachmentsURL = URL.applicationSupportDirectory.appending(path: "Attachments", directoryHint: .isDirectory)
    @ObservationIgnored private let thumbnails = NSCache<NSString, UIImage>()

    func unlock(key: SymmetricKey) throws {
        folders = try SealedFile.read([SharedFolder].self, from: fileURL, key: key) ?? []
        self.key = key
    }

    func lock() {
        folders = []
        key = nil
        thumbnails.removeAllObjects()
    }

    func folder(_ id: UUID) -> SharedFolder? {
        folders.first { $0.id == id }
    }

    @discardableResult
    func createFolder(name: String, colorIndex: Int, owner: Member) throws -> SharedFolder {
        let folder = SharedFolder(
            id: UUID(),
            name: name,
            colorIndex: colorIndex,
            createdAt: .now,
            ownerID: owner.id,
            members: [owner],
            posts: []
        )
        let updated = folders + [folder]
        try persist(updated)
        folders = updated
        return folder
    }

    func deleteFolder(_ id: UUID) throws {
        guard let folder = folder(id) else { return }
        let updated = folders.filter { $0.id != id }
        try persist(updated)
        folders = updated
        folder.posts.flatMap(\.attachmentIDs).forEach(removeAttachment)
    }

    /// Copies the chosen photos out of the library into sealed attachments, then adds the post.
    /// Decorated photos and drawing pages are copied from the journal's own attachments via `journalImage`.
    func post(_ entry: DiaryEntry, to folderID: UUID, author: UUID, journalImage: (UUID) -> Data?) async throws {
        guard let key else { throw JournalStore.StoreError.locked }
        var fragments: [PostFragment] = []
        for fragment in entry.fragments {
            var attachmentIDs: [UUID] = []
            if let drawingID = fragment.drawingID, let data = journalImage(drawingID) {
                let id = UUID()
                try SealedFile.writeData(data, to: attachmentURL(id), key: key)
                attachmentIDs.append(id)
            }
            for assetID in fragment.assetIDs.prefix(Self.maxPhotosPerFragment) {
                var data = fragment.decorations?[assetID].flatMap(journalImage)
                if data == nil {
                    data = await PhotoExport.jpeg(assetID: assetID, maxSide: Self.attachmentMaxSide)
                }
                guard let data else { continue }
                let id = UUID()
                try SealedFile.writeData(data, to: attachmentURL(id), key: key)
                attachmentIDs.append(id)
            }
            if (fragment.kind == .photos || fragment.kind == .drawing) && attachmentIDs.isEmpty && fragment.caption.isEmpty { continue }
            fragments.append(PostFragment(
                id: UUID(),
                kind: fragment.kind,
                start: fragment.start,
                end: fragment.end,
                title: fragment.title,
                place: fragment.place,
                caption: fragment.caption,
                attachmentIDs: attachmentIDs,
                weather: fragment.weather,
                reaction: fragment.reaction,
                // The page arrangement the author made in their journal comes along with the post.
                pageX: fragment.pageX,
                pageY: fragment.pageY,
                pageScale: fragment.pageScale,
                pageZ: fragment.pageZ
            ))
        }
        let post = SharedPost(id: UUID(), authorID: author, day: entry.day, createdAt: .now, mood: entry.mood, note: entry.note, fragments: fragments)
        try update(folderID) { $0.posts.append(post) }
    }

    /// Moves or resizes one print on a post's page and brings it to the top. Only the author's posts are arranged.
    func placeOnPage(_ fragmentID: String, post postID: UUID, in folderID: UUID, x: Double, y: Double, scale: Double) throws {
        try update(folderID) { folder in
            guard let p = folder.posts.firstIndex(where: { $0.id == postID }),
                  let f = folder.posts[p].fragments.firstIndex(where: { $0.id.uuidString == fragmentID }) else { return }
            folder.posts[p].fragments[f].pageX = x
            folder.posts[p].fragments[f].pageY = y
            folder.posts[p].fragments[f].pageScale = scale
            folder.posts[p].fragments[f].pageZ = Date.now.timeIntervalSince1970
        }
    }

    func resetPageLayout(post postID: UUID, in folderID: UUID) throws {
        try update(folderID) { folder in
            guard let p = folder.posts.firstIndex(where: { $0.id == postID }) else { return }
            for f in folder.posts[p].fragments.indices {
                folder.posts[p].fragments[f].pageX = nil
                folder.posts[p].fragments[f].pageY = nil
                folder.posts[p].fragments[f].pageScale = nil
                folder.posts[p].fragments[f].pageZ = nil
            }
        }
    }

    func deletePost(_ postID: UUID, in folderID: UUID) throws {
        guard let post = folder(folderID)?.posts.first(where: { $0.id == postID }) else { return }
        try update(folderID) { $0.posts.removeAll { $0.id == postID } }
        post.attachmentIDs.forEach(removeAttachment)
    }

    func thumbnail(for attachmentID: UUID) -> UIImage? {
        let cacheKey = attachmentID.uuidString as NSString
        if let hit = thumbnails.object(forKey: cacheKey) { return hit }
        guard let key,
              let data = try? SealedFile.readData(from: attachmentURL(attachmentID), key: key),
              let image = UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 480, height: 480))
        else { return nil }
        thumbnails.setObject(image, forKey: cacheKey)
        return image
    }

    func eraseEverything() throws {
        for url in [fileURL, attachmentsURL] where FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: url)
        }
        folders = []
        thumbnails.removeAllObjects()
    }

    private func update(_ folderID: UUID, _ change: (inout SharedFolder) -> Void) throws {
        var updated = folders
        guard let index = updated.firstIndex(where: { $0.id == folderID }) else { return }
        change(&updated[index])
        try persist(updated)
        folders = updated
    }

    private func persist(_ folders: [SharedFolder]) throws {
        guard let key else { throw JournalStore.StoreError.locked }
        try SealedFile.write(folders, to: fileURL, key: key)
    }

    private func attachmentURL(_ id: UUID) -> URL {
        attachmentsURL.appending(path: "\(id.uuidString).sealed")
    }

    private func removeAttachment(_ id: UUID) {
        try? FileManager.default.removeItem(at: attachmentURL(id))
        thumbnails.removeObject(forKey: id.uuidString as NSString)
    }
}
