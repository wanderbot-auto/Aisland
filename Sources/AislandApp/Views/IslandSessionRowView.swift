import SwiftUI
@preconcurrency import MarkdownUI
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

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Auto-height container: renders content directly (auto-sizing).
/// When content exceeds maxHeight, wraps in ScrollView at fixed maxHeight.
private struct AutoHeightScrollView<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder let content: () -> Content
    @State private var contentHeight: CGFloat = 0

    private var isScrollable: Bool { contentHeight > maxHeight }

    var body: some View {
        // Always use ScrollView so the content gets unconstrained vertical
        // space for measurement. Without this, a tight parent window can cap
        // the measurement and make long content appear truncated.
        ScrollView(.vertical) {
            content()
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                    }
                )
                .onPreferenceChange(ContentHeightKey.self) { height in
                    if height > 0 { contentHeight = height }
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(isScrollable ? .automatic : .hidden)
        .frame(height: contentHeight > 0 ? min(contentHeight, maxHeight) : nil)
    }
}

// MARK: - Session row (opened state)

struct IslandSessionRow: View {
    let session: AgentSession
    let referenceDate: Date
    var isActionable: Bool = false
    var useDrawingGroup: Bool = true
    var isInteractive: Bool = true
    var lang: LanguageManager = .shared
    var onApprove: ((ApprovalAction) -> Void)?
    var onAnswer: ((QuestionPromptResponse) -> Void)?
    var onReply: ((String) -> Void)?
    let onJump: () -> Void
    var onDismiss: (() -> Void)?

