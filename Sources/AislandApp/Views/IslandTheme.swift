import SwiftUI
import AislandCore

enum IslandTheme {
    static let workingBlue = Color(red: 0.34, green: 0.61, blue: 0.99)
    static let completedGreen = Color(red: 0.29, green: 0.86, blue: 0.46)
    static let idleGreen = Color(red: 0.26, green: 0.91, blue: 0.42)
    static let cardFill = Color.black
    static let badgeFill = Color(red: 0.14, green: 0.14, blue: 0.15)
    static let approvalCommandFill = Color(red: 0.11, green: 0.08, blue: 0.03)

    static func statusTint(for phase: SessionPhase) -> Color {
        switch phase {
        case .waitingForApproval:
            .orange
        case .waitingForAnswer:
            .yellow
        case .running:
            workingBlue
        case .completed:
            completedGreen
        }
    }
}

extension String {
    var trimmedForNotificationCard: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct IslandWideButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case warning
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(backgroundColor(configuration.isPressed), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary, .warning:
            return .white
        case .secondary:
            return .white.opacity(0.88)
        }
    }

    private func backgroundColor(_ isPressed: Bool) -> Color {
        let pressedFactor: Double = isPressed ? 0.78 : 1.0
        switch kind {
        case .primary:
            return Color(red: 0.26, green: 0.45, blue: 0.86).opacity(pressedFactor)
        case .secondary:
            return Color.white.opacity(isPressed ? 0.12 : 0.16)
        case .warning:
            return Color(red: 0.85, green: 0.55, blue: 0.15).opacity(pressedFactor)
        }
    }
}
