import SwiftUI

/// The 기록 tab as a diary you leaf through, oldest page first like a real one: each month opens on a
/// calendar-and-contents page, followed by one page per written day. Month index tabs down the right edge
/// jump straight to a month's first page, and a strip of dates above the tab bar jumps to any day (its calendar
/// button opens a month view for days further away). It opens on the current month.
struct JournalBook: View {
    let entries: [DiaryEntry]
    let summary: String
    let onFill: (Date) -> Void

    @State private var position: BookPage?
    @State private var showsCalendar = false
    /// A missed day picked in the calendar sheet; filled once the sheet has gone, so two sheets never overlap.
    @State private var pendingFill: Date?

    enum BookPage: Hashable {
        case month(Date)
        case day(UUID)
    }

    private var calendar: Calendar { Calendar.current }

    private var currentMonthStart: Date {
        calendar.dateInterval(of: .month, for: .now)?.start ?? .now
    }

    /// Oldest month first, days in the order they were lived; the current month is always there so its
    /// missed days can be filled.
    private var months: [(month: Date, entries: [DiaryEntry])] {
        let grouped = Dictionary(grouping: entries) { calendar.dateInterval(of: .month, for: $0.day)?.start ?? $0.day }
        let keys = Set(grouped.keys).union([currentMonthStart]).sorted()
        return keys.map { ($0, grouped[$0, default: []].sorted { $0.day < $1.day }) }
    }

    private var pages: [BookPage] {
        months.flatMap { group in [.month(group.month)] + group.entries.map { .day($0.id) } }
    }

    private var dayPages: [UUID] {
        months.flatMap { $0.entries.map(\.id) }
    }

    var body: some View {
        let months = months
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(pages, id: \.self) { page in
                    pageView(page, months: months)
                        .containerRelativeFrame([.horizontal, .vertical])
                        // A page turning about the spine, rather than sliding flat.
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .rotation3DEffect(
                                    .degrees(phase.value * -28),
                                    axis: (x: 0, y: 1, z: 0),
                                    anchor: phase.value < 0 ? .trailing : .leading,
                                    perspective: 0.5
                                )
                                .opacity(1 - abs(phase.value) * 0.35)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: $position)
        .scrollIndicators(.hidden)
        .overlay(alignment: .top) {
            // Pinned to the page column's edge, so on iPad the tabs stay on the book, not the screen edge.
            MonthTabs(months: months.map(\.month), current: currentMonth) { month in
                withAnimation(.snappy) { position = .month(month) }
            }
            .padding(.top, 36)
            .frame(maxWidth: BookLayout.column, alignment: .trailing)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DayStrip(months: months, current: position ?? .month(currentMonthStart)) { id in
                withAnimation(.snappy) { position = .day(id) }
            } onCalendar: {
                showsCalendar = true
            }
        }
        .sheet(isPresented: $showsCalendar, onDismiss: {
            if let day = pendingFill {
                pendingFill = nil
                onFill(day)
            }
        }) {
            CalendarJumpSheet(entries: entries, month: currentMonth ?? currentMonthStart) { entry in
                showsCalendar = false
                withAnimation(.snappy) { position = .day(entry.id) }
            } onFill: { day in
                pendingFill = day
                showsCalendar = false
            }
        }
        .onAppear {
            if position == nil { position = .month(currentMonthStart) }
        }
    }

    /// The month the visible page belongs to, for highlighting its tab.
    private var currentMonth: Date? {
        switch position ?? .month(currentMonthStart) {
        case .month(let month): month
        case .day(let id): entries.first { $0.id == id }.flatMap { calendar.dateInterval(of: .month, for: $0.day)?.start }
        }
    }

    @ViewBuilder
    private func pageView(_ page: BookPage, months: [(month: Date, entries: [DiaryEntry])]) -> some View {
        switch page {
        case .month(let month):
            CalendarPage(
                month: month,
                entries: entries,
                summary: summary,
                monthEntries: months.first { $0.month == month }?.entries ?? [],
                pageNumber: { id in (dayPages.firstIndex(of: id) ?? 0) + 1 },
                onOpen: { entry in withAnimation(.snappy) { position = .day(entry.id) } },
                onFill: onFill
            )
        case .day(let id):
            if let entry = entries.first(where: { $0.id == id }) {
                DayPage(entry: entry, number: (dayPages.firstIndex(of: id) ?? 0) + 1, total: dayPages.count)
            }
        }
    }
}

