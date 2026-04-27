import SwiftUI
import AislandCore

private struct NotificationContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Row Height Estimation

extension AgentSession {
    /// Estimated row height matching `IslandSessionRow` layout for viewport sizing.
    func estimatedIslandRowHeight(at date: Date) -> CGFloat {
        let presence = islandPresence(at: date)
        // Base: vertical padding (28) + headline (~18) + rounding (2)
        var height: CGFloat = 48
        guard presence != .inactive else { return height }
        if spotlightPromptLineText != nil { height += 24 }   // spacing (8) + text (16)
        if spotlightActivityLineText != nil { height += 22 }  // spacing (8) + text (14)
        if let subagents = claudeMetadata?.activeSubagents, !subagents.isEmpty {
            height += 22  // spacing (8) + header (14)
            height += CGFloat(subagents.count) * 18  // each subagent row (spacing 4 + text 14)
        }
        if let tasks = claudeMetadata?.activeTasks, !tasks.isEmpty {
            height += 20  // spacing (8) + summary (12)
            height += CGFloat(tasks.count) * 16  // each task row (spacing 3 + text 13)
        }
        return height
    }
}

// MARK: - Animations

private let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
private let closeAnimation = Animation.smooth(duration: 0.3)
private let popAnimation = Animation.spring(response: 0.3, dampingFraction: 0.5)

/// Composite equatable key so `hasClosedPresence` and `expansionWidth` share
/// a single `.animation(.smooth, value:)` modifier instead of two separate
/// ones that can conflict when both change simultaneously.
private struct ClosedPresenceKey: Equatable {
    var present: Bool
    var width: CGFloat
}

// MARK: - Main island view

struct IslandPanelView: View {
    private static let headerControlButtonSize: CGFloat = 22
    private static let headerControlSpacing: CGFloat = 8
    private static let headerHorizontalPadding: CGFloat = 18
    private static let headerTopPadding: CGFloat = 2
    private static let notchLaneSafetyInset: CGFloat = 12
    private static let closedIdleEdgeHeight: CGFloat = 4

    var model: AppModel

    @Namespace private var notchNamespace
    @State private var isHovering = false
    @State private var showingQuitConfirmation = false

    private var theme: IslandThemePalette { IslandTheme.palette(for: model.interfaceTheme) }

    private var isOpened: Bool {
        model.notchStatus == .opened
    }

    private var usesOpenedVisualState: Bool {
        isOpened
    }

    private var isPopping: Bool {
        model.notchStatus == .popping
    }

    /// Single animation selection based on the current notch status.
    private var notchTransitionAnimation: Animation {
        switch model.notchStatus {
        case .opened:  return openAnimation
        case .closed:  return closeAnimation
        case .popping: return popAnimation
        }
    }

    private var closedSpotlightSession: AgentSession? {
        model.surfacedSessions.first(where: { $0.phase.requiresAttention })
            ?? model.surfacedSessions.first(where: { $0.phase == .running })
            ?? model.surfacedSessions.first
    }

    private var hasClosedPresence: Bool {
        model.liveSessionCount > 0
    }

    private var showsIdleEdgeWhenCollapsed: Bool {
        model.showsIdleEdgeWhenCollapsed
    }

    /// Whether any session has activity worth showing in the closed notch
    private var hasClosedActivity: Bool {
        guard let session = closedSpotlightSession else {
            return false
        }
        return session.phase == .running || session.phase.requiresAttention
    }

    /// Scout icon tint: blue if any running, green if any live, else gray.
    private var scoutTint: Color {
        if model.isCustomAppearance, let phase = closedSpotlightSession?.phase {
            return model.statusColor(for: phase)
        }
        let sessions = model.surfacedSessions
        if sessions.contains(where: { $0.phase == .running }) {
            return IslandTheme.workingBlue
        }
        if !sessions.isEmpty {
            return IslandTheme.idleGreen
        }
        return Color.white.opacity(0.4) // gray
    }

    private var countBadgeWidth: CGFloat {
        let digits = max(1, "\(model.liveSessionCount)".count)
        return CGFloat(26 + max(0, digits - 1) * 8)
    }

