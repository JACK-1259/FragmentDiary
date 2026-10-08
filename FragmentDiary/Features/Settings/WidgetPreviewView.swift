#if DEBUG
import SwiftUI
import WidgetKit

/// Renders the widget's own SwiftUI view at every declared family so lock screen sizes can be
/// checked without fighting the simulator's Lock Screen editor. Colors won't exactly match the
/// system's on-device vibrancy pass for accessory families, but layout and overflow are real.
struct WidgetPreviewView: View {
    private let sampleEntries: [(title: String, entry: FragmentsEntry)] = [
        ("조각 5개, 미기록", FragmentsEntry(date: .now, fragmentCount: 5, wrote: false, streak: 0)),
        ("기록 완료, 3일째", FragmentsEntry(date: .now, fragmentCount: 5, wrote: true, streak: 3)),
        ("조각 0개", FragmentsEntry(date: .now, fragmentCount: 0, wrote: false, streak: 0)),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(sampleEntries, id: \.title) { sample in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(sample.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ink)

                        Text("홈 화면 - 작은").font(.caption).foregroundStyle(Color.inkMuted)
                        family(.systemSmall, size: CGSize(width: 155, height: 155), entry: sample.entry, dark: false)
                        Text("홈 화면 - 중간").font(.caption).foregroundStyle(Color.inkMuted)
                        family(.systemMedium, size: CGSize(width: 329, height: 155), entry: sample.entry, dark: false)

                        Text("잠금 화면 - 원형 (배경은 검정으로 흉내만 낸 것, 실제 시스템은 흑백/색조 처리를 더 해요)")
                            .font(.caption)
                            .foregroundStyle(Color.inkMuted)
                        family(.accessoryCircular, size: CGSize(width: 72, height: 72), entry: sample.entry, dark: true)
                        Text("잠금 화면 - 사각형").font(.caption).foregroundStyle(Color.inkMuted)
                        family(.accessoryRectangular, size: CGSize(width: 172, height: 72), entry: sample.entry, dark: true)
                        Text("잠금 화면 - 한 줄").font(.caption).foregroundStyle(Color.inkMuted)
                        family(.accessoryInline, size: CGSize(width: 360, height: 24), entry: sample.entry, dark: true)
                    }
                    .padding(14)
                    .cardStyle()
                }
            }
            .padding(20)
        }
        .background(Color.paper)
        .navigationTitle("위젯 미리보기 (디버그)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func family(_ family: WidgetFamily, size: CGSize, entry: FragmentsEntry, dark: Bool) -> some View {
        FragmentsWidgetView(entry: entry, previewFamily: family)
            // Approximates the system's Lock Screen vibrancy: default (uncolored) text renders white there, not black.
            .environment(\.colorScheme, dark ? .dark : .light)
            // Home Screen widgets get the system's 16pt content margins; accessory families get none.
            .padding(dark ? 0 : 16)
            .frame(width: size.width, height: size.height)
            .padding(dark ? 8 : 0)
            .background(dark ? Color.black : Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: dark ? 16 : 22, style: .continuous))
    }
}
#endif
