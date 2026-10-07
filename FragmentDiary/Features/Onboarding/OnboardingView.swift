import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(FragmentCollector.self) private var collector
    @Environment(AppLock.self) private var lock
    @AppStorage(ReminderSettings.enabledKey) private var reminderEnabled = false
    @AppStorage(ReminderSettings.minutesKey) private var reminderMinutes = ReminderSettings.defaultMinutes
    @State private var step = 0
    @State private var isWorking = false

    private let primaryTitles = ["시작하기", "사진 허용하기", "캘린더·미리 알림 허용하기", "알림 받기", "조각일기 시작하기"]
    private let secondaryTitles: [String?] = [nil, "나중에", "나중에", "괜찮아요", nil]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<primaryTitles.count, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.hairline))
                        .frame(width: index == step ? 22 : 8, height: 8)
                }
            }
            .animation(.snappy, value: step)
            .padding(.top, 20)
            .accessibilityHidden(true)

            ZStack {
                page(for: step)
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 14) {
                Button(primaryTitles[step]) {
                    Task { await primaryAction() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isWorking)

                Button(secondaryTitles[step] ?? " ") { advance() }
                    .font(.subheadline)
                    .foregroundStyle(Color.inkMuted)
                    .opacity(secondaryTitles[step] == nil ? 0 : 1)
                    .disabled(secondaryTitles[step] == nil)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .readableColumn(560)
        }
        .background(Color.paper.ignoresSafeArea())
    }

    @ViewBuilder
    private func page(for step: Int) -> some View {
        switch step {
        case 0:
            OnboardingPage(
                title: "쓰지 않아도\n쌓이는 일기",
                message: "사진과 일정으로 오늘 하루의 조각을 미리 모아둘게요. 당신은 고르고, 한 줄만 더하면 돼요."
            ) {
                MiniNotebook(scale: 5.8)
                    .frame(maxWidth: .infinity)
            }
        case 1:
            OnboardingPage(
                title: "오늘 찍은 사진이\n조각이 돼요",
                message: "사진은 기기 안에서만 읽고 어디에도 올리지 않아요. 스크린샷은 알아서 빼둘게요."
            ) {
                SymbolBadge(systemName: "photo.on.rectangle.angled")
            }
        case 2:
            OnboardingPage(
                title: "지나간 일정과 끝낸 일이\n질문이 돼요",
                message: "‘민지랑 점심’, 어땠어요? 처럼 물어볼게요. 버튼 한 번이나 한 줄로 답하면 돼요. 이미 지난 일정과 끝낸 할 일만 가져와요."
            ) {
                SymbolBadge(systemName: "calendar")
            }
        case 3:
            OnboardingPage(
                title: "하루 끝에\n살짝 알려드릴게요",
                message: "오늘 있었던 일정과 끝낸 일을 알려드려요. 잠금 화면에는 일정 이름 없이 개수만 보여요. 이미 기록한 날엔 조용히 있을게요."
            ) {
                SymbolBadge(systemName: "bell")
            } bottom: {
                DatePicker("알림 시간", selection: reminderTime, displayedComponents: .hourAndMinute)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.ink)
                    .padding(.top, 8)
            }
        default:
            OnboardingPage(
                title: "당신의 하루는\n이 기기를 떠나지 않아요",
                message: "조각일기는 인터넷을 쓰지 않아요."
            ) {
                SymbolBadge(systemName: "lock.shield")
            } bottom: {
                VStack(alignment: .leading, spacing: 14) {
                    PromiseRow(systemName: "person.crop.circle.badge.xmark", text: "계정도, 서버도, 분석 도구도 없어요")
                    PromiseRow(systemName: "lock.doc", text: "모든 기록은 AES-256으로 암호화돼요")
                    PromiseRow(systemName: "eye.slash", text: "앱 전환 화면에서도 내용이 가려져요")
                    if lock.availability != .unavailable {
                        Toggle("\(lock.methodName)로 잠그기", isOn: Binding(get: { lock.enabled }, set: { lock.enabled = $0 }))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.ink)
                            .padding(.top, 6)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: { ReminderSettings.date(fromMinutes: reminderMinutes) },
            set: { reminderMinutes = ReminderSettings.minutes(from: $0) }
        )
    }

    private func primaryAction() async {
        isWorking = true
        defer { isWorking = false }
        switch step {
        case 1: await collector.requestPhotos()
        case 2:
            await collector.requestCalendar()
            await collector.requestReminders()
        case 3: reminderEnabled = await ReminderScheduler.requestAuthorization()
        case primaryTitles.count - 1:
            onFinish()
            return
        default: break
        }
        advance()
    }

    private func advance() {
        withAnimation(.spring(duration: 0.45)) {
            step = min(step + 1, primaryTitles.count - 1)
        }
    }
}

private struct OnboardingPage<Top: View, Bottom: View>: View {
    let title: String
    let message: String
    @ViewBuilder var top: Top
    @ViewBuilder var bottom: Bottom

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            top
            Spacer().frame(height: 8)
            Text(title)
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(Color.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.body)
                .foregroundStyle(Color.inkMuted)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            bottom
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .readableColumn(560)
    }
}

extension OnboardingPage where Bottom == EmptyView {
    init(title: String, message: String, @ViewBuilder top: () -> Top) {
        self.init(title: title, message: message, top: top, bottom: { EmptyView() })
    }
}

private struct SymbolBadge: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 38))
            .foregroundStyle(.tint)
            .frame(width: 92, height: 92)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.tint.opacity(0.12)))
            .rotationEffect(.degrees(-4))
            .accessibilityHidden(true)
    }
}

private struct PromiseRow: View {
    let systemName: String
    let text: String

    var body: some View {
        Label {
            Text(text).foregroundStyle(Color.ink)
        } icon: {
            Image(systemName: systemName)
                .foregroundStyle(.tint)
                .frame(width: 26)
        }
        .font(.subheadline)
    }
}
