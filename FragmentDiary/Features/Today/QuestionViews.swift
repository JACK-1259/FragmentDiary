import SwiftUI

/// One compact row on the composer: how many questions today has, and a way into the deck.
struct QuestionSummaryRow: View {
    let draft: DraftModel
    let onOpen: () -> Void

    var body: some View {
        let questions = draft.items.filter { $0.fragment.kind.isQuestion }
        let answered = questions.filter(\.included).count
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.tint.opacity(0.14)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(Calendar.current.isDateInToday(draft.day) ? "오늘의 질문 \(questions.count)개" : "그날의 질문 \(questions.count)개")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.ink)
                    Text(answered > 0 ? "\(answered)개 답했어요 · \(titles(questions))" : titles(questions))
                        .font(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(answered == questions.count ? "다시 보기" : "답하기")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tint)
            }
            .padding(14)
            .cardStyle()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("일정과 끝낸 일에 대한 질문에 답해요")
    }

    private func titles(_ questions: [DraftModel.Item]) -> String {
        questions.compactMap(\.fragment.title).joined(separator: " · ")
    }
}

/// The question deck: one card at a time, answered with a reaction tap or a line.
struct QuestionDeckSheet: View {
    @Bindable var draft: DraftModel
    let onDone: () -> Void

    @State private var index: Int
    @FocusState private var writing: Bool

    init(draft: DraftModel, onDone: @escaping () -> Void) {
        self.draft = draft
        self.onDone = onDone
        // Start at the first unanswered question.
        let questions = draft.items.filter { $0.fragment.kind.isQuestion }
        _index = State(initialValue: questions.firstIndex { !$0.included } ?? 0)
    }

    private var ids: [String] { draft.questionIDs }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(Calendar.current.isDateInToday(draft.day) ? "오늘의 질문" : "그날의 질문")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Spacer()
                ProgressDots(count: ids.count, current: index, answered: answeredFlags)
            }
            .padding(.top, 28)

            if ids.indices.contains(index), let itemIndex = draft.items.firstIndex(where: { $0.id == ids[index] }) {
                QuestionCard(item: $draft.items[itemIndex], writing: $writing) {
                    draft.syncInclusion(of: ids[index])
                } onDrop: {
                    draft.dropAnswer(ids[index])
                }
                .id(ids[index])
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                .gesture(swipe)
            }

            HStack {
                if index > 0 {
                    Button("이전") { go(-1) }
                        .foregroundStyle(Color.inkMuted)
                } else if ids.count > 1 {
                    Button("건너뛰기") { go(1) }
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
                if index < ids.count - 1 {
                    Button("다음") { go(1) }
                        .fontWeight(.semibold)
                }
            }
            .font(.subheadline)

            Spacer(minLength: 0)

            Button("다 했어요") {
                writing = false
                onDone()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Color.paper)
        .animation(.snappy, value: index)
    }

    private var answeredFlags: [Bool] {
        ids.map { id in draft.items.first { $0.id == id }?.included ?? false }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 30).onEnded { value in
            if value.translation.width < -60 { go(1) } else if value.translation.width > 60 { go(-1) }
        }
    }

    private func go(_ step: Int) {
        writing = false
        index = min(max(index + step, 0), max(ids.count - 1, 0))
    }
}

private struct QuestionCard: View {
    @Binding var item: DraftModel.Item
    var writing: FocusState<Bool>.Binding
    let onAnswer: () -> Void
    let onDrop: () -> Void

    var body: some View {
        let fragment = item.fragment
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SourceTag(fragment: fragment)
                Spacer()
                if item.included {
                    Label("일기에 들어가요", systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            Text(Question.prompt(for: fragment))
                .font(.system(size: 25, weight: .semibold, design: .serif))
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(Question.sourceLabel(for: fragment))
                .font(.caption)
                .foregroundStyle(Color.inkMuted)

            FlowChips(options: Question.reactions(for: fragment.kind), selection: fragment.reaction) { picked in
                item.fragment.reaction = item.fragment.reaction == picked ? nil : picked
                onAnswer()
            }

            TextField("또는 한 줄 남기기…", text: $item.fragment.caption, axis: .vertical)
                .lineLimit(1...4)
                .focused(writing)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.hairline.opacity(0.55)))
                .onChange(of: item.fragment.caption) { onAnswer() }

            if item.included {
                Button("이 질문은 일기에서 빼기", action: onDrop)
                    .font(.footnote)
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.card.opacity(0.7))
                    .rotationEffect(.degrees(2.5))
                    .offset(x: 6, y: 8)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.card)
                    .shadow(color: .black.opacity(0.07), radius: 12, y: 5)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.hairline, lineWidth: 0.5))
        .sensoryFeedback(.selection, trigger: fragment.reaction)
    }
}

struct SourceTag: View {
    let fragment: Fragment

    var body: some View {
        let isReminder = fragment.kind == .reminder
        Label(isReminder ? "미리 알림 · 끝낸 일" : "캘린더", systemImage: isReminder ? "checklist" : "calendar")
            .font(.caption2.weight(.bold))
            .foregroundStyle(isReminder ? Color(rgb: 0x3E6FA8) : Color(rgb: 0xB04A26))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(isReminder ? Color(rgb: 0xE3EEF8) : Color(rgb: 0xF6E3DA)))
            .environment(\.colorScheme, .light)
    }
}

private struct FlowChips: View {
    let options: [String]
    let selection: String?
    let onPick: (String) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips }
            VStack(alignment: .leading, spacing: 8) { chips }
        }
    }

    private var chips: some View {
        ForEach(options, id: \.self) { option in
            let isOn = selection == option
            Button { onPick(option) } label: {
                Text(option)
                    .font(.subheadline.weight(isOn ? .semibold : .regular))
                    .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.ink))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(isOn ? AnyShapeStyle(.tint.opacity(0.16)) : AnyShapeStyle(Color.hairline.opacity(0.55))))
                    .overlay(Capsule().stroke(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 1.2))
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? .isSelected : [])
        }
    }
}

private struct ProgressDots: View {
    let count: Int
    let current: Int
    let answered: [Bool]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? AnyShapeStyle(.tint) : answered[safe: index] == true ? AnyShapeStyle(.tint.opacity(0.4)) : AnyShapeStyle(Color.hairline))
                    .frame(width: index == current ? 18 : 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(count)개 중 \(current + 1)번째")
    }
}

/// An answered question as it reads back in the diary.
struct QuestionAnswerView: View {
    let fragment: Fragment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SourceTag(fragment: fragment)
            Text(fragment.kind == .reminder ? "‘\(fragment.title ?? "")’ 끝냄" : (fragment.title ?? "일정"))
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.ink)
            if fragment.kind == .event, let place = fragment.place {
                Text(place)
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            if let reaction = fragment.reaction {
                Text(reaction)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.tint.opacity(0.12)))
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
