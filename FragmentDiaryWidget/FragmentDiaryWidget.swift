import SwiftUI
import WidgetKit

@main
struct FragmentDiaryWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayFragmentsWidget()
    }
}

struct TodayFragmentsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayFragments", provider: FragmentsProvider()) { entry in
            FragmentsWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.paper }
        }
        .configurationDisplayName("오늘의 조각")
        .description("오늘 모인 조각 수와 기록 여부만 보여줘요. 일기 내용은 표시하지 않아요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

nonisolated struct FragmentsEntry: TimelineEntry {
    let date: Date
    let fragmentCount: Int?
    let wrote: Bool
    let streak: Int
}

nonisolated struct FragmentsProvider: TimelineProvider {
    func placeholder(in context: Context) -> FragmentsEntry {
        FragmentsEntry(date: .now, fragmentCount: 5, wrote: false, streak: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (FragmentsEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(for: .now))
    }

    /// Adds a midnight entry so the widget flips to the new day even if the app isn't opened.
    func getTimeline(in context: Context, completion: @escaping (Timeline<FragmentsEntry>) -> Void) {
        let now = Date.now
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
        completion(Timeline(entries: [entry(for: now), entry(for: midnight)], policy: .atEnd))
    }

    private func entry(for date: Date) -> FragmentsEntry {
        let snapshot = WidgetSnapshot.load()
        return FragmentsEntry(
            date: date,
            fragmentCount: snapshot?.fragmentCount(on: date),
            wrote: snapshot?.wrote(on: date) ?? false,
            streak: snapshot?.streak(on: date) ?? 0
        )
    }
}

struct FragmentsWidgetView: View {
    let entry: FragmentsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: Text(inlineText)
        case .systemMedium: medium
        default: small
        }
    }

    private var countText: String {
        entry.fragmentCount.map(String.init) ?? "·"
    }

    private var statusText: String {
        if entry.wrote { return "오늘 기록 완료" }
        guard let count = entry.fragmentCount else { return "앱을 열면 조각이 모여요" }
        return count > 0 ? "30초면 기록 끝" : "한 줄만 남겨도 충분해요"
    }

    private var streakText: String? {
        entry.streak >= 2 ? "\(entry.streak)일째 이어가는 중" : nil
    }

    private var inlineText: String {
        if entry.wrote { return "조각일기 · 오늘 기록 완료" }
        if let count = entry.fragmentCount { return "조각일기 · 조각 \(count)개 모임" }
        return "조각일기"
    }

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(DateText.weekday(entry.date))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.terracotta)
            Text(DateText.day(entry.date))
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(Color.ink)
        }
    }

    @ViewBuilder
    private var countBlock: some View {
        if entry.wrote {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.terracotta)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(countText)
                    .font(.system(size: 42, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.ink)
                    .contentTransition(.numericText())
                Text("조각")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.inkMuted)
            }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                dateHeader
                Spacer(minLength: 0)
                MiniStack()
            }
            Spacer(minLength: 4)
            countBlock
            Text(streakText.map { entry.wrote ? $0 : statusText } ?? statusText)
                .font(.caption2)
                .foregroundStyle(Color.inkMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                dateHeader
                Spacer(minLength: 4)
                countBlock
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 8) {
                MiniStack(scale: 1.6)
                    .padding(.top, 6)
                Spacer(minLength: 0)
                if let streakText {
                    Text(streakText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.terracotta)
                }
                Text("일기 내용은 앱 안에만 있어요")
                    .font(.caption2)
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.wrote {
                Image(systemName: "checkmark")
                    .font(.title2.weight(.bold))
            } else {
                VStack(spacing: -2) {
                    Text(countText)
                        .font(.system(.title2, design: .serif, weight: .semibold))
                    Text("조각")
                        .font(.system(size: 10, weight: .medium))
                }
            }
        }
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("조각일기")
                .font(.headline)
                .widgetAccentable()
            Text(entry.wrote ? "오늘 기록 완료" : entry.fragmentCount.map { "오늘 조각 \($0)개" } ?? "오늘의 조각 모으는 중")
                .font(.subheadline)
            Text(streakText ?? statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The app's three-card motif, small enough for a widget corner.
private struct MiniStack: View {
    var scale: CGFloat = 1

    var body: some View {
        ZStack {
            card(Color(rgb: 0x9DB08F)).rotationEffect(.degrees(-10)).offset(x: -6 * scale, y: 2 * scale)
            card(Color(rgb: 0xE2B660)).rotationEffect(.degrees(8)).offset(x: 6 * scale)
            card(Color.terracotta).rotationEffect(.degrees(-2)).offset(y: -2 * scale)
        }
        .frame(width: 30 * scale, height: 26 * scale)
        .accessibilityHidden(true)
    }

    private func card(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3 * scale, style: .continuous)
            .fill(color)
            .frame(width: 14 * scale, height: 18 * scale)
            .overlay(RoundedRectangle(cornerRadius: 3 * scale, style: .continuous).stroke(Color.card, lineWidth: 1.5))
    }
}