    private var expansionWidth: CGFloat {
        guard !showsIdleEdgeWhenCollapsed else { return 0 }
        guard hasClosedPresence else { return 0 }
        let hasPending = closedSpotlightSession?.phase.requiresAttention == true
        let leftWidth = sideWidth + 8 + (hasPending ? 18 : 0)
        let rightWidth = max(sideWidth, countBadgeWidth) + (hasPending ? 18 : 0)
        return leftWidth + rightWidth + 16 + (hasPending ? 6 : 0)
    }

    /// Composite key combining `hasClosedPresence` and `expansionWidth` so a
    /// single `.animation(.smooth)` modifier drives both values.  Previously
    /// they had two separate `.animation(.smooth, value:)` modifiers that
    /// could conflict when they changed in the same runloop pass.
    private var closedPresenceAnimationKey: ClosedPresenceKey {
        ClosedPresenceKey(present: hasClosedPresence, width: expansionWidth)
    }

    private var sideWidth: CGFloat {
        max(0, closedNotchHeight - 12) + 10
    }

    private var targetOverlayScreen: NSScreen? {
        if let targetScreenID = model.overlayPlacementDiagnostics?.targetScreenID,
           let screen = NSScreen.screens.first(where: { screenID(for: $0) == targetScreenID }) {
            return screen
        }

        return NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
    }

    private var usesNotchAwareOpenedHeader: Bool {
        model.overlayPlacementDiagnostics?.mode == .notch
            || targetOverlayScreen?.safeAreaInsets.top ?? 0 > 0
    }

    /// True when the closed island sits on an external (non-notched) display.
    /// The central black rectangle is otherwise aligned with the physical
    /// notch, so center content is only useful here.
    private var isExternalDisplayPlacement: Bool {
        if let mode = model.overlayPlacementDiagnostics?.mode {
            return mode == .topBar
        }
        // Fallback when diagnostics haven't been populated yet.
        return (targetOverlayScreen?.safeAreaInsets.top ?? 0) == 0
    }

    private var openedHeaderButtonsWidth: CGFloat {
        (Self.headerControlButtonSize * 3) + (Self.headerControlSpacing * 2)
    }

    private var openedSurfaceSwitcherWidth: CGFloat {
        CGFloat(IslandSurface.switchableTabs.count * 34)
            + CGFloat(max(0, IslandSurface.switchableTabs.count - 1) * 3)
            + 4
    }

    private var openedHeaderControlsWidth: CGFloat {
        openedHeaderButtonsWidth
            + (isNotificationMode ? 0 : openedSurfaceSwitcherWidth + 10)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.clear

                notchContent(availableSize: geometry.size)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .islandTheme(model.interfaceTheme)
        .alert(model.lang.t("island.quit.confirmTitle"), isPresented: $showingQuitConfirmation) {
            Button(model.lang.t("island.quit.confirmAction"), role: .destructive) {
                model.quitApplication()
            }
            Button(model.lang.t("settings.general.cancel"), role: .cancel) {}
        } message: {
            Text(model.lang.t("island.quit.confirmMessage"))
        }
    }

