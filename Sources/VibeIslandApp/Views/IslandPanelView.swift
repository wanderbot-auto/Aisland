import SwiftUI
import VibeIslandCore

struct IslandPanelView: View {
    var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ONE GLANCE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(model.state.attentionCount) attention")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if let session = model.focusedSession {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.headline)

                            HStack(spacing: 8) {
                                statusBadge(
                                    title: session.tool.displayName,
                                    tint: .white.opacity(0.14)
                                )

                                statusBadge(
                                    title: session.spotlightStatusLabel,
                                    tint: phaseTint(for: session.phase)
                                )
                            }
                        }

                        Spacer(minLength: 16)

                        if let trackingLabel = session.spotlightTrackingLabel {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("tracking")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Text(trackingLabel)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.82))
                                    .lineLimit(1)
                            }
                        }
                    }

                    Text(session.spotlightPrimaryText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)

                    if let secondaryText = session.spotlightSecondaryText {
                        Text(secondaryText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        if let currentTool = session.spotlightCurrentToolLabel {
                            statusBadge(title: currentTool, tint: Color.cyan.opacity(0.22))
                        }

                        if let terminalLabel = session.spotlightTerminalLabel {
                            statusBadge(title: terminalLabel, tint: Color.white.opacity(0.12))
                        }

                        Spacer(minLength: 0)

                        Text(session.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let request = session.permissionRequest {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Approval needed for \(request.title.lowercased())")
                                .font(.caption)
                                .foregroundStyle(.orange.opacity(0.92))

                            HStack(spacing: 10) {
                                Button(request.secondaryActionTitle) {
                                    model.approveFocusedPermission(false)
                                }
                                .buttonStyle(.bordered)

                                Button(request.primaryActionTitle) {
                                    model.approveFocusedPermission(true)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    } else if let prompt = session.questionPrompt {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Codex is waiting for a quick answer.")
                                .font(.caption)
                                .foregroundStyle(.yellow.opacity(0.92))

                            HStack(spacing: 10) {
                                ForEach(prompt.options.prefix(2), id: \.self) { option in
                                    Button(option) {
                                        model.answerFocusedQuestion(option)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    } else {
                        HStack {
                            Text(session.phase == .completed
                                ? "Turn completed in terminal."
                                : "Keep working in terminal. Jump back when needed.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Jump Back") {
                                model.jumpToFocusedSession()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(session.jumpTarget == nil)
                        }
                    }
                }
            } else {
                Text("Waiting for Codex hook events.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 520, height: 256, alignment: .topLeading)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.92),
                        Color(red: 0.11, green: 0.13, blue: 0.18).opacity(0.96),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func statusBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint, in: Capsule())
    }

    private func phaseTint(for phase: SessionPhase) -> Color {
        switch phase {
        case .running:
            return Color.mint.opacity(0.22)
        case .waitingForApproval:
            return Color.orange.opacity(0.24)
        case .waitingForAnswer:
            return Color.yellow.opacity(0.24)
        case .completed:
            return Color.blue.opacity(0.24)
        }
    }
}

struct MenuBarContentView: View {
    var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vibe Island OSS")
                .font(.headline)
            Text("\(model.state.runningCount) running · \(model.state.attentionCount) attention")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            Button("Open Control Center") {
                model.showControlCenter()
            }

            Text(model.acceptanceStatusTitle)
                .font(.subheadline.weight(.semibold))
            Text(model.acceptanceStatusSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Run Demo Acceptance") {
                model.startAcceptanceDemo()
            }

            Divider()

            Button(model.isOverlayVisible ? "Hide Island Overlay" : "Show Island Overlay") {
                model.toggleOverlay()
            }

            Button("Restart Demo") {
                model.resetDemo()
            }

            Divider()

            Text(model.codexHookStatusTitle)
                .font(.subheadline.weight(.semibold))
            Text(model.codexHookStatusSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Refresh Codex Hook Status") {
                model.refreshCodexHookStatus()
            }

            if model.codexHooksInstalled {
                Button("Uninstall Codex Hooks") {
                    model.uninstallCodexHooks()
                }
            } else {
                Button("Install Codex Hooks") {
                    model.installCodexHooks()
                }
                .disabled(model.hooksBinaryURL == nil)
            }

            if let session = model.focusedSession {
                Divider()
                Text(session.title)
                    .font(.subheadline.weight(.semibold))
                Text(session.spotlightPrimaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let currentTool = session.spotlightCurrentToolLabel {
                    Text("Live tool: \(currentTool)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let trackingLabel = session.spotlightTrackingLabel {
                    Text("Tracking: \(trackingLabel)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
