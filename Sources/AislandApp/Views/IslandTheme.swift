import SwiftUI
import AislandCore

struct IslandThemePalette: Equatable {
    let name: String
    let background: Color
    let backgroundElevated: Color
    let surface: Color
    let surfaceDim: Color
    let surfaceBright: Color
    let surfaceContainer: Color
    let surfaceContainerHigh: Color
    let surfaceContainerHighest: Color
    let glass: Color
    let glassStrong: Color
    let card: Color
    let cardSelected: Color
    let primary: Color
    let primaryContainer: Color
    let onPrimary: Color
    let secondary: Color
    let tertiary: Color
    let text: Color
    let textSecondary: Color
    let textTertiary: Color
    let outline: Color
    let outlineVariant: Color
    let success: Color
    let warning: Color
    let error: Color
    let shadow: Color

    static let cyberMinimalist = IslandThemePalette(
        name: "Cyber-Minimalist AI",
        background: Color(hex: "#000000") ?? .black,
        backgroundElevated: Color(hex: "#0E0E0E") ?? .black,
        surface: Color(hex: "#131313") ?? .black,
        surfaceDim: Color(hex: "#1B1B1B") ?? .black,
        surfaceBright: Color(hex: "#393939") ?? .gray,
        surfaceContainer: Color(hex: "#1F1F1F") ?? .black,
        surfaceContainerHigh: Color(hex: "#2A2A2A") ?? .black,
        surfaceContainerHighest: Color(hex: "#353535") ?? .black,
        glass: (Color(hex: "#000000") ?? .black).opacity(0.70),
        glassStrong: (Color(hex: "#131313") ?? .black).opacity(0.92),
        card: Color(hex: "#1A1A1A") ?? .black,
        cardSelected: (Color(hex: "#00D1FF") ?? .cyan).opacity(0.14),
        primary: Color(hex: "#00D1FF") ?? .cyan,
        primaryContainer: Color(hex: "#A4E6FF") ?? .cyan,
        onPrimary: Color(hex: "#001F28") ?? .black,
        secondary: Color(hex: "#C8C6C5") ?? .secondary,
        tertiary: Color(hex: "#DEDCDB") ?? .secondary,
        text: Color(hex: "#E2E2E2") ?? .white,
        textSecondary: Color(hex: "#BBC9CF") ?? .secondary,
        textTertiary: Color(hex: "#859399") ?? .secondary,
        outline: Color(hex: "#859399") ?? .secondary,
        outlineVariant: Color(hex: "#3C494E") ?? .secondary,
        success: Color(hex: "#42E86B") ?? .green,
        warning: Color(hex: "#FFB547") ?? .orange,
        error: Color(hex: "#FFB4AB") ?? .red,
        shadow: Color.black.opacity(0.65)
    )

    static let graphiteClassic = IslandThemePalette(
        name: "Graphite Classic",
        background: Color(hex: "#0B0D10") ?? .black,
        backgroundElevated: Color(hex: "#13171C") ?? .black,
        surface: Color(hex: "#171B21") ?? .black,
        surfaceDim: Color(hex: "#20262D") ?? .black,
        surfaceBright: Color(hex: "#3C4652") ?? .gray,
        surfaceContainer: Color(hex: "#222832") ?? .black,
        surfaceContainerHigh: Color(hex: "#2A323D") ?? .black,
        surfaceContainerHighest: Color(hex: "#36404C") ?? .gray,
        glass: (Color(hex: "#101419") ?? .black).opacity(0.76),
        glassStrong: (Color(hex: "#151A20") ?? .black).opacity(0.94),
        card: Color(hex: "#1B2028") ?? .black,
        cardSelected: (Color(hex: "#7BB7FF") ?? .blue).opacity(0.16),
        primary: Color(hex: "#7BB7FF") ?? .blue,
        primaryContainer: Color(hex: "#BBD8FF") ?? .blue,
        onPrimary: Color(hex: "#07111E") ?? .black,
        secondary: Color(hex: "#CBD5E1") ?? .secondary,
        tertiary: Color(hex: "#A7F3D0") ?? .mint,
        text: Color(hex: "#F2F6FA") ?? .white,
        textSecondary: Color(hex: "#B8C2CC") ?? .secondary,
        textTertiary: Color(hex: "#7E8B98") ?? .secondary,
        outline: Color(hex: "#718096") ?? .secondary,
        outlineVariant: Color(hex: "#3A4653") ?? .secondary,
        success: Color(hex: "#7EE787") ?? .green,
        warning: Color(hex: "#FFCB6B") ?? .orange,
        error: Color(hex: "#FF8A80") ?? .red,
        shadow: Color.black.opacity(0.48)
    )
}