    @ViewBuilder
    private func notchContent(availableSize: CGSize) -> some View {
        // Window is always at opened size — use opened insets unconditionally.
        let panelShadowHorizontalInset = IslandChromeMetrics.openedShadowHorizontalInset
        let panelShadowBottomInset = IslandChromeMetrics.openedShadowBottomInset
        let layoutWidth = max(0, availableSize.width - (panelShadowHorizontalInset * 2))
        let layoutHeight = max(0, availableSize.height - panelShadowBottomInset)

        // Opened dimensions: fill the layout area with outer padding.
        let outerHorizontalPadding: CGFloat = 28
        let outerBottomPadding: CGFloat = 14
        let openedWidth = max(0, layoutWidth - outerHorizontalPadding)
        let openedHeight = max(closedNotchHeight, layoutHeight - outerBottomPadding)

        // Closed dimensions: sized to the actual notch + session indicators.
        let closedTotalWidth = closedNotchWidth + expansionWidth + (isPopping ? 18 : 0)
        let closedTotalHeight = closedNotchHeight

        let currentWidth = usesOpenedVisualState ? openedWidth : closedTotalWidth
        let currentHeight = usesOpenedVisualState ? openedHeight : closedTotalHeight
        let horizontalInset = usesOpenedVisualState ? 14.0 : 0.0
        let bottomInset = usesOpenedVisualState ? 14.0 : 0.0
        let surfaceWidth = currentWidth + (horizontalInset * 2)
        let surfaceHeight = currentHeight + bottomInset
        let surfaceShape = NotchShape(
            topCornerRadius: usesOpenedVisualState ? NotchShape.openedTopRadius : NotchShape.closedTopRadius,
            bottomCornerRadius: usesOpenedVisualState ? NotchShape.openedBottomRadius : NotchShape.closedBottomRadius
        )
        let hidesClosedSurfaceChrome = showsIdleEdgeWhenCollapsed && !usesOpenedVisualState
        let idleEdgeWidth = closedNotchWidth + (isPopping ? 18 : 0)

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                surfaceShape
                    .fill(theme.glass.opacity(hidesClosedSurfaceChrome ? 0 : 1))
                    .frame(width: surfaceWidth, height: surfaceHeight)

                VStack(spacing: 0) {
                    headerRow
                        .frame(height: closedNotchHeight)
                        .opacity(hidesClosedSurfaceChrome ? 0 : 1)

                    openedContent
                        .frame(width: openedWidth - 24)
                        .frame(maxHeight: usesOpenedVisualState ? currentHeight - closedNotchHeight - 12 : 0, alignment: .top)
                        .opacity(usesOpenedVisualState ? 1 : 0)
                        .clipped(antialiased: false)
                }
                .frame(width: currentWidth, height: currentHeight, alignment: .top)
                .padding(.horizontal, horizontalInset)
                .padding(.bottom, bottomInset)
                .clipShape(surfaceShape)
                .overlay(alignment: .top) {
                    // Black strip to blend with physical notch at the very top
                    Rectangle()
                        .fill(theme.background)
                        .frame(height: 1)
                        .padding(.horizontal, usesOpenedVisualState ? NotchShape.openedTopRadius : NotchShape.closedTopRadius)
                        .opacity(hidesClosedSurfaceChrome ? 0 : 1)
                }
                .overlay {
                    surfaceShape
                        .stroke(Color.white.opacity(hidesClosedSurfaceChrome ? 0 : (usesOpenedVisualState ? 0.07 : 0.04)), lineWidth: 1)
                }
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(theme.background)
                        .frame(width: idleEdgeWidth, height: Self.closedIdleEdgeHeight)
                        .overlay {
                            Capsule()
                                .stroke(theme.outline.opacity(0.12), lineWidth: 1)
                        }
                        .opacity(showsIdleEdgeWhenCollapsed ? 1 : 0)
                }
            }
            .frame(width: surfaceWidth, height: surfaceHeight, alignment: .top)
        }
        .scaleEffect(usesOpenedVisualState ? 1 : (isHovering ? IslandChromeMetrics.closedHoverScale : 1), anchor: .top)
        .padding(.horizontal, panelShadowHorizontalInset)
        .padding(.bottom, panelShadowBottomInset)
        .animation(notchTransitionAnimation, value: model.notchStatus)
        .animation(.smooth, value: closedPresenceAnimationKey)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            if !isOpened {
                model.notchOpen(reason: .click, surface: model.lastSwitchableIslandSurface)
            }
        }
    }

    // MARK: - Closed state

    private var closedNotchWidth: CGFloat {
        (targetOverlayScreen ?? NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }))?.notchSize.width ?? NSScreen.externalDisplayNotchWidth
    }

    private var closedNotchHeight: CGFloat {
        (targetOverlayScreen ?? NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }))?.islandClosedHeight ?? 24
    }

    // MARK: - Header row (shared between closed and opened)

    @ViewBuilder
    private var headerRow: some View {
        if usesOpenedVisualState {
            openedHeaderContent
                .frame(height: closedNotchHeight)
        } else {
            HStack(spacing: 0) {
                if hasClosedPresence {
                    HStack(spacing: 4) {
                        if model.isCustomAppearance {
                            IslandPixelGlyph(
                                tint: scoutTint,
                                style: model.islandPixelShapeStyle,
                                isAnimating: hasClosedActivity,
                                customAvatarImage: model.customAvatarImage
                            )
                            .matchedGeometryEffect(id: "island-icon", in: notchNamespace, isSource: true)
                        } else {
                            AislandIcon(size: 14, isAnimating: hasClosedActivity, tint: scoutTint)
                                .matchedGeometryEffect(id: "island-icon", in: notchNamespace, isSource: true)
                        }

                        if closedSpotlightSession?.phase.requiresAttention == true {
                            AttentionIndicator(
                                size: 14,
                                color: phaseColor(closedSpotlightSession?.phase ?? .running)
                            )
                        }
                    }
                    .frame(width: sideWidth + 8 + (closedSpotlightSession?.phase.requiresAttention == true ? 18 : 0))
                }

                if !hasClosedPresence {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: closedNotchWidth - 20)
                } else {
                    Rectangle()
                        .fill(theme.background)
                        .frame(width: closedNotchWidth - NotchShape.closedTopRadius + (isPopping ? 18 : 0))
                        .overlay(
                            CentralActivityLabel(
                                toolName: closedSpotlightSession?.currentToolName,
                                preview: closedSpotlightSession?.currentCommandPreviewText,
                                isVisible: isExternalDisplayPlacement && hasClosedPresence
                            )
                        )
                }

                if hasClosedPresence {
                    let attentionBalanceWidth: CGFloat = closedSpotlightSession?.phase.requiresAttention == true ? 18 : 0
                    ClosedCountBadge(
                        liveCount: model.liveSessionCount,
                        tint: closedSpotlightSession?.phase.requiresAttention == true ? .orange : scoutTint
                    )
                    .matchedGeometryEffect(id: "right-indicator", in: notchNamespace, isSource: true)
                    .frame(width: max(sideWidth, countBadgeWidth) + attentionBalanceWidth)
                }
            }
            .frame(height: closedNotchHeight)
        }
    }

    @ViewBuilder
    private var openedHeaderContent: some View {
        if usesNotchAwareOpenedHeader {
            GeometryReader { geometry in
                let providers = openedUsageProviders
                let providerGroups = splitUsageProviders(providers)
                let metrics = openedHeaderMetrics(for: geometry.size.width)

                HStack(spacing: 0) {
                    usageLaneView(providerGroups.left, alignment: .leading)
                        .frame(width: metrics.leftUsageWidth, alignment: .leading)

                    Color.clear
                        .frame(width: metrics.centerGapWidth)

                    HStack(spacing: Self.headerControlSpacing) {
                        usageLaneView(providerGroups.right, alignment: .trailing)
                        openedHeaderControls
                    }
                    .frame(width: metrics.rightLaneWidth, alignment: .trailing)
                }
                .padding(.horizontal, Self.headerHorizontalPadding)
                .padding(.top, Self.headerTopPadding)
            }
        } else {
            HStack(spacing: 12) {
                openedUsageSummary
                    .frame(maxWidth: .infinity, alignment: .leading)

                openedHeaderControls
            }
            .padding(.leading, Self.headerHorizontalPadding)
            .padding(.trailing, Self.headerHorizontalPadding)
            .padding(.top, Self.headerTopPadding)
        }
    }

    private var openedHeaderControls: some View {
        HStack(spacing: 10) {
            if !isNotificationMode {
                surfaceSwitcher
            }

            openedHeaderButtons
        }
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
    }

    private var openedHeaderButtons: some View {
        HStack(spacing: Self.headerControlSpacing) {
            headerIconButton(
                systemName: model.isSoundMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                tint: model.isSoundMuted ? .orange.opacity(0.92) : .white.opacity(0.62)
            ) {
                model.toggleSoundMuted()
            }

            headerIconButton(systemName: "gearshape.fill", tint: theme.textSecondary.opacity(0.72)) {
                model.showSettings()
            }

            headerIconButton(
                systemName: "power",
                tint: .white.opacity(0.62),
                accessibilityLabel: model.lang.t("island.quit.confirmTitle")
            ) {
                showingQuitConfirmation = true
            }
        }
    }

    private func headerIconButton(
        systemName: String,
        tint: Color,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: Self.headerControlButtonSize, height: Self.headerControlButtonSize)
                .background(theme.surfaceContainerHighest.opacity(0.56), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? systemName)
    }

    private var openedContent: some View {
        VStack(spacing: 8) {
            if !model.hasAnyInstalledAgent {
                installHooksHint
            }

            if model.islandSurface == .temporaryChat {
                TemporaryChatView(model: model)
            } else if model.islandSurface == .usage {
                RecentModelUsageView(model: model)
            } else if model.islandSurface == .whiteNoise {
                WhiteNoiseView(model: model)
            } else if model.shouldShowSessionBootstrapPlaceholder {
                sessionBootstrapPlaceholder
            } else if model.islandListSessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 0)
    }

    private var surfaceSwitcher: some View {
        HStack(spacing: 3) {
            ForEach(IslandSurface.switchableTabs) { tab in
                surfaceButton(tab: tab) {
                    model.showIslandSurface(tab)
                }
            }
        }
        .padding(2)
        .background(theme.surfaceContainerHighest.opacity(0.56), in: Capsule())
        .frame(maxWidth: openedSurfaceSwitcherWidth)
    }

    private func surfaceButton(
        tab: IslandSurfaceTab,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            let isSelected = tab.matches(model.islandSurface)
            ZStack {
                Capsule()
                    .fill(isSelected ? theme.primary : Color.white.opacity(0.001))
                Image(systemName: tab.systemImageName)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isSelected ? theme.onPrimary.opacity(0.92) : theme.textSecondary.opacity(0.72))
            }
            .frame(width: 34, height: 20)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.lang.t(tab.accessibilityLabelKey))
    }

    /// Persistent hint at the top of the expanded island while no agent
    /// hooks are installed. Decoupled from session presence — process
    /// discovery routinely surfaces sessions even on a freshly cleaned
    /// install, so the empty-state branch alone never reaches users who
    /// already run an agent.
    private var installHooksHint: some View {
        Button {
            model.showOnboarding()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.primary)
                Text(model.lang.t("island.hint.installHooks"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.primary.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(theme.primary.opacity(0.35), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var sessionBootstrapPlaceholder: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white.opacity(0.7))
                .scaleEffect(0.8)
            Text(model.lang.t("island.checkingTerminals"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
            Text(model.lang.t("island.terminalOwnership"))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.28))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(model.lang.t("island.noTerminals"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
            Text(model.recentSessions.isEmpty
                ? model.lang.t("island.startAgent")
                : model.lang.t("island.recentSessions"))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.25))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var actionableSessionID: String? {
        model.islandSurface.sessionID
    }

    /// Whether the panel was opened by a notification (show only actionable session + footer).
    private var isNotificationMode: Bool {
        model.notchOpenReason == .notification && actionableSessionID != nil
    }

    private var sessionList: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            if isNotificationMode {
                // Notification mode: NO ScrollView — content sizes naturally
                sessionListContent(context: context)
                    .padding(.vertical, 2)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: NotificationContentHeightKey.self,
                                value: geo.size.height
                            )
                        }
                    )
                    .onPreferenceChange(NotificationContentHeightKey.self) { height in
                        if height > 0 {
                            model.measuredNotificationContentHeight = height
                        }
                    }
            } else {
                // List mode: scroll when content exceeds the panel's available space.
                // The parent frame constraint (currentHeight - closedNotchHeight - 12)
                // determines the viewport; ScrollView handles overflow naturally.
                ScrollView(.vertical) {
                    sessionListContent(context: context)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func sessionListContent(context: TimelineViewDefaultContext) -> some View {
        VStack(spacing: 6) {
            if isNotificationMode, let session = model.activeIslandCardSession {
                IslandSessionRow(
                    session: session,
                    referenceDate: context.date,
                    isActionable: true,
                    useDrawingGroup: model.notchStatus == .opened,
                    isInteractive: model.notchStatus == .opened,
                    questionOptionLayout: model.questionOptionLayout,
                    lang: model.lang,
                    onApprove: { model.approvePermission(for: session.id, action: $0) },
                    onAnswer: { model.answerQuestion(for: session.id, answer: $0) },
                    onReply: TerminalTextSender.canReply(to: session, enabled: model.completionReplyEnabled)
                        ? { model.replyToSession(session, text: $0) } : nil,
                    onJump: { model.jumpToSession(session) }
                )

                if model.allSessions.count > 1 {
                    Button {
                        let isCompletion = session.phase == .completed
                        model.expandNotificationToSessionList(clearExpansion: isCompletion)
                    } label: {
                        Text(model.lang.t("island.showAll", model.allSessions.count))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ForEach(model.islandListSessions) { session in
                    IslandSessionRow(
                        session: session,
                        referenceDate: context.date,
                        isActionable: session.phase.requiresAttention || session.id == actionableSessionID,
                        useDrawingGroup: model.notchStatus == .opened,
                        isInteractive: model.notchStatus == .opened,
                        questionOptionLayout: model.questionOptionLayout,
                        lang: model.lang,
                        onApprove: { model.approvePermission(for: session.id, action: $0) },
                        onAnswer: { model.answerQuestion(for: session.id, answer: $0) },
                        onReply: TerminalTextSender.canReply(to: session, enabled: model.completionReplyEnabled)
                            ? { model.replyToSession(session, text: $0) } : nil,
                        onJump: { model.jumpToSession(session) }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func phaseColor(_ phase: SessionPhase) -> Color {
        if model.isCustomAppearance {
            return model.statusColor(for: phase)
        }
        return IslandTheme.statusTint(for: phase)
    }

    @ViewBuilder
    private var openedUsageSummary: some View {
        let providers = openedUsageProviders

        if providers.isEmpty == false {
            usageSummaryView(providers)
        } else {
            HStack(spacing: 8) {
                Text(model.lang.t("app.name"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Text(model.lang.t("island.usageWaiting"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .lineLimit(1)
        }
    }

    private var openedUsageProviders: [UsageProviderPresentation] {
        UsageLogProvider.allCases.compactMap { provider in
            guard model.shouldDisplayTodayTokenUsage(for: provider),
                  let totals = model.todayUsageProviderTotals.first(where: { $0.provider == provider }),
                  totals.totalTokens > 0 else {
                return nil
            }

            return UsageProviderPresentation(
                id: provider.rawValue,
                title: provider.displayName,
                totalTokens: totals.totalTokens,
                inputTokens: totals.inputTokens,
                outputTokens: totals.outputTokens,
                entryCount: totals.entryCount
            )
        }
    }

    private func splitUsageProviders(
        _ providers: [UsageProviderPresentation]
    ) -> (left: [UsageProviderPresentation], right: [UsageProviderPresentation]) {
        switch providers.count {
        case 0:
            return ([], [])
        case 1:
            return ([providers[0]], [])
        case 2:
            return ([providers[0]], [providers[1]])
        default:
            let splitIndex = Int(ceil(Double(providers.count) / 2.0))
            return (
                Array(providers.prefix(splitIndex)),
                Array(providers.dropFirst(splitIndex))
            )
        }
    }

    @ViewBuilder
    private func usageLaneView(
        _ providers: [UsageProviderPresentation],
        alignment: Alignment
    ) -> some View {
        if providers.isEmpty {
            Color.clear
                .frame(maxWidth: .infinity)
        } else {
            usageSummaryView(providers)
                .frame(maxWidth: .infinity, alignment: alignment)
        }
    }

    private func openedHeaderMetrics(for totalWidth: CGFloat) -> OpenedHeaderMetrics {
        let contentWidth = max(0, totalWidth - (Self.headerHorizontalPadding * 2))
        guard usesNotchAwareOpenedHeader,
              let screen = targetOverlayScreen else {
            let rightLaneWidth = min(contentWidth, openedHeaderControlsWidth + (contentWidth / 2))
            let leftUsageWidth = max(0, contentWidth - rightLaneWidth)
            return OpenedHeaderMetrics(
                leftUsageWidth: leftUsageWidth,
                centerGapWidth: 0,
                rightLaneWidth: rightLaneWidth
            )
        }

        let panelMinX = screen.frame.midX - (totalWidth / 2)
        let panelMaxX = panelMinX + totalWidth
        let contentMinX = panelMinX + Self.headerHorizontalPadding
        let contentMaxX = panelMaxX - Self.headerHorizontalPadding

        let fallbackNotchHalfWidth = screen.notchSize.width / 2
        let notchLeftEdge = screen.frame.midX - fallbackNotchHalfWidth
        let notchRightEdge = screen.frame.midX + fallbackNotchHalfWidth
        let leftVisibleMaxX = screen.auxiliaryTopLeftArea?.maxX ?? notchLeftEdge
        let rightVisibleMinX = screen.auxiliaryTopRightArea?.minX ?? notchRightEdge

        let rawLeftWidth = max(0, min(contentMaxX, leftVisibleMaxX) - contentMinX)
        let rawRightWidth = max(0, contentMaxX - max(contentMinX, rightVisibleMinX))

        let leftUsageWidth = max(0, rawLeftWidth - Self.notchLaneSafetyInset)
        let rightLaneWidth = max(0, rawRightWidth - Self.notchLaneSafetyInset)
        let centerGapWidth = max(0, contentWidth - leftUsageWidth - rightLaneWidth)

        return OpenedHeaderMetrics(
            leftUsageWidth: leftUsageWidth,
            centerGapWidth: centerGapWidth,
            rightLaneWidth: rightLaneWidth
        )
    }

    private func usageSummaryView(
        _ providers: [UsageProviderPresentation]
    ) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                if index > 0 {
                    usageSeparator("·", opacity: 0.32)
                }

                usageProviderChip(provider)
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func usageProviderChip(_ provider: UsageProviderPresentation) -> some View {
        return HStack(spacing: 4) {
            Text(provider.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))

            Text(Self.compactTokenCount(provider.totalTokens))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.primary.opacity(0.95))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(theme.surfaceContainerHighest.opacity(0.56), in: Capsule())
        .help(provider.helpText)
    }

    private static func compactTokenCount(_ count: Int) -> String {
        switch count {
        case 1_000_000...:
            return String(format: "%.1fM", Double(count) / 1_000_000)
        case 10_000...:
            return "\(count / 1_000)K"
        case 1_000...:
            return String(format: "%.1fK", Double(count) / 1_000)
        default:
            return count.formatted()
        }
    }

    private func screenID(for screen: NSScreen) -> String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let number = screen.deviceDescription[key] as? NSNumber {
            return "display-\(number.uint32Value)"
        }

        return screen.localizedName
    }

    private func usageSeparator(_ title: String, opacity: Double) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(opacity))
    }

}

private struct UsageProviderPresentation: Identifiable {
    let id: String
    let title: String
    let totalTokens: Int
    let inputTokens: Int
    let outputTokens: Int
    let entryCount: Int

    var helpText: String {
        "\(title) today: \(totalTokens.formatted()) tokens · \(inputTokens.formatted()) in · \(outputTokens.formatted()) out · \(entryCount.formatted()) entries"
    }
}

private struct OpenedHeaderMetrics {
    let leftUsageWidth: CGFloat
    let centerGapWidth: CGFloat
    let rightLaneWidth: CGFloat
}

// MARK: - Aisland icon (left side of closed notch)

private struct AislandIcon: View {
    let size: CGFloat
    var isAnimating: Bool = false
    var tint: Color = .mint

    var body: some View {
        AislandBrandMark(
            size: size,
            tint: tint,
            isAnimating: isAnimating,
            style: .duotone
        )
    }
}

// MARK: - Attention indicator (permission/question dot)

private struct AttentionIndicator: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: size * 0.75, weight: .bold))
            .foregroundStyle(color)
    }
}

// MARK: - Closed count badge (right side of closed notch)

private struct ClosedCountBadge: View {
    let liveCount: Int
    let tint: Color

    var body: some View {
        Text("\(liveCount)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(IslandTheme.badgeFill, in: Capsule())
    }
}

// MARK: - Central activity overlay (external-display only)

/// Renders the focus session's current tool call inside the central black
/// rectangle of the closed island. The notch on built-in displays physically
/// covers this area, so we gate rendering on `placementMode == .topBar`.
///
/// State machine: while a tool is active the label tracks it live. When the
/// tool clears (PostToolUse fires or metadata drops the field), the last
/// value lingers for `fadeDelay` then disappears.
private struct CentralActivityLabel: View {
    let toolName: String?
    let preview: String?
    let isVisible: Bool

    @State private var displayed: DisplayedActivity?

    private static let fadeDelay: Duration = .seconds(2)

    struct DisplayedActivity: Equatable {
        var tool: String
        var preview: String?
    }

    var body: some View {
        Group {
            if isVisible, let displayed {
                HStack(spacing: 4) {
                    Image(systemName: Self.icon(for: displayed.tool))
                        .font(.system(size: 9, weight: .semibold))
                    Text(Self.label(for: displayed))
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeOut(duration: 0.22), value: displayed)
        .onChange(of: trackingKey, initial: true) { _, _ in
            sync()
        }
        .task(id: clearTaskID) {
            guard toolName == nil, displayed != nil else { return }
            do {
                try await Task.sleep(for: Self.fadeDelay)
                displayed = nil
            } catch {
                // cancelled — a new tool arrived, let sync() handle it
            }
        }
    }

    /// Composite key so `.onChange` fires on either tool or preview change.
    private var trackingKey: String {
        "\(toolName ?? "")|\(preview ?? "")"
    }

    /// Key used to (re)start the clear timer. Changes whenever we transition
    /// between active/idle so `.task(id:)` cancels and restarts cleanly.
    private var clearTaskID: String {
        toolName == nil ? "clearing-\(displayed?.tool ?? "")" : "active-\(toolName ?? "")"
    }

    private func sync() {
        if let toolName, !toolName.isEmpty {
            displayed = DisplayedActivity(tool: toolName, preview: preview)
        }
    }

    private static func label(for activity: DisplayedActivity) -> String {
        if let preview = activity.preview?.trimmingCharacters(in: .whitespacesAndNewlines),
           !preview.isEmpty {
            return "\(activity.tool) · \(preview)"
        }
        return activity.tool
    }

    private static func icon(for tool: String) -> String {
        let lower = tool.lowercased()
        if lower.contains("grep") || lower.contains("search") || lower.contains("glob") {
            return "magnifyingglass"
        }
        if lower.contains("edit") || lower.contains("write") {
            return "pencil"
        }
        if lower.contains("bash") || lower.contains("shell") || lower.contains("exec") || lower.contains("run") {
            return "terminal"
        }
        if lower.contains("read") {
            return "doc.text"
        }
        if lower.contains("web") || lower.contains("fetch") {
            return "globe"
        }
        if lower.contains("task") || lower.contains("agent") || lower.contains("subagent") {
            return "sparkles"
        }
        return "wrench.and.screwdriver"
    }
}

// MARK: - Menu bar content (unchanged)

struct MenuBarContentView: View {
    var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.lang.t("app.name.oss"))
                .font(.headline)
            Text(model.lang.t("menu.status", model.liveSessionCount, model.liveAttentionCount))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            Button(model.lang.t("menu.settings")) {
                model.showSettings()
            }

            #if DEBUG
            Button(model.lang.t("menu.openDebug")) {
                model.showControlCenter()
            }
            #endif

            Text(model.acceptanceStatusTitle)
                .font(.subheadline.weight(.semibold))
            Text(model.acceptanceStatusSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button(model.isOverlayVisible ? model.lang.t("menu.hideOverlay") : model.lang.t("menu.showOverlay")) {
                model.toggleOverlay()
            }

            Divider()

            Text(model.codexHookStatusTitle)
                .font(.subheadline.weight(.semibold))
            Text(model.codexHookStatusSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(model.lang.t("menu.refreshCodexHooks")) {
                model.refreshCodexHookStatus()
            }

            if model.codexHooksInstalled {
                Button(model.lang.t("menu.uninstallCodexHooks")) {
                    model.uninstallCodexHooks()
                }
            } else {
                Button(model.lang.t("menu.installCodexHooks")) {
                    model.installCodexHooks()
                }
                .disabled(model.hooksBinaryURL == nil)
            }

            Divider()

            Text(model.claudeHookStatusTitle)
                .font(.subheadline.weight(.semibold))
            Text(model.claudeHookStatusSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(model.lang.t("menu.refreshClaudeHooks")) {
                model.refreshClaudeHookStatus()
            }

            if model.claudeHooksInstalled {
                Button(model.lang.t("menu.uninstallClaudeHooks")) {
                    model.uninstallClaudeHooks()
                }
            } else {
                Button(model.lang.t("menu.installClaudeHooks")) {
                    model.installClaudeHooks()
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
                    Text(model.lang.t("menu.liveTool", currentTool))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let trackingLabel = session.spotlightTrackingLabel {
                    Text(model.lang.t("menu.tracking", trackingLabel))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
