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

nonisolated struct FragmentsProvider: TimelineProvider {
    func placeholder(in context: Context) -> FragmentsEntry {
        FragmentsEntry(date: .now, fragmentCount: 5, wrote: false, streak: 3,
                       week: [.written, .written, .missed, .written, .today, .future, .future])
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
            streak: snapshot?.streak(on: date) ?? 0,
            week: WidgetSnapshot.week(containing: date, writtenDays: snapshot?.writtenDays ?? [])
        )
    }
}