    @State private var isHighlighted = false
    @State private var isManuallyExpanded = false
    @State private var replyText: String = ""

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
                            if session.isRemote {
                                compactBadge("SSH", presence: presence, icon: "network")
                            }
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
                                            ? Color(red: 0.29, green: 0.86, blue: 0.46)
                                            : Color(red: 0.34, green: 0.61, blue: 0.99))
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
                .fill(isHighlighted ? Color.white.opacity(isActionable ? 0.06 : 0.05) : Color.black)
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
            Color(red: 0.34, green: 0.61, blue: 0.99)
        case .completed:
            Color(red: 0.29, green: 0.86, blue: 0.46)
        }
    }

    @ViewBuilder
    private var actionableBody: some View {
        switch session.phase {
        case .waitingForApproval:
            approvalActionBody
        case .waitingForAnswer:
            questionActionBody
        case .completed:
            completionActionBody
        case .running:
            EmptyView()
        }
    }

    // MARK: - Approval action area

    private var approvalActionBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.orange)
                Text(commandLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(commandPreviewText)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                if let path = session.permissionRequest?.affectedPath.trimmedForNotificationCard,
                   !path.isEmpty {
                    Text(path)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.11, green: 0.08, blue: 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.orange.opacity(0.18))
            )

            HStack(spacing: 8) {
                Button("Deny") { onApprove?(.deny) }
                    .buttonStyle(IslandWideButtonStyle(kind: .secondary))
                Button("Allow Once") { onApprove?(.allowOnce) }
                    .buttonStyle(IslandWideButtonStyle(kind: .warning))
            }

            if let toolName = session.permissionRequest?.toolName {
                Menu {
                    Button("Always Allow (\(toolName))") {
                        let rule = ClaudePermissionRuleValue(toolName: toolName)
                        let update = ClaudePermissionUpdate.addRules(
                            destination: .session,
                            rules: [rule],
                            behavior: .allow
                        )
                        onApprove?(.allowWithUpdates([update]))
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("More approval options")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Question action area

    private var questionActionBody: some View {
        StructuredQuestionPromptView(
            prompt: session.questionPrompt,
            lang: lang,
            onAnswer: { onAnswer?($0) }
        )
    }

    // MARK: - Completion action area

    private var completionActionBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(completionPromptLabel)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)

                Spacer(minLength: 8)

                Text(lang.t("completion.done"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.29, green: 0.86, blue: 0.46).opacity(0.96))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Rectangle()
                .fill(.white.opacity(0.04))
                .frame(height: 1)

            AutoHeightScrollView(maxHeight: 260) {
                Markdown(completionMessageText)
                    .markdownTheme(.completionCard)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }

            if onReply != nil {
                Rectangle()
                    .fill(.white.opacity(0.04))
                    .frame(height: 1)

                completionReplyInput
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    @ViewBuilder
    private var completionReplyInput: some View {
        HStack(spacing: 8) {
            ReplyTextField(
                placeholder: lang.t("completion.replyPlaceholder"),
                text: $replyText,
                onSubmit: { submitReply() }
            )
            .frame(height: 32)

            Button {
                submitReply()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(replyText.trimmingCharacters(in: .whitespaces).isEmpty
                        ? .white.opacity(0.2) : .white.opacity(0.9))
            }
            .buttonStyle(.plain)
            .disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func submitReply() {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        replyText = ""
        onReply?(text)
    }

    // MARK: - Actionable helpers

    private var completionPromptLabel: String {
        if let prompt = session.latestUserPromptText?.trimmedForNotificationCard, !prompt.isEmpty {
            return "You: \(prompt)"
        }
        return "You:"
    }

    private var completionMessageText: String {
        if let text = session.completionAssistantMessageText?.trimmedForNotificationCard, !text.isEmpty {
            return text
        }
        return session.summary
    }

    private var commandLabel: String {
        switch session.currentToolName {
        case "exec_command", "Bash": return "Bash"
        case "AskUserQuestion": return "Question"
        case "ExitPlanMode": return "Plan"
        case "apply_patch": return "Patch"
        case "write_stdin": return "Input"
        case let value?: return value.capitalized
        case nil: return "Command"
        }
    }

    private var commandPreviewText: String {
        let preview = session.currentCommandPreviewText?.trimmedForNotificationCard
        if let preview, !preview.isEmpty {
            return "$ \(preview)"
        }
        return session.permissionRequest?.summary.trimmedForNotificationCard ?? session.summary.trimmedForNotificationCard
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
                .fill(Color(red: 0.34, green: 0.61, blue: 0.99))
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
        .background(Color(red: 0.14, green: 0.14, blue: 0.15), in: Capsule())
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
            return Color(red: 0.34, green: 0.61, blue: 0.99)
        case .active:
            return Color(red: 0.29, green: 0.86, blue: 0.46)
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

private struct StructuredQuestionPromptView: View {
    let prompt: QuestionPrompt?
    var lang: LanguageManager = .shared
    let onAnswer: (QuestionPromptResponse) -> Void

    @State private var selections: [String: Set<String>] = [:]
    @State private var freeformTexts: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsPromptTitle {
                Text(promptTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.yellow.opacity(0.96))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(structuredQuestions, id: \.question) { question in
                    questionRow(question)
                }

                Button(lang.t("question.submit")) {
                    onAnswer(QuestionPromptResponse(answers: answerMap))
                }
                .buttonStyle(IslandWideButtonStyle(kind: .primary))
                .disabled(!hasCompleteSelection)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.06))
        )
    }

    // MARK: - Per-question row

    /// Renders a single question with its header, text, and vertical option list.
    @ViewBuilder
    private func questionRow(_ question: QuestionPromptItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if structuredQuestions.count > 1 {
                Text(question.header)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text(question.question)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            // Vertical option list
            VStack(alignment: .leading, spacing: 4) {
                ForEach(question.options) { option in
                    optionRow(option, question: question)
                }
            }
        }
    }

    // MARK: - Option row (vertical, CLI-style)

    @ViewBuilder
    private func optionRow(_ option: QuestionOption, question: QuestionPromptItem) -> some View {
        let isSelected = selectedLabels(for: question).contains(option.label)
        let showsFreeform = option.allowsFreeform && isSelected
        VStack(alignment: .leading, spacing: 0) {
            Button {
                toggle(option: option.label, for: question)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? .yellow : .white.opacity(0.35))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(option.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(isSelected ? 1 : 0.78))

                        if !option.description.isEmpty {
                            Text(option.description)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.white.opacity(0.4))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)

            if showsFreeform {
                Divider()
                    .overlay(Color.white.opacity(0.08))
                freeformField(for: option, question: question)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.yellow.opacity(0.10) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? .yellow.opacity(0.25) : .clear)
        )
    }

    @ViewBuilder
    private func freeformField(for option: QuestionOption, question: QuestionPromptItem) -> some View {
        let key = freeformKey(for: question, option: option)
        ReplyTextField(
            placeholder: lang.t("question.otherPlaceholder"),
            text: Binding(
                get: { freeformTexts[key] ?? "" },
                set: { freeformTexts[key] = $0 }
            ),
            onSubmit: {
                if hasCompleteSelection {
                    onAnswer(QuestionPromptResponse(answers: answerMap))
                }
            }
        )
        .frame(height: 22)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }

    // MARK: - Helpers

    private var structuredQuestions: [QuestionPromptItem] {
        prompt?.questions ?? []
    }

    private var promptTitle: String {
        prompt?.title.trimmedForNotificationCard ?? lang.t("question.answerNeeded")
    }

    private var showsPromptTitle: Bool {
        guard !promptTitle.isEmpty else {
            return false
        }

        guard structuredQuestions.count == 1,
              let questionTitle = structuredQuestions.first?.question.trimmedForNotificationCard else {
            return true
        }

        return questionTitle.caseInsensitiveCompare(promptTitle) != .orderedSame
    }

    private var answerMap: [String: String] {
        Dictionary(uniqueKeysWithValues: structuredQuestions.compactMap { question in
            let values = resolvedAnswers(for: question)
            guard !values.isEmpty else {
                return nil
            }
            return (question.question, values.joined(separator: ", "))
        })
    }

    private var hasCompleteSelection: Bool {
        structuredQuestions.allSatisfy { question in
            let selected = selectedLabels(for: question)
            guard !selected.isEmpty else {
                return false
            }
            // When a freeform option is selected, require non-empty text.
            for option in question.options where option.allowsFreeform && selected.contains(option.label) {
                if trimmedFreeform(for: question, option: option).isEmpty {
                    return false
                }
            }
            return true
        }
    }

    private func selectedLabels(for question: QuestionPromptItem) -> Set<String> {
        selections[question.question] ?? []
    }

    private func resolvedAnswers(for question: QuestionPromptItem) -> [String] {
        let selected = selectedLabels(for: question)
        guard !selected.isEmpty else { return [] }

        let optionOrder = question.options
        var answers: [String] = []
        for option in optionOrder where selected.contains(option.label) {
            if option.allowsFreeform {
                let text = trimmedFreeform(for: question, option: option)
                answers.append(text.isEmpty ? option.label : text)
            } else {
                answers.append(option.label)
            }
        }
        return answers
    }

    private func freeformKey(for question: QuestionPromptItem, option: QuestionOption) -> String {
        "\(question.question)|\(option.label)"
    }

    private func trimmedFreeform(for question: QuestionPromptItem, option: QuestionOption) -> String {
        (freeformTexts[freeformKey(for: question, option: option)] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func toggle(option: String, for question: QuestionPromptItem) {
        var selected = selections[question.question] ?? []

        if question.multiSelect {
            if selected.contains(option) {
                selected.remove(option)
            } else {
                selected.insert(option)
            }
        } else {
            if selected.contains(option) {
                selected.removeAll()
            } else {
                selected = [option]
            }
        }

        selections[question.question] = selected
    }
}

// MARK: - Reply TextField (NSTextField wrapper for IME-safe Enter handling)

/// NSTextField wrapper that fires `onSubmit` only when the IME composition
/// is finished — pressing Enter during Chinese/Japanese IME composition
/// confirms the candidate instead of submitting.
private struct ReplyTextField: NSViewRepresentable {
    var placeholder: String
    @Binding var text: String
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 13)
        field.textColor = .white
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.35),
                .font: NSFont.systemFont(ofSize: 13),
            ]
        )
        field.delegate = context.coordinator
        field.cell?.lineBreakMode = .byTruncatingTail
        field.cell?.usesSingleLineMode = true
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        context.coordinator.onSubmit = onSubmit
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onSubmit: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self.text = text
            self.onSubmit = onSubmit
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Let AppKit handle Enter during IME composition (e.g. confirming
                // a Chinese/Japanese candidate). Only submit when no marked text.
                guard !textView.hasMarkedText() else { return false }
                onSubmit()
                return true
            }
            return false
        }
    }
}

