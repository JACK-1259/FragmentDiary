import SwiftUI
import WidgetKit

nonisolated struct FragmentsEntry: TimelineEntry {
    let date: Date
    let fragmentCount: Int?
    let wrote: Bool
    let streak: Int
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

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                dateHeader
                Spacer(minLength: 0)
                MiniStack(accent: accent)
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
                MiniStack(accent: accent, scale: 1.6)
                    .padding(.top, 6)
                Spacer(minLength: 0)
                if let streakText {
                    Text(streakText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
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
struct MiniStack: View {
    let accent: Color
    var scale: CGFloat = 1

    var body: some View {
        ZStack {
            card(Color(rgb: 0x9DB08F)).rotationEffect(.degrees(-10)).offset(x: -6 * scale, y: 2 * scale)
            card(Color(rgb: 0xE2B660)).rotationEffect(.degrees(8)).offset(x: 6 * scale)
            card(accent).rotationEffect(.degrees(-2)).offset(y: -2 * scale)
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
