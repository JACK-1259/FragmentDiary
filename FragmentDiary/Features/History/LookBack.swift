import SwiftUI

/// "1년 전 오늘" — the same date in an earlier year, or a month ago when the journal is younger than that.
enum LookBack {
    struct Match {
        let entry: DiaryEntry
        let label: String
    }

    static func match(in store: JournalStore, today: Date = .now) -> Match? {
        let calendar = Calendar.current
        for years in 1...5 {
            if let day = calendar.date(byAdding: .year, value: -years, to: today), let entry = store.entry(on: day) {
                return Match(entry: entry, label: "\(years)년 전 오늘")
            }
        }
        if let day = calendar.date(byAdding: .month, value: -1, to: today), let entry = store.entry(on: day) {
            return Match(entry: entry, label: "한 달 전 오늘")
        }
        return nil
    }
}

/// A bookmark ribbon under the date: one photo, the mood and a line from that earlier day.
struct LookBackStrip: View {
    let match: LookBack.Match
    let onOpen: () -> Void

    var body: some View {
        let entry = match.entry
        Button(action: onOpen) {
            HStack(spacing: 12) {
                BookmarkRibbon()
                    .frame(width: 20, height: 46)
                if let photo = entry.previewPhotos.first {
                    PhotoRefThumbnail(photo: photo)
                        .frame(width: 44, height: 44)
                        .clipped()
                        .padding(3)
                        .background(Color.white)
                        .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
                        .rotationEffect(.degrees(-3))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text([match.label, entry.mood?.label].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.tint)
                    Text(summary(entry))
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(match.label) 기록 열기")
    }

    private func summary(_ entry: DiaryEntry) -> String {
        let text = entry.previewText.replacingOccurrences(of: "\n", with: " ")
        if !text.isEmpty { return text }
        return entry.fragments.isEmpty ? "그날의 기록" : "그날의 조각 \(entry.fragments.count)개"
    }
}

private struct BookmarkRibbon: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let w = proxy.size.width, h = proxy.size.height
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w / 2, y: h * 0.8))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.closeSubpath()
            }
            .fill(Color(rgb: 0xE85D6F))
        }
        .accessibilityHidden(true)
    }
}

struct IdentifiedID: Identifiable {
    let id: UUID
}
