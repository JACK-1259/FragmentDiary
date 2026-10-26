import SwiftUI

struct LockScreenView: View {
    @Environment(JournalStore.self) private var store
    @Environment(FolderStore.self) private var folderStore
    @Environment(AppLock.self) private var lock
    @Environment(\.scenePhase) private var scenePhase
    // One automatic prompt per return to the foreground; the Face ID sheet itself flips scenePhase, so retrying on every .active would loop after a cancel.
    @State private var autoAttempted = false
    @State private var isAuthenticating = false
    @State private var errorText: String?
    /// The journal's files are here but their key isn't (e.g. restored from a backup without the keychain).
    @State private var keyMissing = false
    @State private var confirmFreshStart = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.tint)
            Text("조각일기")
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .foregroundStyle(Color.ink)
            Text("당신의 하루는 이 기기를 떠나지 않아요")
                .font(.subheadline)
                .foregroundStyle(Color.inkMuted)
            Spacer()
            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            if keyMissing {
                Button("새 일기장으로 시작하기") { confirmFreshStart = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .confirmationDialog("새 일기장으로 시작할까요?", isPresented: $confirmFreshStart, titleVisibility: .visible) {
                        Button("새로 시작하기") { startFresh() }
                        Button("취소", role: .cancel) {}
                    } message: {
                        Text("이 기기에서 열 수 없는 기록은 지우지 않고 따로 보관해 둬요. 지금 일기장은 빈 상태로 시작해요.")
                    }
            } else {
                Button {
                    Task { await unlock() }
                } label: {
                    if lock.isEffective {
                        Label("\(lock.methodName)로 열기", systemImage: lock.symbolName)
                    } else {
                        Label("열기", systemImage: "book.closed")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isAuthenticating)
            }
        }
        .padding(24)
        .readableColumn(520)
        // Real devices prompt for Face ID as soon as the lock appears; the simulator waits for a tap.
        #if !targetEnvironment(simulator)
        .task {
            if scenePhase == .active { await autoUnlock() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: autoAttempted = false
            case .active: Task { await autoUnlock() }
            default: break
            }
        }
        #endif
    }

    private func autoUnlock() async {
        guard !autoAttempted else { return }
        autoAttempted = true
        await unlock()
    }

    private func unlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        lock.refreshAvailability()
        if lock.isEffective {
            guard await lock.authenticate() else { return }
        }
        do {
            let key = try KeyVault.loadOrCreateKey()
            // Folders first: RootView reveals the app as soon as the journal reports unlocked.
            try folderStore.unlock(key: key)
            try store.unlock(key: key)
            SampleCleanup.run(store)
            errorText = nil
            keyMissing = false
        } catch KeyVault.VaultError.keyMissingForExistingJournal {
            keyMissing = true
            errorText = "이 기기에서 기록을 여는 열쇠를 찾지 못했어요.\n기기를 백업에서 복원했다면, 암호화된 백업이나 iCloud 백업으로 복원해야 기록이 함께 열려요."
        } catch {
            errorText = "기록을 여는 중 문제가 생겼어요.\n\(error.localizedDescription)"
        }
    }

    /// Moves the unreadable files aside (never deletes them) and opens an empty journal with a new key.
    private func startFresh() {
        do {
            try JournalFiles.setAsideUnreadable()
            keyMissing = false
            errorText = nil
            Task { await unlock() }
        } catch {
            errorText = "새로 시작하지 못했어요.\n\(error.localizedDescription)"
        }
    }
}
