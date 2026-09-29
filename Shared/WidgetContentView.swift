import SwiftUI
import WidgetKit

nonisolated struct FragmentsEntry: TimelineEntry {
    let date: Date
    let fragmentCount: Int?
    let wrote: Bool
    let streak: Int
    /// Monday through Sunday of the week containing `date`.
    let week: [DayState]
}

struct FragmentsWidgetView: View {
    let entry: FragmentsEntry
    /// Set only by the debug preview screen, which can't write the read-only `\.widgetFamily` key.
    var previewFamily: WidgetFamily?
    @Environment(\.widgetFamily) private var envFamily
    private let accent = AppTheme.current.accent

    private var family: WidgetFamily { previewFamily ?? envFamily }

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

    private var weekText: String {
        let days = entry.week.filter { $0 == .written }.count
        return days == 0 ? "이번 주 첫 조각을 기다려요" : "이번 주 \(days)일 기록"
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
                .foregroundStyle(accent)
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
                .foregroundStyle(accent)
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

    /// After writing, the streak is the more useful line than "오늘 기록 완료" (the checkmark already says that).
    private var footerText: String {
        entry.wrote ? (streakText ?? statusText) : statusText
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                dateHeader
                Spacer(minLength: 0)
                WeekNotebook(days: entry.week, accent: accent, width: 50)
            }
            Spacer(minLength: 0)
            countBlock
            Text(footerText)
                .font(.caption2)
                .foregroundStyle(Color.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                dateHeader
                Spacer(minLength: 4)
                countBlock
                Text(footerText)
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                WeekNotebook(days: entry.week, accent: accent, width: 66)
                Text(weekText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
