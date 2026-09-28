import SwiftUI

struct EntryContentView: View {
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let mood = entry.mood {
                MoodChip(mood: mood, day: entry.day)
            }
            if entry.quick, !entry.note.isEmpty {
                Text(entry.note)
                    .font(.system(.title2, design: .serif))
                    .foregroundStyle(Color.ink)
                    .lineSpacing(4)
            }
            if !entry.fragments.isEmpty {
                VStack(spacing: 0) {
                    ForEach(entry.fragments) { fragment in
                        TimelineRow(label: DateText.timelineLabel(for: fragment), showsLine: fragment.id != entry.fragments.last?.id) {
                            FragmentReadView(fragment: fragment)
                        }
                    }
                }
            }
            if !entry.quick, !entry.note.isEmpty {
                Text(entry.note)
                    .font(.body)
                    .foregroundStyle(Color.ink)
                    .lineSpacing(6)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            }
        }
    }
}

private struct FragmentReadView: View {
    let fragment: Fragment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch fragment.kind {
            case .photos: PhotoCollage(assetIDs: fragment.assetIDs, height: 150)
            case .event: EventSummary(fragment: fragment)
            case .note: EmptyView()
            }
            if !fragment.caption.isEmpty {
                Text(fragment.caption)
                    .font(fragment.kind == .note ? .body : .subheadline)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
