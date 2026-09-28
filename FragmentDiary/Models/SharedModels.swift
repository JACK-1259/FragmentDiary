import Foundation

nonisolated struct Member: Codable, Hashable, Identifiable, Sendable {
    enum Role: String, Codable, Sendable {
        case owner, member
    }

    var id: UUID
    var name: String
    var role: Role
    var colorIndex: Int
}

/// A fragment as it lives in a shared folder: photos are copied in as attachments, since members don't share a photo library.
nonisolated struct PostFragment: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var kind: FragmentKind
    var start: Date
    var end: Date?
    var title: String?
    var place: String?
    var caption: String
    var attachmentIDs: [UUID]

    var asFragment: Fragment {
        Fragment(sourceID: id.uuidString, kind: kind, start: start, end: end, title: title, place: place, caption: caption)
    }
}

nonisolated struct SharedPost: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var authorID: UUID
    var day: Date
    var createdAt: Date
    var mood: Mood?
    var note: String
    var fragments: [PostFragment]

    var attachmentIDs: [UUID] { fragments.flatMap(\.attachmentIDs) }
}

nonisolated struct SharedFolder: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var colorIndex: Int
    var createdAt: Date
    var ownerID: UUID
    var members: [Member]
    var posts: [SharedPost]

    func member(_ id: UUID) -> Member? {
        members.first { $0.id == id }
    }

    var latestPost: SharedPost? {
        posts.max { $0.createdAt < $1.createdAt }
    }
}

/// Who "me" is inside shared folders. Stays on this device until sync exists.
enum LocalIdentity {
    static let nameKey = "displayName"
    private static let idKey = "localMemberID"

    static var id: UUID {
        if let stored = UserDefaults.standard.string(forKey: idKey), let id = UUID(uuidString: stored) {
            return id
        }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: idKey)
        return id
    }

    static var name: String {
        UserDefaults.standard.string(forKey: nameKey) ?? ""
    }
}
