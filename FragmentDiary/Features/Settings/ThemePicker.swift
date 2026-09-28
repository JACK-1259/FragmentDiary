import SwiftUI

struct ThemePicker: View {
    @AppStorage(AppTheme.storageKey, store: AppTheme.sharedDefaults) private var themeValue = AppTheme.default.storageValue
    @Environment(\.onThemeAccent) private var onAccent

    private var theme: AppTheme { AppTheme(storageValue: themeValue) }

    private var isCustom: Bool {
        if case .custom = theme { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 16) {
                ForEach(ThemePreset.allCases) { preset in
                    swatch(preset)
                }
            }

            ColorPicker(selection: customColor, supportsOpacity: false) {
                HStack(spacing: 8) {
                    Text("직접 고르기")
                        .foregroundStyle(Color.ink)
                    if isCustom {
                        Text("사용 중")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
            }

            Text("오늘 기록 완성")
                .font(.headline)
                .foregroundStyle(onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Capsule().fill(.tint))
                .accessibilityLabel("테마 미리보기")
        }
        .padding(.vertical, 6)
    }

    private func swatch(_ preset: ThemePreset) -> some View {
        let isSelected = theme == .preset(preset)
        return Button {
            withAnimation(.snappy) { themeValue = AppTheme.preset(preset).storageValue }
        } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.preset(preset).accent)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(Color.ink, lineWidth: isSelected ? 2 : 0).padding(-4))
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.preset(preset).onAccent)
                        }
                    }
                Text(preset.name)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.ink : Color.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var customColor: Binding<Color> {
        Binding {
            theme.accent
        } set: { color in
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            func channel(_ value: CGFloat) -> UInt32 { UInt32((min(max(value, 0), 1) * 255).rounded()) }
            themeValue = AppTheme.custom(channel(red) << 16 | channel(green) << 8 | channel(blue)).storageValue
        }
    }
}
