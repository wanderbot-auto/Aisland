import AppKit
import CoreText
import SwiftUI

struct WhiteNoiseView: View {
    var model: AppModel

    private let columns = [
        GridItem(.adaptive(minimum: 132, maximum: 180), spacing: 8, alignment: .top)
    ]

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 12) {
                hero
                controls
                if model.selectedWhiteNoiseSounds.isEmpty {
                    emptyState
                }
                categories
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            WhiteNoiseBrandFonts.registerIfNeeded()
        }
    }

    private var hero: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.08, green: 0.34, blue: 0.34), Color(red: 0.02, green: 0.10, blue: 0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                if let logo = WhiteNoiseBrandAssets.logoImage {
                    Image(nsImage: logo)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.mint)
                }
            }
            .frame(width: 54, height: 54)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(model.lang.t("whiteNoise.title"))
                    .font(.custom("Fraunces", size: 19).weight(.semibold))
                    .foregroundStyle(.white)
                Text(model.lang.t("whiteNoise.subtitle"))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            mixBadge
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.07))
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.mint.opacity(0.16))
                        .frame(width: 90, height: 90)
                        .blur(radius: 22)
                        .offset(x: 24, y: -38)
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var mixBadge: some View {
        VStack(spacing: 2) {
            Text("\(model.selectedWhiteNoiseSounds.count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.82))
            Text(model.lang.t("whiteNoise.mix"))
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(.black.opacity(0.52))
        }
        .frame(width: 48, height: 44)
        .background(Color.mint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
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
                .tint(.mint)
                Text(percent(model.whiteNoiseState.globalVolume))
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.48))
                    .frame(width: 36, alignment: .trailing)
            }

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
        }
        .padding(12)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyState: some View {
        HStack(spacing: 9) {
            Image(systemName: "sparkles")
                .foregroundStyle(.mint)
            Text(model.lang.t("whiteNoise.empty"))
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.54))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.mint.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.mint.opacity(0.22), lineWidth: 0.6)
        )
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
                    .foregroundStyle(.mint.opacity(0.9))
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
            Button {
                model.toggleWhiteNoiseSound(sound)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: sound.systemImageName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? .black.opacity(0.78) : .white.opacity(0.66))
                        .frame(width: 24, height: 24)
                        .background(selected ? Color.white.opacity(0.35) : Color.white.opacity(0.08), in: Circle())
                    Text(sound.label)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(selected ? .black.opacity(0.82) : .white.opacity(0.72))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            if selected {
                HStack(spacing: 7) {
                    Slider(
                        value: Binding(
                            get: { volume },
                            set: { model.setWhiteNoiseVolume($0, for: sound) }
                        ),
                        in: 0...1
                    )
                    .tint(.black.opacity(0.76))
                    Text(percent(volume))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.58))
                        .frame(width: 32, alignment: .trailing)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(selected ? Color.mint : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(selected ? Color.white.opacity(0.35) : Color.white.opacity(0.09), lineWidth: 0.8)
                )
        )
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: selected)
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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(kind == .primary ? Color.black.opacity(0.82) : Color.white.opacity(0.82))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(background(configuration.isPressed), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .opacity(isDisabled ? 0.45 : 1)
    }

    private func background(_ isPressed: Bool) -> Color {
        switch kind {
        case .primary:
            return Color.mint.opacity(isPressed ? 0.72 : 1)
        case .secondary:
            return Color.white.opacity(isPressed ? 0.10 : 0.15)
        }
    }
}

@MainActor
private enum WhiteNoiseBrandAssets {
    static var logoImage: NSImage? {
        guard let url = Bundle.appResources.url(
            forResource: "logo-light",
            withExtension: "png",
            subdirectory: "WhiteNoise"
        ) ?? Bundle.appResources.url(
            forResource: "logo-light",
            withExtension: "png"
        ) else {
            return nil
        }
        return NSImage(contentsOf: url)
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
