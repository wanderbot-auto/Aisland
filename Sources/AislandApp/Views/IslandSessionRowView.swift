import SwiftUI
import AislandCore

private struct ConditionalDrawingGroup: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.drawingGroup()
        } else {
            content
        }
    }
}


struct IslandSessionRow: View {
    let session: AgentSession
    let referenceDate: Date
    var isActionable: Bool = false
    var useDrawingGroup: Bool = true
    var isInteractive: Bool = true
    var questionOptionLayout: QuestionOptionLayout = .horizontal
    var lang: LanguageManager = .shared
    var onApprove: ((ApprovalAction) -> Void)?
    var onAnswer: ((QuestionPromptResponse) -> Void)?
    var onReply: ((String) -> Void)?
    let onJump: () -> Void
    var onDismiss: (() -> Void)?

    @State private var isHighlighted = false
    @State private var isManuallyExpanded = false

    var body: some View {
        rowBody(referenceDate: referenceDate)
    }

    private func rowBody(referenceDate: Date) -> some View {
        let rawPresence = session.islandPresence(at: referenceDate)
        let presence = (rawPresence == .inactive && isManuallyExpanded) ? .active : rawPresence
        let showsExpandedContent = presence != .inactive
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                statusDot(for: presence)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        Text(session.spotlightHeadlineText)
                            .font(.system(size: isActionable ? 15 : 14, weight: .semibold))
                            .foregroundStyle(headlineColor(for: presence))
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        HStack(spacing: 6) {
                            compactBadge(session.tool.displayName, presence: presence)
                            if let terminalBadge = session.spotlightTerminalBadge {
                                compactBadge(terminalBadge, presence: presence)
                            }
                            compactBadge(session.spotlightAgeBadge, presence: presence)
                            if let onDismiss {
                                DismissButton(action: onDismiss)
                            }
                        }
                    }

                    if showsExpandedContent || isActionable,
                       let promptLine = session.spotlightPromptLineText ?? expandedPromptLineText {
                        Text(promptLine)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                    }

                    if showsExpandedContent || isActionable,
                       let activityLine = session.spotlightActivityLineText ?? expandedActivityLineText {
                        Text(activityLine)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(activityColor(for: presence).opacity(0.94))
                            .lineLimit(1)
                    }

