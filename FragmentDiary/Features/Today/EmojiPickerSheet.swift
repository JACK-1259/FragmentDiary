import SwiftUI

/// Picks up to eight emoji for an emoji-only fragment: tap from the grid, or type with the emoji keyboard.
struct EmojiPickerSheet: View {
    let onDone: (String) -> Void

    @State private var picked: String
    @State private var typed = ""

    static let limit = 8
    private static let groups: [(title: String, emoji: [String])] = [
        ("기분", ["😊", "😆", "🥰", "😌", "🥹", "😴", "😮‍💨", "😢", "😡", "🤒", "🤔", "😎"]),
        ("하루", ["☀️", "🌧️", "❄️", "🌈", "🌙", "⭐️", "🔥", "✨", "💤", "🎉", "💪", "🍀"]),
        ("먹고 놀고", ["☕️", "🍰", "🍜", "🍕", "🍺", "🍓", "🎬", "🎵", "📚", "🎮", "🏃", "🚶"]),
        ("곳곳", ["🏠", "🏢", "🏫", "🌳", "🌊", "⛰️", "✈️", "🚌", "🛍️", "🏥", "💻", "📷"]),
        ("마음", ["❤️", "💌", "🤝", "🙏", "👍", "👏", "🫶", "💔", "🐶", "🐱", "🌸", "🎁"]),
    ]

    init(initial: String, onDone: @escaping (String) -> Void) {
        self.onDone = onDone
        _picked = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    preview
                    HStack(spacing: 10) {
                        TextField("이모지 키보드로 직접 넣기", text: $typed)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.hairline.opacity(0.5)))
                            .onChange(of: typed) { _, new in
                                // Keep only emoji; letters typed by mistake are dropped.
                                let emoji = new.filter(\.isEmoji)
                                if !emoji.isEmpty { add(String(emoji)) }
                                if !new.isEmpty { typed = "" }
                            }
                    }
                    ForEach(Self.groups, id: \.title) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.inkMuted)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                                ForEach(group.emoji, id: \.self) { emoji in
                                    Button { add(emoji) } label: {
                                        Text(emoji)
                                            .font(.system(size: 32))
                                            .frame(maxWidth: .infinity, minHeight: 48)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(picked.count >= Self.limit)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.paper)
            .navigationTitle("이모지로 남기기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { onDone(Self.unchanged) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { onDone(picked) }
                        .disabled(picked.isEmpty)
                }
            }
        }
    }

    /// Returned on cancel; the composer treats it as "leave things as they were".
    static let unchanged = "\u{0}"

    private var preview: some View {
        HStack(spacing: 12) {
            Text(picked.isEmpty ? "아래에서 골라 주세요" : picked)
                .font(.system(size: picked.isEmpty ? 15 : 40))
                .foregroundStyle(Color.inkMuted)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            if !picked.isEmpty {
                Button {
                    picked.removeLast()
                } label: {
                    Image(systemName: "delete.left")
                        .font(.title3)
                        .foregroundStyle(Color.inkMuted)
                }
                .accessibilityLabel("하나 지우기")
            }
        }
        .padding(14)
        .cardStyle()
    }

    private func add(_ emoji: String) {
        for character in emoji where picked.count < Self.limit {
            picked.append(character)
        }
    }
}

extension Character {
    /// True for characters that render as emoji (not digits or symbols that merely have an emoji variant).
    var isEmoji: Bool {
        guard let first = unicodeScalars.first else { return false }
        return first.properties.isEmojiPresentation || (first.properties.isEmoji && unicodeScalars.count > 1)
    }
}