private extension String {
    var trimmedForNotificationCard: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct IslandWideButtonStyle: ButtonStyle {
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

// MARK: - MarkdownUI Theme

extension MarkdownUI.Theme {
    @MainActor static let completionCard = Theme()
        .text {
            ForegroundColor(.white.opacity(0.88))
            FontSize(13.5)
            FontWeight(.medium)
        }
        .link {
            ForegroundColor(.blue)
        }
        .strong {
            FontWeight(.bold)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(12.5)
            ForegroundColor(.white.opacity(0.88))
            BackgroundColor(.white.opacity(0.08))
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(12.5)
                    ForegroundColor(.white.opacity(0.88))
                }
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(16)
                    FontWeight(.bold)
                    ForegroundColor(.white.opacity(0.88))
                }
                .markdownMargin(top: 8, bottom: 4)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(15)
                    FontWeight(.bold)
                    ForegroundColor(.white.opacity(0.88))
                }
                .markdownMargin(top: 8, bottom: 4)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(14)
                    FontWeight(.semibold)
                    ForegroundColor(.white.opacity(0.88))
                }
                .markdownMargin(top: 6, bottom: 2)
        }
        .blockquote { configuration in
            configuration.label
                .markdownTextStyle {
                    ForegroundColor(.white.opacity(0.6))
                    FontSize(13.5)
                }
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 3)
                }
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 2, bottom: 2)
        }
        .table { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .markdownTableBorderStyle(.init(.allBorders, color: .white.opacity(0.15), strokeStyle: .init(lineWidth: 1)))
                .markdownTableBackgroundStyle(
                    .alternatingRows(Color.white.opacity(0.04), Color.white.opacity(0.08))
                )
                .markdownMargin(top: 4, bottom: 8)
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    if configuration.row == 0 {
                        FontWeight(.semibold)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .relativeLineSpacing(.em(0.25))
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