                    if showsExpandedContent,
                       let subagents = session.claudeMetadata?.activeSubagents,
                       !subagents.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 9, weight: .medium))
                                Text(lang.t("subagents.title", subagents.count))
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .foregroundStyle(.cyan.opacity(0.8))

                            ForEach(subagents, id: \.agentID) { sub in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(sub.summary != nil
                                            ? IslandTheme.completedGreen
                                            : IslandTheme.workingBlue)
                                        .frame(width: 6, height: 6)
                                    Text(sub.agentType ?? sub.agentID)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .lineLimit(1)
                                    if let desc = sub.taskDescription {
                                        Text("(\(desc))")
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(.white.opacity(0.5))
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    if sub.summary != nil {
                                        Text(lang.t("subagents.completed"))
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.4))
                                    } else if let started = sub.startedAt {
                                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                                            Text(subagentElapsed(since: started, at: timeline.date))
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(.white.opacity(0.4))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if showsExpandedContent,
                       let tasks = session.claudeMetadata?.activeTasks,
                       !tasks.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(taskSummary(tasks))
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.45))
                            ForEach(tasks) { task in
                                HStack(spacing: 5) {
                                    taskStatusIcon(task.status)
                                    Text(task.title)
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundStyle(task.status == .completed
                                            ? .white.opacity(0.4)
                                            : .white.opacity(0.7))
                                        .strikethrough(task.status == .completed)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, isActionable ? 16 : 16)
            .padding(.vertical, isActionable ? 14 : 14)

            if isActionable {
                actionableBody
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: isActionable ? 24 : 22, style: .continuous)
                .fill(isHighlighted ? Color.white.opacity(isActionable ? 0.06 : 0.05) : IslandTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: isActionable ? 24 : 22, style: .continuous)
                .strokeBorder(actionableBorderColor)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.24), radius: isHighlighted ? 8 : 0, y: isHighlighted ? 6 : 0)
        .overlay(
            Group {
                if !isActionable {
                    Rectangle()
                        .fill(Color.white.opacity(isHighlighted ? 0 : 0.02))
                        .frame(height: 1)
                }
            },
            alignment: .bottom
        )
        .modifier(ConditionalDrawingGroup(enabled: useDrawingGroup && !isActionable))
        .contentShape(RoundedRectangle(cornerRadius: isActionable ? 24 : 22, style: .continuous))
        .animation(.easeInOut(duration: 0.15), value: isHighlighted)
        .onTapGesture(perform: handlePrimaryTap)
        .onHover { hovering in
            guard isInteractive else { return }
            isHighlighted = hovering
        }
        .onChange(of: isInteractive) { _, interactive in
            if !interactive {
                isManuallyExpanded = false
            }
        }
    }

    private var actionableBorderColor: Color {
        if isActionable {
            return actionableStatusTint.opacity(isHighlighted ? 0.45 : 0.28)
        }
        return isHighlighted ? .white.opacity(0.24) : .white.opacity(0.04)
    }

    private var actionableStatusTint: Color {
        switch session.phase {
        case .waitingForApproval:
            .orange
        case .waitingForAnswer:
            .yellow
        case .running:
            IslandTheme.workingBlue
        case .completed:
            IslandTheme.completedGreen
        }
    }

    @ViewBuilder
    private var actionableBody: some View {
        switch session.phase {
        case .waitingForApproval:
            IslandApprovalCardView(session: session, onApprove: onApprove)
        case .waitingForAnswer:
            IslandQuestionCardView(
                prompt: session.questionPrompt,
                optionLayout: questionOptionLayout,
                lang: lang,
                onAnswer: { onAnswer?($0) }
            )
        case .completed:
            IslandCompletionCardView(session: session, lang: lang, onReply: onReply)
        case .running:
            EmptyView()
        }
    }

    private func subagentElapsed(since start: Date, at now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(start))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let secs = seconds % 60
        return "\(minutes)m \(secs)s"
    }

    private func taskSummary(_ tasks: [ClaudeTaskInfo]) -> String {
        let done = tasks.filter { $0.status == .completed }.count
        let prog = tasks.filter { $0.status == .inProgress }.count
        let pend = tasks.filter { $0.status == .pending }.count
        return lang.t("tasks.summary", done, prog, pend)
    }

    @ViewBuilder
    private func taskStatusIcon(_ status: ClaudeTaskInfo.Status) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.square.fill")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.35))
        case .inProgress:
            Circle()
                .fill(IslandTheme.workingBlue)
                .frame(width: 6, height: 6)
        case .pending:
            Circle()
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                .frame(width: 6, height: 6)
        }
    }

    private func statusDot(for presence: IslandSessionPresence) -> some View {
        Circle()
            .fill(statusTint(for: presence))
            .frame(width: 9, height: 9)
            .padding(.top, 6)
    }

    /// Prompt line for manually expanded inactive rows (bypasses time-based filter).
    private var expandedPromptLineText: String? {
        guard isManuallyExpanded, let prompt = session.spotlightPromptText else { return nil }
        return "You: \(prompt)"
    }

    /// Activity line for manually expanded inactive rows (bypasses time-based filter).
    private var expandedActivityLineText: String? {
        guard isManuallyExpanded else { return nil }
        let trimmed = session.lastAssistantMessageText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let assistantMessage = trimmed, !assistantMessage.isEmpty {
            return assistantMessage
        }
        return session.jumpTarget != nil ? "Ready" : "Completed"
    }

    private func handlePrimaryTap() {
        let rawPresence = session.islandPresence(at: referenceDate)
        if rawPresence == .inactive && !isManuallyExpanded {
            withAnimation(.easeInOut(duration: 0.2)) {
                isManuallyExpanded = true
            }
        } else {
            onJump()
        }
    }

    private func compactBadge(
        _ title: String,
        presence: IslandSessionPresence,
        icon: String? = nil
    ) -> some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 7.5, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(badgeTextColor(for: presence))
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(IslandTheme.badgeFill, in: Capsule())
    }

    private func headlineColor(for presence: IslandSessionPresence) -> Color {
        presence == .inactive ? .white.opacity(0.78) : .white
    }

    private func badgeTextColor(for presence: IslandSessionPresence) -> Color {
        presence == .inactive ? .white.opacity(0.42) : .white.opacity(0.56)
    }

    private func statusTint(for presence: IslandSessionPresence) -> Color {
        if session.phase == .waitingForApproval {
            return .orange.opacity(0.94)
        }

        if session.phase == .waitingForAnswer {
            return .yellow.opacity(0.96)
        }

        switch presence {
        case .running:
            return IslandTheme.workingBlue
        case .active:
            return IslandTheme.completedGreen
        case .inactive:
            return .white.opacity(0.38)
        }
    }

    private func activityColor(for presence: IslandSessionPresence) -> Color {
        switch session.spotlightActivityTone {
        case .attention:
            .orange.opacity(0.94)
        case .live:
            statusTint(for: presence)
        case .idle:
            .white.opacity(0.46)
        case .ready:
            presence == .inactive ? .white.opacity(0.46) : statusTint(for: presence)
        }
    }
}

private struct DismissButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(isHovered ? 0.8 : 0.4))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