enum BookLayout {
    /// The widest a page gets, tabs included; iPad leaves the rest as desk.
    static let column: CGFloat = 760
}

/// A month's first page: the calendar, then a table of contents.
private struct CalendarPage: View {
    let month: Date
    let entries: [DiaryEntry]
    let summary: String
    let monthEntries: [DiaryEntry]
    let pageNumber: (UUID) -> Int
    let onOpen: (DiaryEntry) -> Void
    let onFill: (Date) -> Void

    var body: some View {
        BookSheet {
            VStack(alignment: .leading, spacing: 18) {
                MonthCalendarView(entries: entries, month: month, showsMonthArrows: false, bare: true, onOpen: onOpen, onFill: onFill)
                    .id(month)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(Color(rgb: 0x8A7F75))
                if !monthEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("차례")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(Color(rgb: 0x2A2420))
                            .padding(.bottom, 4)
                        ForEach(monthEntries) { entry in
                            Button { onOpen(entry) } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("\(DateText.dayNumber(entry.day))일 \(DateText.shortWeekday(entry.day))")
                                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                                    Text(entry.previewText.replacingOccurrences(of: "\n", with: " "))
                                        .font(.system(.subheadline, design: .serif))
                                        .lineLimit(1)
                                    Spacer(minLength: 6)
                                    Text("p.\(pageNumber(entry.id))")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(Color(rgb: 0x8A7F75))
                                }
                                .foregroundStyle(Color(rgb: 0x3B3029))
                                .padding(.vertical, 9)
                                .overlay(alignment: .bottom) { Rectangle().fill(Color(rgb: 0xE6DCCD)).frame(height: 1) }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Text("밀어서 넘기기 ›")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

/// One written day: its date, page number and the notebook page itself.
private struct DayPage: View {
    let entry: DiaryEntry
    let number: Int
    let total: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .lastTextBaseline) {
                    DayHeader(day: entry.day)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        NavigationLink(value: entry.id) {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(.tint)
                        }
                        .accessibilityLabel("수정·삭제")
                        Text("p.\(number) / \(total)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                JournalPageView(entry: entry)
                    .overlay(alignment: .bottomTrailing) { PageCurl() }
            }
            .padding(.leading, 26)
            .padding(.trailing, 44)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: BookLayout.column)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }
}

/// A page with the stack of pages behind it showing, so the book has some thickness.
private struct BookSheet<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            content
                .padding(.leading, 34)
                .padding(.trailing, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    ZStack {
                        sheet(Color(rgb: 0xEFE6D8)).offset(x: 6, y: 6)
                        sheet(Color(rgb: 0xF6EEE2)).offset(x: 3, y: 3)
                        sheet(Color(rgb: 0xFFFDF6)).shadow(color: .black.opacity(0.10), radius: 14, y: 6)
                    }
                }
                .overlay(alignment: .leading) { BookRings() }
                .environment(\.colorScheme, .light)
                .padding(.leading, 26)
                .padding(.trailing, 44)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: BookLayout.column)
                .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func sheet(_ color: Color) -> some View {
        UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 6, bottomTrailingRadius: 16, topTrailingRadius: 16, style: .continuous)
            .fill(color)
    }
}

private struct BookRings: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 26
            while y < size.height - 16 {
                context.fill(Path(roundedRect: CGRect(x: 0, y: y, width: 26, height: 10), cornerRadius: 5), with: .color(Color(rgb: 0x6B5E7A)))
                y += 46
            }
        }
        .frame(width: 26)
        .offset(x: -10)
        .accessibilityHidden(true)
    }
}

/// The folded bottom corner that says there's another page.
private struct PageCurl: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 44, y: 0))
                path.addLine(to: CGPoint(x: 44, y: 44))
                path.addLine(to: CGPoint(x: 0, y: 44))
                path.closeSubpath()
            }
            // The corner is folded away, so what shows there is the desk behind the page.
            .fill(Color.paper)
            Path { path in
                path.move(to: CGPoint(x: 44, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 44))
                path.addLine(to: CGPoint(x: 6, y: 6))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(rgb: 0xE8DCCB), Color(rgb: 0xFBF5EA)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .shadow(color: .black.opacity(0.12), radius: 3, x: -2, y: -2)
        }
        .frame(width: 44, height: 44)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Every written day in a row above the tab bar, scrolled to keep the open page in view. The calendar button in
