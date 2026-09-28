import Foundation

enum MarkdownExporter {
    static func export(_ entries: [DiaryEntry]) -> String {
        var lines = ["# 조각일기", ""]
        for entry in entries.sorted(by: { $0.day < $1.day }) {
            var heading = "## \(DateText.full(entry.day))"
            if let mood = entry.mood {
                heading += " · \(mood.label)"
            }
            lines.append(heading)
            for fragment in entry.fragments {
                lines.append("- \(DateText.time(fragment.start)) \(fragment.summaryLine)")
            }
            if !entry.note.isEmpty {
                lines.append("")
                lines.append(entry.note)
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