enum IslandTheme {
    static let cyber = IslandThemePalette.cyberMinimalist

    static let workingBlue = cyber.primaryContainer
    static let completedGreen = cyber.success
    static let idleGreen = cyber.success
    static let cardFill = cyber.card
    static let badgeFill = cyber.surfaceContainerHigh
    static let approvalCommandFill = (Color(hex: "#2A1E0E") ?? .orange).opacity(0.84)

    static func palette(for theme: IslandInterfaceTheme) -> IslandThemePalette {
        switch theme {
        case .cyberMinimalist: return .cyberMinimalist
        case .graphiteClassic: return .graphiteClassic
        }
    }

    static func statusTint(for phase: SessionPhase, palette: IslandThemePalette = .cyberMinimalist) -> Color {
        switch phase {
        case .waitingForApproval:
            palette.warning
        case .waitingForAnswer:
            palette.primaryContainer
        case .running:
            palette.primary
        case .completed:
            palette.success
        }
    }

    static func titleFont(size: CGFloat = 18) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func bodyFont(size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func labelFont(size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

private struct IslandThemeKey: EnvironmentKey {
    static let defaultValue = IslandThemePalette.cyberMinimalist
}

extension EnvironmentValues {
    var islandTheme: IslandThemePalette {
        get { self[IslandThemeKey.self] }
        set { self[IslandThemeKey.self] = newValue }
    }
}

extension View {
    func islandTheme(_ theme: IslandInterfaceTheme) -> some View {
        environment(\.islandTheme, IslandTheme.palette(for: theme))
            .tint(IslandTheme.palette(for: theme).primary)
    }
}

extension String {
    var trimmedForNotificationCard: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct IslandGlassCard: ViewModifier {
    @Environment(\.islandTheme) private var theme
    var cornerRadius: CGFloat = 18
    var borderOpacity: Double = 0.12
    var fillOpacity: Double = 1

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.card.opacity(fillOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(theme.outline.opacity(borderOpacity), lineWidth: 1)
            )
            .shadow(color: theme.shadow.opacity(0.22), radius: 18, x: 0, y: 10)
    }
}

extension View {
    func islandGlassCard(cornerRadius: CGFloat = 18, borderOpacity: Double = 0.12, fillOpacity: Double = 1) -> some View {
        modifier(IslandGlassCard(cornerRadius: cornerRadius, borderOpacity: borderOpacity, fillOpacity: fillOpacity))
    }

    func islandSettingsPaneBackground() -> some View {
        modifier(IslandSettingsPaneBackground())
    }
}

private struct IslandSettingsPaneBackground: ViewModifier {
    @Environment(\.islandTheme) private var theme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(
                ZStack {
                    theme.background
                    LinearGradient(
                        colors: [theme.primary.opacity(0.11), .clear, theme.surfaceContainer.opacity(0.18)],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                    RadialGradient(
                        colors: [theme.primary.opacity(0.12), .clear],
                        center: .topTrailing,
                        startRadius: 24,
                        endRadius: 360
                    )
                }
                .ignoresSafeArea()
            )
    }
}

struct IslandWideButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case warning
    }

    let kind: Kind
    @Environment(\.islandTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(IslandTheme.labelFont(size: 11.5))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(backgroundColor(configuration.isPressed), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary, .warning:
            return theme.onPrimary
        case .secondary:
            return theme.text.opacity(0.88)
        }
    }

    private var borderColor: Color {
        switch kind {
        case .primary:
            return theme.primary.opacity(0.42)
        case .secondary:
            return theme.outline.opacity(0.16)
        case .warning:
            return theme.warning.opacity(0.42)
        }
    }

    private func backgroundColor(_ isPressed: Bool) -> Color {
        let pressedFactor: Double = isPressed ? 0.78 : 1.0
        switch kind {
        case .primary:
            return theme.primary.opacity(pressedFactor)
        case .secondary:
            return theme.surfaceContainerHighest.opacity(isPressed ? 0.58 : 0.42)
        case .warning:
            return theme.warning.opacity(pressedFactor)
        }
    }
}
