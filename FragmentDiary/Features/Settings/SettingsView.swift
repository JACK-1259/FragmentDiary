import SwiftUI

struct SettingsView: View {
    @Environment(JournalStore.self) private var store
    @Environment(FolderStore.self) private var folderStore
    @Environment(AppLock.self) private var lock
    @Environment(FragmentCollector.self) private var collector
    @Environment(\.openURL) private var openURL
    @AppStorage(ReminderSettings.enabledKey) private var reminderEnabled = false
    @AppStorage(ReminderSettings.minutesKey) private var reminderMinutes = ReminderSettings.defaultMinutes
    @AppStorage(LocalIdentity.nameKey) private var displayName = ""
    @State private var confirmErase = false
    @State private var notificationsDenied = false
    @State private var errorText: String?

    var body: some View {
        @Bindable var lock = lock
        NavigationStack {
            Form {
                Group {
                    Section {
                        Toggle("\(lock.methodName)로 잠그기", isOn: $lock.enabled)
                            .disabled(lock.availability == .unavailable)
                    } header: {
                        Text("프라이버시")
                    } footer: {
                        Text(
                            lock.availability == .unavailable
                                ? "기기에 암호가 설정되어 있지 않아 잠금을 사용할 수 없어요."
                                : "앱을 떠나면 바로 잠기고, 앱 전환 화면에서도 내용이 가려져요.")
                    }

                    Section {
                        PermissionRow(
                            title: "사진", systemImage: "photo.on.rectangle", state: collector.photoState
                        ) {
                            await collector.requestPhotos()
                        }
                        PermissionRow(title: "캘린더", systemImage: "calendar", state: collector.calendarState) {
                            await collector.requestCalendar()
                        }
                    } header: {
                        Text("조각 모으기")
                    } footer: {
                        Text("사진과 일정은 기기 안에서만 읽어요. 스크린샷과 아직 시작하지 않은 일정은 제외돼요.")
                    }

                    Section {
                        Toggle("저녁 알림", isOn: $reminderEnabled)
                        if reminderEnabled {
                            DatePicker("시간", selection: reminderTime, displayedComponents: .hourAndMinute)
                        }
                    } header: {
                        Text("알림")
                    } footer: {
                        Text("그날 모인 조각 수에 맞춰 알려드려요. 이미 기록한 날엔 울리지 않아요.")
                    }

                    Section {
                        TextField("폴더에서 보일 내 이름", text: $displayName)
                    } header: {
                        Text("함께 쓰는 폴더")
                    } footer: {
                        Text("이미 만든 폴더의 이름 표시는 바뀌지 않아요. 동기화 연결 전까지 폴더 기록은 이 기기에만 저장돼요.")
                    }

                    Section {
                        ShareLink(item: MarkdownExporter.export(store.entries)) {
                            Label("텍스트로 내보내기", systemImage: "square.and.arrow.up")
                        }
                        .disabled(store.entries.isEmpty)
                        Button("모든 기록 삭제", role: .destructive) {
                            confirmErase = true
                        }
                    } header: {
                        Text("데이터")
                    } footer: {
                        Text("내보낸 텍스트는 암호화되지 않아요. 보관할 곳을 신중히 골라주세요.")
                    }

                    Section {
                        Label("계정, 서버, 분석 도구 없음", systemImage: "wifi.slash")
                        Label("모든 기록은 AES-256으로 암호화돼 이 기기에만 저장돼요", systemImage: "lock.doc")
                    } header: {
                        Text("조각일기의 약속")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.ink)
                }
                .listRowBackground(Color.card)
            }
            .tint(Color.accentColor)
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .navigationTitle("설정")
            .onAppear {
                lock.refreshAvailability()
                collector.refreshStatus()
            }
            .onChange(of: reminderEnabled) { _, enabled in
                Task {
                    if enabled, !(await ReminderScheduler.requestAuthorization()) {
                        reminderEnabled = false
                        notificationsDenied = true
                    }
                    await rescheduleReminders()
                }
            }
            .onChange(of: reminderMinutes) {
                Task { await rescheduleReminders() }
            }
            .confirmationDialog("모든 기록을 삭제할까요?", isPresented: $confirmErase, titleVisibility: .visible) {
                Button("모두 삭제", role: .destructive) { eraseAll() }
            } message: {
                Text("개인 일기와 함께 쓰는 폴더의 기록이 모두 지워지고, 암호화 키까지 파기돼서 되돌릴 수 없어요.")
            }
            .alert("알림이 꺼져 있어요", isPresented: $notificationsDenied) {
                Button("설정 열기") { openSystemSettings() }
                Button("닫기", role: .cancel) {}
            } message: {
                Text("설정 앱에서 조각일기의 알림을 허용해주세요.")
            }
            .alert(
                "문제가 생겼어요",
                isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })
            ) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: { ReminderSettings.date(fromMinutes: reminderMinutes) },
            set: { reminderMinutes = ReminderSettings.minutes(from: $0) }
        )
    }

    private func rescheduleReminders() async {
        await ReminderScheduler.reschedule(todayFragmentCount: collector.collect(on: .now).count)
    }

    private func eraseAll() {
        do {
            try folderStore.eraseEverything()
            try store.eraseEverything()
            try folderStore.unlock(key: KeyVault.loadOrCreateKey())
            UserDefaults.standard.removeObject(forKey: ReminderSettings.lastEntryDayKey)
            WidgetPublisher.publish(fragmentCount: collector.collect(on: .now).count, store: store)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

private struct PermissionRow: View {
    let title: String
    let systemImage: String
    let state: PermissionState
    let request: () async -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(Color.ink)
            Spacer()
            switch state {
            case .granted:
                Text("허용됨").foregroundStyle(Color.inkMuted)
            case .limited:
                Button("일부만 허용됨") { openSettings() }
            case .notDetermined:
                Button("허용하기") { Task { await request() } }
            case .denied:
                Button("설정에서 허용") { openSettings() }
            }
        }
        .font(.subheadline)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}
