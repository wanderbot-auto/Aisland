import SwiftUI
import VibeIslandCore

// MARK: - Animations

private let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
private let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
private let popAnimation = Animation.spring(response: 0.3, dampingFraction: 0.5)

// MARK: - Main island view

struct IslandPanelView: View {
    var model: AppModel

    @Namespace private var notchNamespace

    private var isOpened: Bool {
        model.notchStatus == .opened
    }

    private var isPopping: Bool {
        model.notchStatus == .popping
    }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height

            ZStack(alignment: .top) {
                Color.clear

                notchContent(screenWidth: screenWidth)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.top, 0)
            }
            .frame(width: screenWidth, height: screenHeight)
        }
        .onChange(of: model.notchStatus) { oldValue, newValue in
            // Status changes are animated by the withAnimation calls in the model
        }
    }

    @ViewBuilder
    private func notchContent(screenWidth: CGFloat) -> some View {
        let notchWidth = closedNotchWidth
        let openedWidth = min(screenWidth * 0.4, 480)
        let openedHeight: CGFloat = 400

        let currentWidth = isOpened ? openedWidth : (isPopping ? notchWidth + 32 : notchWidth)
        let currentHeight = isOpened ? openedHeight : closedNotchHeight

        VStack(spacing: 0) {
            if isOpened {
                openedHeaderRow(width: openedWidth)
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                openedContent
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.8, anchor: .top).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            } else {
                closedContent
            }
        }
        .frame(width: currentWidth, height: currentHeight)
        .background(Color.black)
        .clipShape(
            NotchShape(
                topCornerRadius: isOpened ? NotchShape.openedTopRadius : NotchShape.closedTopRadius,
                bottomCornerRadius: isOpened ? NotchShape.openedBottomRadius : NotchShape.closedBottomRadius
            )
        )
        .shadow(color: .black.opacity(isOpened ? 0.7 : 0), radius: isOpened ? 6 : 0)
        .animation(isOpened ? openAnimation : closeAnimation, value: model.notchStatus)
    }

    // MARK: - Closed state

    private var closedNotchWidth: CGFloat { 224 }
    private var closedNotchHeight: CGFloat { 38 }

    private var closedContent: some View {
        HStack(spacing: 8) {
            if let session = model.focusedSession {
                closedSessionIndicator(session: session)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func closedSessionIndicator(session: AgentSession) -> some View {
        HStack(spacing: 6) {
            // Left: status dot
            Circle()
                .fill(phaseColor(session.phase))
                .frame(width: 6, height: 6)

            Spacer()

            // Center: phase text
            if session.phase.requiresAttention {
                Text(session.phase == .waitingForApproval ? "Approval" : "Question")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            // Right: activity indicator
            if session.phase == .running {
                SpinnerView()
            } else if session.phase.requiresAttention {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(phaseColor(session.phase))
            }
        }
    }

    // MARK: - Opened state

    private func openedHeaderRow(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                openedUsageSummary
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    headerPill("\(model.state.runningCount) live", tint: .white.opacity(0.7))

                    if model.state.attentionCount > 0 {
                        headerPill("\(model.state.attentionCount) attention", tint: .orange.opacity(0.95))
                    }

                    Button {
                        model.notchClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 20, height: 20)
                            .background(.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var openedContent: some View {
        VStack(spacing: 0) {
            if model.surfacedSessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No active sessions")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
            Text("Start Codex in your terminal")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.25))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(model.surfacedSessions) { session in
                    IslandSessionRow(
                        session: session,
                        isSelected: session.id == model.focusedSession?.id,
                        onSelect: { model.select(sessionID: session.id) },
                        onJump: { model.jumpToSession(session) },
                        onApprove: { model.approvePermission(for: session.id, approved: $0) },
                        onAnswer: { model.answerQuestion(for: session.id, answer: $0) }
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Helpers

    private func phaseColor(_ phase: SessionPhase) -> Color {
        switch phase {
        case .running: .mint
        case .waitingForApproval: .orange
        case .waitingForAnswer: .yellow
        case .completed: .blue
        }
    }

    @ViewBuilder
    private var openedUsageSummary: some View {
        if let snapshot = model.claudeUsageSnapshot,
           snapshot.isEmpty == false {
            HStack(spacing: 8) {
                Text("Claude")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                if let fiveHour = snapshot.fiveHour {
                    usageWindowView(label: "5h", window: fiveHour)
                }

                if let fiveHour = snapshot.fiveHour,
                   let sevenDay = snapshot.sevenDay,
                   fiveHour.usedPercentage >= 0,
                   sevenDay.usedPercentage >= 0 {
                    Text("|")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.16))
                }

                if let sevenDay = snapshot.sevenDay {
                    usageWindowView(label: "7d", window: sevenDay)
                }
            }
            .lineLimit(1)
        } else {
            HStack(spacing: 8) {
                Text("Vibe Island")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Text("Claude usage waiting")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .lineLimit(1)
        }
    }

    private func usageWindowView(label: String, window: ClaudeUsageWindow) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            Text("\(window.roundedUsedPercentage)%")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(usageColor(for: window.usedPercentage))

            if let resetsAt = window.resetsAt,
               let remaining = remainingDurationString(until: resetsAt) {
                Text(remaining)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    private func headerPill(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.08), in: Capsule())
    }

    private func usageColor(for percentage: Double) -> Color {
        switch percentage {
        case 90...:
            .red.opacity(0.95)
        case 70..<90:
            .orange.opacity(0.95)
        default:
            .green.opacity(0.95)
        }
    }

    private func remainingDurationString(until date: Date) -> String? {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else {
            return nil
        }

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated

        if interval >= 86_400 {
            formatter.allowedUnits = [.day]
            formatter.maximumUnitCount = 1
        } else if interval >= 3_600 {
            formatter.allowedUnits = [.hour, .minute]
            formatter.maximumUnitCount = 2
        } else {
            formatter.allowedUnits = [.minute]
            formatter.maximumUnitCount = 1
        }

        return formatter.string(from: interval)
    }
}

// MARK: - Session row (opened state)

private struct IslandSessionRow: View {
    let session: AgentSession
    let isSelected: Bool
    let onSelect: () -> Void
    let onJump: () -> Void
    let onApprove: (Bool) -> Void
    let onAnswer: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(session.spotlightPrimaryText)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        if let tool = session.spotlightCurrentToolLabel {
                            compactBadge(tool)
                        }
                        compactBadge(session.spotlightStatusLabel)
                    }
                }
            }
            .buttonStyle(.plain)

            if isSelected {
                actionRow
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? .white.opacity(0.12) : .clear)
        )
    }

    @ViewBuilder
    private var actionRow: some View {
        if let request = session.permissionRequest {
            HStack(spacing: 8) {
                Text(request.summary)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange.opacity(0.9))
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button(request.secondaryActionTitle) { onApprove(false) }
                    .buttonStyle(IslandCompactButtonStyle(tint: .secondary))
                Button(request.primaryActionTitle) { onApprove(true) }
                    .buttonStyle(IslandCompactButtonStyle(tint: .orange))
            }
        } else if let prompt = session.questionPrompt {
            HStack(spacing: 8) {
                Text(prompt.title)
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow.opacity(0.9))
                    .lineLimit(2)
                Spacer(minLength: 8)
                ForEach(prompt.options.prefix(2), id: \.self) { option in
                    Button(option) { onAnswer(option) }
                        .buttonStyle(IslandCompactButtonStyle(tint: .secondary))
                }
            }
        } else {
            HStack {
                if let tool = session.spotlightCurrentToolLabel {
                    Text("Running \(tool)")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer(minLength: 8)
                Button("Jump") { onJump() }
                    .buttonStyle(IslandCompactButtonStyle(tint: .mint))
                    .disabled(session.jumpTarget == nil)
            }
        }
    }

    private func compactBadge(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.white.opacity(0.06), in: Capsule())
    }

    private var statusColor: Color {
        switch session.phase {
        case .running: .mint
        case .waitingForApproval: .orange
        case .waitingForAnswer: .yellow
        case .completed: session.jumpTarget != nil ? .white.opacity(0.5) : .blue
        }
    }
}

// MARK: - Compact button style

private struct IslandCompactButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint == .secondary ? .white.opacity(0.7) : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                (tint == .secondary ? Color.white.opacity(0.08) : tint.opacity(0.15)),
                in: Capsule()
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Spinner

private struct SpinnerView: View {
    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: "arrow.trianglehead.2.counterclockwise")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.mint.opacity(0.7))
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Menu bar content (unchanged)

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

            Divider()

            Button(model.isOverlayVisible ? "Hide Island Overlay" : "Show Island Overlay") {
                model.toggleOverlay()
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
