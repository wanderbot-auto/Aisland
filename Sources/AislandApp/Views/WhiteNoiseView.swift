import CoreText
import SwiftUI

struct WhiteNoiseView: View {
    var model: AppModel
    @Environment(\.islandTheme) private var theme

    private let columns = [
        GridItem(.adaptive(minimum: 132, maximum: 180), spacing: 8, alignment: .top)
    ]

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.vertical) {
                VStack(spacing: 14) {
                    categories
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            controlsBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            WhiteNoiseBrandFonts.registerIfNeeded()
        }
    }

    private var categories: some View {
        VStack(spacing: 14) {
            ForEach(model.whiteNoiseCategories) { category in
                categorySection(category)
            }
        }
    }

    private func categorySection(_ category: WhiteNoiseCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: category.systemImageName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.primary.opacity(0.9))
                Text(localizedCategoryTitle(category))
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                Text("\(category.sounds.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer(minLength: 0)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(category.sounds) { sound in
                    soundCard(sound)
                }
            }
        }
    }

    private func soundCard(_ sound: WhiteNoiseSound) -> some View {
        let selected = model.whiteNoiseState.contains(sound.id)
        let volume = model.whiteNoiseState.volume(for: sound.id)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: sound.systemImageName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? theme.onPrimary.opacity(0.78) : theme.textSecondary.opacity(0.78))
                    .frame(width: 24, height: 24)
                    .background(selected ? theme.onPrimary.opacity(0.20) : theme.surfaceContainerHighest.opacity(0.54), in: Circle())
                Text(sound.label)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(selected ? theme.onPrimary.opacity(0.82) : theme.text.opacity(0.72))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if selected {
                HStack(spacing: 7) {
                    Slider(
                        value: Binding(
                            get: { volume },
                            set: { model.setWhiteNoiseVolume($0, for: sound) }
                        ),
                        in: 0...1
                    )
                    .tint(theme.onPrimary.opacity(0.76))
                    Text(percent(volume))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.onPrimary.opacity(0.58))
                        .frame(width: 32, alignment: .trailing)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(selected ? theme.primary : theme.card.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(selected ? theme.primaryContainer.opacity(0.35) : theme.outline.opacity(0.12), lineWidth: 0.8)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .onTapGesture {
            model.toggleWhiteNoiseSound(sound)
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: selected)
    }

    private var controlsBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Label(model.lang.t("whiteNoise.globalVolume"), systemImage: "slider.horizontal.3")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Slider(
                    value: Binding(
                        get: { model.whiteNoiseState.globalVolume },
                        set: { model.setWhiteNoiseGlobalVolume($0) }
                    ),
                    in: 0...1
                )
                .tint(theme.primary)
                Text(percent(model.whiteNoiseState.globalVolume))
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.48))
                    .frame(width: 36, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button {
                    model.toggleWhiteNoisePaused()
                } label: {
                    Label(
                        model.whiteNoiseState.isPaused ? model.lang.t("whiteNoise.resume") : model.lang.t("whiteNoise.pause"),
                        systemImage: model.whiteNoiseState.isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .buttonStyle(WhiteNoiseControlButtonStyle(kind: .primary, isDisabled: !model.whiteNoiseState.hasSelection))
                .disabled(!model.whiteNoiseState.hasSelection)

                Button {
                    model.clearWhiteNoiseMix()
                } label: {
                    Label(model.lang.t("whiteNoise.clear"), systemImage: "xmark.circle.fill")
                }
                .buttonStyle(WhiteNoiseControlButtonStyle(kind: .secondary, isDisabled: !model.whiteNoiseState.hasSelection))
                .disabled(!model.whiteNoiseState.hasSelection)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(12)
        .background(theme.glassStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(theme.outline.opacity(0.12), lineWidth: 1)
        )
    }

    private func localizedCategoryTitle(_ category: WhiteNoiseCategory) -> String {
        let key = "whiteNoise.category." + category.id
        let localized = model.lang.t(key)
        return localized == key ? category.title : localized
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct WhiteNoiseControlButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }

    let kind: Kind
    let isDisabled: Bool
    @Environment(\.islandTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(kind == .primary ? theme.onPrimary.opacity(0.82) : theme.text.opacity(0.82))
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(background(configuration.isPressed), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .opacity(isDisabled ? 0.45 : 1)
    }

    private func background(_ isPressed: Bool) -> Color {
        switch kind {
        case .primary:
            return theme.primary.opacity(isPressed ? 0.72 : 1)
        case .secondary:
            return theme.surfaceContainerHighest.opacity(isPressed ? 0.42 : 0.58)
        }
    }
}

@MainActor
private enum WhiteNoiseBrandFonts {
    private static var didRegister = false

    static func registerIfNeeded() {
        guard !didRegister else { return }
        didRegister = true
        let names = [
            "fraunces-v31-latin-600",
            "inter-tight-v7-latin-600",
            "inter-tight-v7-latin-700",
            "inter-v13-latin-500",
            "inter-v13-latin-regular",
        ]
        for name in names {
            guard let url = Bundle.appResources.url(
                forResource: name,
                withExtension: "woff2",
                subdirectory: "WhiteNoise/fonts"
            ) ?? Bundle.appResources.url(
                forResource: name,
                withExtension: "woff2"
            ) else { continue }
            _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