/// front opens a month view for jumping further.
private struct DayStrip: View {
    let months: [(month: Date, entries: [DiaryEntry])]
    let current: JournalBook.BookPage
    let onSelect: (UUID) -> Void
    let onCalendar: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onCalendar) {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundStyle(Color.ink)
                    .frame(width: 44, height: 54)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.inkMuted.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("달력에서 날짜 고르기")

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 6) {
                        ForEach(months, id: \.month) { group in
                            if !group.entries.isEmpty {
                                Text("\(Calendar.current.component(.month, from: group.month))월")
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(Color.inkMuted)
                                    .padding(.horizontal, 2)
                                    .id(group.month)
                                ForEach(group.entries) { entry in
                                    chip(entry).id(entry.id)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 5)
                    .padding(.trailing, 4)
                }
                .scrollIndicators(.hidden)
                // A horizontal scroll view is greedy vertically; pin it to the chips' height.
                .frame(height: 66)
                .onAppear { reveal(in: proxy, animated: false) }
                .onChange(of: current) { reveal(in: proxy, animated: true) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: BookLayout.column)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(stops: [.init(color: Color.paper.opacity(0), location: 0), .init(color: Color.paper, location: 0.14)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func chip(_ entry: DiaryEntry) -> some View {
        let isOn = current == .day(entry.id)
        return Button { onSelect(entry.id) } label: {
            VStack(spacing: 3) {
                Text(DateText.dayNumber(entry.day))
                    .font(.system(size: 15, weight: .bold))
                Text(DateText.shortWeekday(entry.day))
                    .font(.system(size: 10))
                    .foregroundStyle(isOn ? Color.white.opacity(0.8) : Color.inkMuted)
                Circle()
                    .fill(entry.mood?.color ?? Color.hairline)
                    .overlay(Circle().stroke(Color.white.opacity(isOn ? 0.9 : 0), lineWidth: 1))
                    .frame(width: 6, height: 6)
            }
            .foregroundStyle(isOn ? Color.white : Color.ink)
            .frame(width: 40, height: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.card))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.hairline, lineWidth: isOn ? 0 : 1)
            )
            .offset(y: isOn ? -3 : 0)
            .animation(.snappy(duration: 0.2), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(DateText.full(entry.day))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// Keeps the open day (or, on a month's first page, that month's label) in the middle of the strip.
    private func reveal(in proxy: ScrollViewProxy, animated: Bool) {
        let target: AnyHashable = switch current {
        case .day(let id): AnyHashable(id)
        case .month(let month): AnyHashable(month)
        }
        if animated {
            withAnimation(.snappy) { proxy.scrollTo(target, anchor: .center) }
        } else {
            proxy.scrollTo(target, anchor: .center)
        }
    }
}

/// The month calendar in a sheet: a written day opens its page, a missed day starts filling it in.
private struct CalendarJumpSheet: View {
    let entries: [DiaryEntry]
    let month: Date
    let onOpen: (DiaryEntry) -> Void
    let onFill: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                MonthCalendarView(entries: entries, month: month, onOpen: onOpen, onFill: onFill)
                    .padding(20)
                    .readableColumn()
            }
            .background(Color.paper)
            .navigationTitle("날짜로 가기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.68), .large])
    }
}

/// Index tabs sticking out of the book's right edge, oldest month on top.
private struct MonthTabs: View {
    let months: [Date]
    let current: Date?
    let onSelect: (Date) -> Void

    var body: some View {
        VStack(spacing: 6) {
            // The latest eight; older months are a swipe back from the first tab.
            ForEach(Array(months.suffix(8).enumerated()), id: \.element) { index, month in
                let isOn = month == current
                Button { onSelect(month) } label: {
                    Text(label(month))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isOn ? Color.white : Color(rgb: 0x8A7F75))
                        .frame(width: 34, height: 42)
                        .background(
                            UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8, style: .continuous)
                                .fill(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(rgb: 0xF0D4C6).opacity(index.isMultiple(of: 2) ? 1 : 0.75)))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(DateText.month(month)) 첫 장으로")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    /// "10월", with the year added in January or for another year so tabs stay unambiguous.
    private func label(_ month: Date) -> String {
        let calendar = Calendar.current
        let m = calendar.component(.month, from: month)
        let y = calendar.component(.year, from: month)
        if y != calendar.component(.year, from: .now) { return "\(y % 100)'\n\(m)월" }
        return "\(m)월"
    }
}
