import Foundation

/// How a calendar event or finished reminder is turned into a question the user can answer in a tap or a line.
enum Question {
    static func prompt(for fragment: Fragment) -> String {
        let title = fragment.title?.trimmed.nilIfEmpty ?? (fragment.kind == .reminder ? "할 일" : "일정")
        switch fragment.kind {
        case .reminder: return "‘\(title)’\(Josa.objectMarker(after: title)) 끝냈네요!"
        default: return "‘\(title)’, 어땠어요?"
        }
    }

    static func reactions(for kind: FragmentKind) -> [String] {
        switch kind {
        case .reminder: ["😌 후련해", "💪 뿌듯해", "🙂 별일 없었어"]
        default: ["😊 좋았어", "🙂 무난했어", "😮‍💨 지쳤어"]
        }
    }

    static func sourceLabel(for fragment: Fragment) -> String {
        switch fragment.kind {
        case .reminder: "미리 알림 · \(DateText.time(fragment.start))에 끝냄"
        default:
            [fragment.end == nil ? "하루 종일" : DateText.time(fragment.start), fragment.place]
                .compactMap { $0 }
                .joined(separator: " · ")
        }
    }
}

/// Picks 을/를 from the last syllable so questions read naturally whatever the title is.
nonisolated enum Josa {
    static func objectMarker(after word: String) -> String {
        guard let scalar = word.trimmed.unicodeScalars.last else { return "을(를)" }
        let value = scalar.value
        if (0xAC00...0xD7A3).contains(value) {
            return (value - 0xAC00) % 28 == 0 ? "를" : "을"
        }
        // Latin letters and digits: read the usual Korean pronunciation of the last character.
        let lastCharacter = Character(scalar).lowercased()
        if "aeiouwy".contains(lastCharacter) || "2459".contains(lastCharacter) { return "를" }
        if lastCharacter.first?.isLetter == true || lastCharacter.first?.isNumber == true { return "을" }
        return "을(를)"
    }
}

nonisolated extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
