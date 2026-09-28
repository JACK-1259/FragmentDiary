import SwiftUI

struct LockScreenView: View {
    @Environment(JournalStore.self) private var store
    @Environment(AppLock.self) private var lock
    @Environment(\.scenePhase) private var scenePhase
    // One automatic prompt per return to the foreground; the Face ID sheet itself flips scenePhase, so retrying on every .active would loop after a cancel.
    @State private var autoAttempted = false
    @State private var isAuthenticating = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Color.accentColor)
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
            if lock.isEffective {
                Button {
                    Task { await unlock() }
                } label: {
                    Label("\(lock.methodName)로 열기", systemImage: lock.symbolName)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isAuthenticating)
            }
        }
        .padding(24)
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
            try store.unlock(key: KeyVault.loadOrCreateKey())
            errorText = nil
        } catch {
            errorText = "기록을 여는 중 문제가 생겼어요.\n\(error.localizedDescription)"
        }
    }
}
