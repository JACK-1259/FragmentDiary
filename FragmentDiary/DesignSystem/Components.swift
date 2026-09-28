import SwiftUI

extension DateText {
    static func timelineLabel(for fragment: Fragment) -> String {
        fragment.kind == .event && fragment.end == nil ? "종일" : time(fragment.start)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(Color.accentColor.opacity(isEnabled ? 1 : 0.35)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().stroke(Color.hairline, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.card))
            .overlay(Capsule().stroke(Color.hairline, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 18) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.card)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.hairline, lineWidth: 0.5)
        )
    }
}

struct DayHeader: View {
    let day: Date
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(DateText.weekday(day))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Text(DateText.day(day))
                .font(.system(size: 38, weight: .semibold, design: .serif))
                .foregroundStyle(Color.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct MoodPicker: View {
    @Binding var selection: Mood?
    var day: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Calendar.current.isDateInToday(day) ? "오늘의 결" : "그날의 결")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.inkMuted)
            HStack(spacing: 0) {
                ForEach(Mood.allCases) { mood in
                    let isSelected = selection == mood
                    Button {
                        withAnimation(.snappy) { selection = isSelected ? nil : mood }
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(mood.color)
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.ink, lineWidth: isSelected ? 2 : 0).padding(-4))
                                .scaleEffect(isSelected ? 1.08 : 1)
                                .opacity(selection == nil || isSelected ? 1 : 0.4)
                            Text(mood.label)
                                .font(.caption2.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.ink : Color.inkMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mood.label)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct MoodChip: View {
    let mood: Mood
    let day: Date

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(mood.color).frame(width: 10, height: 10)
            Text("\(Calendar.current.isDateInToday(day) ? "오늘의 결" : "그날의 결") · \(mood.label)")
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(mood.color.opacity(0.18)))
    }
}

struct NewBadge: View {
    var body: some View {
        Text("새 조각")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.accentColor.opacity(0.14)))
    }
}

/// Time on the left, a dot, and a hairline running down to the next moment.
struct TimelineRow<Content: View>: View {
    let label: String
    var showsLine = true
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Text(label)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(Color.inkMuted)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 7, height: 7)
            }
            .frame(width: 44)
            .padding(.top, 14)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)
        }
        .background(alignment: .topLeading) {
            if showsLine {
                Rectangle()
                    .fill(Color.hairline)
                    .frame(width: 1)
                    .padding(.top, 48)
                    .padding(.leading, 21.5)
            }
        }
    }
}

struct AssetThumbnail: View {
    let assetID: String
    @State private var image: UIImage?
    @State private var isMissing = false
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(Color.hairline)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else if isMissing {
                    Image(systemName: "photo")
                        .foregroundStyle(Color.inkMuted)
                }
            }
            .clipped()
            .task(id: assetID) {
                let loaded = await ThumbnailCache.shared.image(for: assetID, pixelSide: 320 * displayScale)
                withAnimation(.easeOut(duration: 0.2)) { image = loaded }
                isMissing = loaded == nil
            }
            .accessibilityHidden(true)
    }
}

struct PolaroidTile: View {
    let assetID: String
    let size: CGSize

    var body: some View {
        AssetThumbnail(assetID: assetID)
            .frame(width: size.width - 8, height: size.height - 8)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.card))
            .shadow(color: .black.opacity(0.14), radius: 6, y: 3)
    }
}

/// Overlapping, slightly tilted prints — the scrapbook look, kept restrained.
struct PhotoCollage: View {
    let assetIDs: [String]
    var height: CGFloat = 150

    var body: some View {
        let shown = Array(assetIDs.prefix(3))
        let tileHeight = height - 16
        let tileWidth = shown.count == 1 ? tileHeight * 1.3 : tileHeight * 0.78
        let step = tileWidth * 0.62
        let totalWidth = CGFloat(max(shown.count - 1, 0)) * step + tileWidth

        ZStack(alignment: .topLeading) {
            ForEach(Array(shown.enumerated()), id: \.element) { index, id in
                PolaroidTile(assetID: id, size: CGSize(width: tileWidth, height: tileHeight))
                    .rotationEffect(.degrees(stableAngle(for: id, maxDegrees: 3)))
                    .offset(x: CGFloat(index) * step)
                    .zIndex(Double(index))
            }
            if assetIDs.count > shown.count {
                Text("+\(assetIDs.count - shown.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.paper)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.ink.opacity(0.8)))
                    .offset(x: totalWidth - 40, y: tileHeight - 30)
                    .zIndex(10)
            }
        }
        .frame(width: totalWidth, height: tileHeight, alignment: .topLeading)
        .padding(.vertical, 8)
        .padding(.leading, 4)
        .accessibilityElement()
        .accessibilityLabel("사진 \(assetIDs.count)장")
    }
}

struct EventSummary: View {
    let fragment: Fragment
    var isNew = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(fragment.title ?? "일정")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    if isNew { NewBadge() }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var detail: String {
        var parts: [String] = []
        if let end = fragment.end {
            parts.append("\(DateText.time(fragment.start))–\(DateText.time(end))")
        } else {
            parts.append("하루 종일")
        }
        if let place = fragment.place {
            parts.append(place)
        }
        return parts.joined(separator: " · ")
    }
}

struct FragmentStackIllustration: View {
    var body: some View {
        ZStack {
            tile(symbol: "text.quote", color: Mood.calm.color)
                .rotationEffect(.degrees(-9))
                .offset(x: -70, y: 14)
            tile(symbol: "calendar", color: Mood.good.color)
                .rotationEffect(.degrees(7))
                .offset(x: 70, y: 4)
            tile(symbol: "photo", color: .accentColor)
                .rotationEffect(.degrees(-2))
                .offset(y: -14)
        }
        .frame(height: 210)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func tile(symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.85))
                .frame(height: 96)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                }
            Capsule().fill(Color.hairline).frame(height: 6)
            Capsule().fill(Color.hairline).frame(width: 52, height: 6)
        }
        .padding(8)
        .frame(width: 124)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.card))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }
}

struct PrivacyShield: View {
    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            Text("조각일기")
                .font(.system(.title, design: .serif, weight: .semibold))
                .foregroundStyle(Color.inkMuted)
        }
    }
}
