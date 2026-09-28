import Foundation

/// Seam for the sync backend (CloudKit sharing is the intended one). Until it exists, folders live only on this device.
protocol FolderSync {
    var isAvailable: Bool { get }
    func inviteLink(for folder: SharedFolder) async throws -> URL
}

enum FolderSyncError: LocalizedError {
    case notConnected

    var errorDescription: String? { "아직 동기화가 연결되지 않았어요." }
}

struct UnconnectedFolderSync: FolderSync {
    var isAvailable: Bool { false }

    func inviteLink(for folder: SharedFolder) async throws -> URL {
        throw FolderSyncError.notConnected
    }
}
