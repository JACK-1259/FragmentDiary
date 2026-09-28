import SwiftUI

@main
struct FragmentDiaryApp: App {
    @State private var store = JournalStore()
    @State private var folderStore = FolderStore()
    @State private var lock = AppLock()
    @State private var collector = FragmentCollector()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(folderStore)
                .environment(lock)
                .environment(collector)
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskID)) {
            await BackgroundRefresh.run()
        }
    }
}

struct RootView: View {
    @Environment(JournalStore.self) private var store
    @Environment(FolderStore.self) private var folderStore
    @Environment(AppLock.self) private var lock
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            if !onboarded {
                OnboardingView { onboarded = true }
                    .transition(.opacity)
            } else if store.isUnlocked {
                MainTabView()
                    .transition(.opacity)
            } else {
                LockScreenView()
                    .transition(.opacity)
            }
            if scenePhase != .active && store.isUnlocked && lock.isEffective {
                PrivacyShield()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.isUnlocked)
        .animation(.easeInOut(duration: 0.3), value: onboarded)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            if lock.isEffective {
                store.lock()
                folderStore.lock()
            }
            BackgroundRefresh.schedule()
        }
    }
}

struct MainTabView: View {
    private enum MainTab {
        case today, history, together, settings
    }

    @State private var selection = MainTab.today

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tabItem { Label("오늘", systemImage: "square.stack") }
                .tag(MainTab.today)
            HistoryView()
                .tabItem { Label("기록", systemImage: "book.closed") }
                .tag(MainTab.history)
            FoldersView()
                .tabItem { Label("함께", systemImage: "person.2") }
                .tag(MainTab.together)
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(MainTab.settings)
        }
    }
}
