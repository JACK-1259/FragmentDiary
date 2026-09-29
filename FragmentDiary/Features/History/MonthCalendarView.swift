import SwiftUI

/// Month grid showing which days were written and which were missed. Tapping a written day opens it;
/// tapping a missed day starts filling it in.
struct MonthCalendarView: View {
    let entries: [DiaryEntry]
    let onOpen: (DiaryEntry) -> Void
    let onFill: (Date) -> Void

    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now

    private static let weekdayNames = ["일", "월", "화", "수", "목", "금", "토"]
    private static let cellSize: CGFloat = 38

    private enum DayState {
        case written(DiaryEntry), missed, today, future
        /// Before the first entry ever — not counted as missed, so the calendar doesn't scold for days before the diary existed.
        case beforeStart
    }

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        let today = calendar.startOfDay(for: .now)
        let byDay = Dictionary(entries.map { (calendar.startOfDay(for: $0.day), $0) }, uniquingKeysWith: { first, _ in first })
        let firstDay = byDay.keys.min()
        let days = daysInMonth
        let states = days.map { state(for: $0, byDay: byDay, today: today, firstDay: firstDay) }

        VStack(spacing: 14) {
            header(written: states.filter { if case .written = $0 { true } else { false } }.count,
                   missed: states.filter { if case .missed = $0 { true } else { false } }.count,
                   firstDay: firstDay)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    Text(Self.weekdayNames[(calendar.firstWeekday - 1 + i) % 7])
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.inkMuted)
                }
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: Self.cellSize)
                }
                ForEach(Array(zip(days, states).enumerated()), id: \.offset) { _, pair in
                    cell(day: pair.0, state: pair.1)
                }
            }

            legend
        }
        .padding(16)
        .cardStyle()
    }

    private func header(written: Int, missed: Int, firstDay: Date?) -> some View {
        let current = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        let earliest = firstDay.flatMap { calendar.dateInterval(of: .month, for: $0)?.start } ?? current
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(DateText.month(month))
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color.ink)
                Text(missed > 0 ? "기록 \(written)일 · 놓친 날 \(missed)일" : "기록 \(written)일")
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .contentTransition(.numericText())
            }
            Spacer()
            HStack(spacing: 4) {
                monthButton("chevron.left", label: "이전 달", enabled: month > earliest) { shiftMonth(-1) }
                monthButton("chevron.right", label: "다음 달", enabled: month < current) { shiftMonth(1) }
            }
        }
    }

    private func monthButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.hairline))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func cell(day: Date, state: DayState) -> some View {
        let number = Text(DateText.dayNumber(day)).font(.subheadline.monospacedDigit())
        switch state {
        case .written(let entry):
            Button { onOpen(entry) } label: {
                number.fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: Self.cellSize, height: Self.cellSize)
                    .background(Circle().fill(entry.mood.map { AnyShapeStyle($0.color) } ?? AnyShapeStyle(.tint)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(DateText.day(day)), 기록함")
        case .missed:
            Button { onFill(day) } label: {
                number.foregroundStyle(Color.inkMuted)
                    .frame(width: Self.cellSize, height: Self.cellSize)
                    .overlay(Circle().strokeBorder(Color.inkMuted.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(DateText.day(day)), 놓친 날")
            .accessibilityHint("눌러서 이 날을 채워요")
        case .today:
            number.fontWeight(.bold)
                .foregroundStyle(.tint)
                .frame(width: Self.cellSize, height: Self.cellSize)
                .overlay(Circle().strokeBorder(.tint, lineWidth: 1.8))
                .accessibilityLabel("\(DateText.day(day)), 오늘")
        case .future:
            number.foregroundStyle(Color.inkMuted.opacity(0.4))
                .frame(width: Self.cellSize, height: Self.cellSize)
        case .beforeStart:
            Button { onFill(day) } label: {
                number.foregroundStyle(Color.inkMuted.opacity(0.7))
                    .frame(width: Self.cellSize, height: Self.cellSize)
            }
            .buttonStyle(.plain)
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Circle().fill(.tint).frame(width: 10, height: 10)
                Text("쓴 날")
            }
            HStack(spacing: 6) {
                Circle().strokeBorder(Color.inkMuted.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
                    .frame(width: 10, height: 10)
                Text("놓친 날 · 눌러서 채우기")
            }
            Spacer(minLength: 0)
        }
        .font(.caption2)
        .foregroundStyle(Color.inkMuted)
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    private var leadingBlanks: Int {
        (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
    }

    private func state(for day: Date, byDay: [Date: DiaryEntry], today: Date, firstDay: Date?) -> DayState {
        if let entry = byDay[day] { return .written(entry) }
        if day == today { return .today }
        if day > today { return .future }
        if let firstDay, day >= firstDay { return .missed }
        return .beforeStart
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: month) else { return }
        withAnimation(.snappy) { month = next }
    }
}
