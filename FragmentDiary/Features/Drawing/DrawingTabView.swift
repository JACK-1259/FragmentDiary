import SwiftUI

/// The 그림 tab: today's page as a print on top, then an album of earlier drawings.
struct DrawingTabView: View {
    @Environment(JournalStore.self) private var store
    @State private var editing: EditTarget?
    @State private var path: [DrawingRef] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    todayCard
                    album
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color.paper)
            .navigationDestination(for: DrawingRef.self) { ref in
                DrawingDetailView(entryID: ref.entryID) { fragment, entry in
                    editing = EditTarget(day: entry.day, fragment: fragment)
                }
            }
        }
        .fullScreenCover(item: $editing) { target in
            DrawingEditorView(
                day: target.day,
                existing: target.fragment,
                layers: target.fragment?.drawingID.flatMap(store.layers)
            ) {
                editing = nil
            }
        }
    }

    private var drawings: [(entry: DiaryEntry, fragment: Fragment)] {
        store.entries.compactMap { entry in entry.drawing.map { (entry, $0) } }
    }

    private var todayDrawing: (entry: DiaryEntry, fragment: Fragment)? {
        drawings.first { Calendar.current.isDateInToday($0.entry.day) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("그림")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(Color.ink)
            let monthCount = drawings.filter { Calendar.current.isDate($0.entry.day, equalTo: .now, toGranularity: .month) }.count
            Text(monthCount > 0 ? "이번 달 그림 \(monthCount)장" : "글 대신 그림으로 하루를 남겨요")
                .font(.subheadline)
                .foregroundStyle(Color.inkMuted)
        }
    }

    private var todayCard: some View {
        VStack(spacing: 18) {
            Group {
                if let today = todayDrawing, let id = today.fragment.drawingID {
                    Button {
                        path.append(DrawingRef(entryID: today.entry.id))
                    } label: {
                        Print(caption: printCaption(today.fragment, day: today.entry.day)) {
                            JournalAttachmentImage(attachmentID: id)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Print(caption: "\(DateText.day(.now)) · 아직 그리지 않았어요") {
                        VStack(spacing: 10) {
                            Image(systemName: "scribble.variable")
                                .font(.system(size: 40, weight: .light))
                            Text("오늘 하루를 그림으로 남겨보세요")
                                .font(.subheadline)
                        }
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(rgb: DrawingDiary.paperRGB))
                    }
                }
            }
            .rotationEffect(.degrees(-1.5))
            .frame(maxWidth: 380)

            Button {
                editing = EditTarget(day: Calendar.current.startOfDay(for: .now), fragment: todayDrawing?.fragment)
            } label: {
                Label(todayDrawing == nil ? "오늘 그림 그리기" : "오늘 그림 이어 그리기", systemImage: "pencil.and.scribble")
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var album: some View {
        let past = drawings.filter { !Calendar.current.isDateInToday($0.entry.day) }
        if !past.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("지난 그림")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 14) {
                    ForEach(past, id: \.entry.id) { item in
                        Button {
                            path.append(DrawingRef(entryID: item.entry.id))
                        } label: {
                            VStack(spacing: 6) {
                                if let id = item.fragment.drawingID {
                                    JournalAttachmentThumbnail(attachmentID: id)
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.hairline, lineWidth: 0.5))
                                }
                                Text("\(DateText.day(item.entry.day)) \(DateText.shortWeekday(item.entry.day))")
                                    .font(.caption)
                                    .foregroundStyle(Color.inkMuted)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(DateText.day(item.entry.day)) 그림")
                    }
                }
            }
        }
    }

    private func printCaption(_ fragment: Fragment, day: Date) -> String {
        let date = DateText.day(day)
        let words = fragment.caption.replacingOccurrences(of: "\n", with: " ")
        return words.isEmpty ? date : "\(date) · \(words)"
    }

    struct EditTarget: Identifiable {
        let day: Date
        let fragment: Fragment?
        var id: String { "\(day.timeIntervalSince1970)-\(fragment?.drawingID?.uuidString ?? "new")" }
    }
}

struct DrawingRef: Hashable {
    let entryID: UUID
}

/// A polaroid-style print, the same scrapbook language as the photo collages.
private struct Print<Content: View>: View {
    let caption: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
                .aspectRatio(DrawingDiary.aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            Text(caption)
                .font(.system(.body, design: .serif))
                .foregroundStyle(Color(rgb: 0x2A2420))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(rgb: 0xFFFDF9)))
        .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
    }
}

/// One saved drawing page, with an edit action.
struct DrawingDetailView: View {
    let entryID: UUID
    let onEdit: (Fragment, DiaryEntry) -> Void

    @Environment(JournalStore.self) private var store

    var body: some View {
        Group {
            if let entry = store.entries.first(where: { $0.id == entryID }), let fragment = entry.drawing {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        DayHeader(day: entry.day)
                        DrawingPageView(fragment: fragment, day: entry.day)
                        if let mood = entry.mood {
                            MoodChip(mood: mood, day: entry.day)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("고쳐 그리기") { onEdit(fragment, entry) }
                    }
                }
            } else {
                ContentUnavailableView("그림을 찾을 수 없어요", systemImage: "scribble")
            }
        }
        .background(Color.paper)
        .navigationBarTitleDisplayMode(.inline)
    }
}
