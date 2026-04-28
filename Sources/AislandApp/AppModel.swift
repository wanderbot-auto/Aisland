import AppKit
import Foundation
import Observation
import AislandCore
import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    /// Posted by `AppModel.showOnboarding()` to ask `SettingsView` to
    /// switch to General. Lets empty-state CTAs deliver the user to the
    /// right place without `SettingsView`'s `@State` leaking into `AppModel`.
    static let openIslandSelectGeneralTab = Notification.Name("openIslandSelectGeneralTab")
}

typealias TemporaryChatStreamFactory = @Sendable (
    [TemporaryChatMessage],
    LLMChatConfiguration
) throws -> AsyncThrowingStream<TemporaryChatStreamEvent, Error>

@MainActor
@Observable
final class AppModel {
    private static let soundMutedDefaultsKey = "overlay.sound.muted"
    private static let showDockIconDefaultsKey = "app.showDockIcon"
    private static let hapticFeedbackEnabledDefaultsKey = "app.hapticFeedbackEnabled"
    private static let interfaceThemeDefaultsKey = "appearance.interface.theme"
    private static let interfaceTransparencyDefaultsKey = "appearance.interface.transparency"
    private static let islandClosedDisplayStyleDefaultsKey = "appearance.island.closedDisplayStyle"
    private static let islandHideIdleToEdgeDefaultsKey = "appearance.island.hideIdleToEdge"
    private static let islandPixelShapeStyleDefaultsKey = "appearance.island.pixelShapeStyle"
    private static let islandStatusColorsDefaultsKey = "appearance.island.statusColors"
    private static let showCodexUsageDefaultsKey = "app.showCodexUsage"
    private static let islandTokenUsageDisplayModeDefaultsKey = "island.tokenUsage.displayMode"
    private static let completionReplyEnabledDefaultsKey = "feature.completionReply.enabled"
    private static let suppressFrontmostNotificationsDefaultsKey = "app.suppressFrontmostNotifications"
    static let questionOptionLayoutDefaultsKey = "question.optionLayout"
    private static let legacyLLMProviderDefaultsKey = "llm.chat.provider"
    private static let legacyLLMModelDefaultsKey = "llm.chat.model"
    private static let legacyLLMBaseURLDefaultsKey = "llm.chat.baseURL"
    private static let islandShortcutsDefaultsKey = "island.shortcuts"
    private static let whiteNoiseSelectedSoundIDsDefaultsKey = "whiteNoise.selectedSoundIDs"
    private static let whiteNoiseItemVolumesDefaultsKey = "whiteNoise.itemVolumes"
    private static let whiteNoiseGlobalVolumeDefaultsKey = "whiteNoise.globalVolume"

    static let defaultStatusColors = themeDefaultStatusColors(for: .cyberMinimalist)
    static func themeDefaultStatusColors(for theme: IslandInterfaceTheme) -> [SessionPhase: String] {
        switch theme {
        case .cyberMinimalist:
            return [
                .running: "#00D1FF",
                .waitingForApproval: "#FFB547",
                .waitingForAnswer: "#A4E6FF",
                .completed: "#42E86B",
            ]
        case .graphiteClassic:
            return [
                .running: "#7BB7FF",
                .waitingForApproval: "#FFCB6B",
                .waitingForAnswer: "#A7F3D0",
                .completed: "#7EE787",
            ]
        }
    }
    private static let themeDefaultStatusColorPalettes =
        IslandInterfaceTheme.allCases.map { themeDefaultStatusColors(for: $0) }
    private static func statusColorsAreThemeDefaults(_ colors: [SessionPhase: String]) -> Bool {
        themeDefaultStatusColorPalettes.contains(colors)
    }

    static let legacyDefaultStatusColors: [SessionPhase: String] = [
        .running: "#00D1FF",
        .waitingForApproval: "#FFB547",
        .waitingForAnswer: "#FFD95A",
        .completed: "#42E86B",
    ]
    private static let syntheticClaudeSessionPrefix = "claude-process:"
    private static let liveSessionStalenessWindow: TimeInterval = 15 * 60
    private static let jumpOverlayDismissLeadTime: Duration = .milliseconds(20)
    static let hoverOpenDelay: TimeInterval = 0.15

    struct AcceptanceStep: Identifiable {
        let id: String
        let title: String
        let detail: String
        let isComplete: Bool
    }

    let lang = LanguageManager.shared

    var state = SessionState() {
        didSet {
            _cachedSessionBuckets = nil
            bridgeServer.updateStateSnapshot(state)
        }
    }
    @ObservationIgnored private var _cachedSessionBuckets: (primary: [AgentSession], overflow: [AgentSession])?
    var selectedSessionID: String?
    let hooks = HookInstallationCoordinator()
    let overlay = OverlayUICoordinator()
    let discovery = SessionDiscoveryCoordinator()
    let monitoring = ProcessMonitoringCoordinator()
    let usageAnalytics = UsageAnalyticsCoordinator()
    let codexAppServer = CodexAppServerCoordinator()
    let updateChecker = UpdateChecker()
    let shortcutController = IslandShortcutController()

    var notchStatus: NotchStatus {
        get { overlay.notchStatus }
        set { overlay.notchStatus = newValue }
    }
    var notchOpenReason: NotchOpenReason? {
        get { overlay.notchOpenReason }
        set { overlay.notchOpenReason = newValue }
    }
    var islandSurface: IslandSurface {
        get { overlay.islandSurface }
        set { overlay.islandSurface = newValue }
    }
    var isOverlayVisible: Bool { overlay.isOverlayVisible }
    var isOverlayCloseTransitionPending: Bool { overlay.isCloseTransitionPending }
    var isCodexSetupBusy: Bool { hooks.isCodexSetupBusy }
    var isClaudeHookSetupBusy: Bool { hooks.isClaudeHookSetupBusy }
    var isClaudeUsageSetupBusy: Bool { hooks.isClaudeUsageSetupBusy }
    var codexHookStatus: CodexHookInstallationStatus? { hooks.codexHookStatus }
    var claudeHookStatus: ClaudeHookInstallationStatus? { hooks.claudeHookStatus }
    var claudeStatusLineStatus: ClaudeStatusLineInstallationStatus? { hooks.claudeStatusLineStatus }
    var claudeUsageSnapshot: ClaudeUsageSnapshot? { hooks.claudeUsageSnapshot }
    var codexUsageSnapshot: CodexUsageSnapshot? { hooks.codexUsageSnapshot }
    var hooksBinaryURL: URL? { hooks.hooksBinaryURL }
    var codexHooksInstalled: Bool { hooks.codexHooksInstalled }
    var claudeHooksInstalled: Bool { hooks.claudeHooksInstalled }
    var openCodePluginInstalled: Bool { hooks.openCodePluginInstalled }
    var claudeUsageInstalled: Bool { hooks.claudeUsageInstalled }
    var claudeHookStatusTitle: String { hooks.claudeHookStatusTitle }
    var claudeHookStatusSummary: String { hooks.claudeHookStatusSummary }
    var claudeUsageStatusTitle: String { hooks.claudeUsageStatusTitle }
    var claudeUsageStatusSummary: String { hooks.claudeUsageStatusSummary }
    var claudeUsageSummaryText: String? { hooks.claudeUsageSummaryText }
    var codexUsageStatusTitle: String { hooks.codexUsageStatusTitle }
    var codexUsageStatusSummary: String { hooks.codexUsageStatusSummary }
    var codexUsageSummaryText: String? { hooks.codexUsageSummaryText }
    var usageAnalyticsIsRefreshing: Bool { usageAnalytics.isRefreshing }
    var usageAnalyticsLastRefreshError: String? { usageAnalytics.lastRefreshError }
    var usageAnalyticsLastRefreshedAt: Date? { usageAnalytics.lastRefreshedAt }
    var usageAnalyticsLastRefreshReport: UsageAnalyticsRefreshReport? { usageAnalytics.lastRefreshReport }
    var todayUsageProviderTotals: [UsageAnalyticsProviderTotals] { usageAnalytics.todayProviderTotals }
    var openCodePluginStatus: OpenCodePluginInstallationStatus? { hooks.openCodePluginStatus }
    var isOpenCodeSetupBusy: Bool { hooks.isOpenCodeSetupBusy }
    var openCodePluginStatusTitle: String { hooks.openCodePluginStatusTitle }
    var openCodePluginStatusSummary: String { hooks.openCodePluginStatusSummary }
    var claudeHealthReport: HookHealthReport? { hooks.claudeHealthReport }
    var codexHealthReport: HookHealthReport? { hooks.codexHealthReport }
    var openCodeHealthReport: HookHealthReport? { hooks.openCodeHealthReport }
    var codexHookStatusTitle: String { hooks.codexHookStatusTitle }
    var codexHookStatusSummary: String { hooks.codexHookStatusSummary }

    /// Mirrors `AgentIntentStore.firstLaunchCompleted`. Onboarding sets this
    /// to true after the user completes (or explicitly skips) the flow;
    /// legacy migration also flips it for users upgrading with existing
    /// hooks.
    var firstLaunchCompleted: Bool {
        get { hooks.intentStore.firstLaunchCompleted }
        set { hooks.intentStore.firstLaunchCompleted = newValue }
    }

    /// True if at least one managed hook is currently present on disk.
    /// Drives the "configure agents" empty-state prompts in the island and
    /// the settings window.
    var hasAnyInstalledAgent: Bool {
        hooks.claudeHooksInstalled
            || hooks.codexHooksInstalled
            || hooks.openCodePluginInstalled
    }
    func refreshCodexHookStatus() { hooks.refreshCodexHookStatus() }
    func refreshClaudeHookStatus() { hooks.refreshClaudeHookStatus() }
    func refreshOpenCodePluginStatus() { hooks.refreshOpenCodePluginStatus() }
    func refreshClaudeUsageState() { hooks.refreshClaudeUsageState() }
    func refreshCodexUsageState() { hooks.refreshCodexUsageState() }
    func refreshUsageAnalytics() { usageAnalytics.refreshNow() }
    func startUsageAnalyticsMonitoringIfNeeded() { usageAnalytics.startMonitoringIfNeeded() }
    func usageAnalyticsSnapshot(for period: UsageAggregationPeriod) -> UsageAnalyticsSnapshot? {
        usageAnalytics.snapshot(for: period)
    }
    var usageAnalyticsDailyModelUsage: [UsageAnalyticsDailyModelBucket] {
        usageAnalytics.dailyModelUsage
    }
    var usageAnalyticsHourlyModelUsage: [UsageAnalyticsHourlyModelBucket] {
        usageAnalytics.hourlyModelUsage
    }
    func shouldDisplayTodayTokenUsage(for provider: UsageLogProvider) -> Bool {
        switch islandTokenUsageDisplayMode {
        case .claude:
            provider == .claude
        case .codex:
            provider == .codex
        case .both:
            provider == .claude || provider == .codex
        }
    }
    func installCodexHooks() { hooks.installCodexHooks() }
    func uninstallCodexHooks() { hooks.uninstallCodexHooks() }
    func installClaudeHooks() { hooks.installClaudeHooks() }
    func uninstallClaudeHooks() { hooks.uninstallClaudeHooks() }
    func installOpenCodePlugin() { hooks.installOpenCodePlugin() }
    func uninstallOpenCodePlugin() { hooks.uninstallOpenCodePlugin() }
    func installClaudeUsageBridge() { hooks.installClaudeUsageBridge() }
    func uninstallClaudeUsageBridge() { hooks.uninstallClaudeUsageBridge() }
    func updateClaudeConfigDirectory(to newDirectory: URL?) { hooks.updateClaudeConfigDirectory(to: newDirectory) }
    func runHealthChecks() { hooks.runHealthChecks() }
    func repairHooks() {
        Task { @MainActor in
            await hooks.repairHooksIfNeeded()
        }
    }
    var isBridgeReady = false
    var lastActionMessage = "Waiting for agent hook events..." {
        didSet {
            guard lastActionMessage != oldValue else {
                return
            }

            harnessRuntimeMonitor?.recordLog(lastActionMessage)
        }
    }
    var isResolvingInitialLiveSessions: Bool {
        get { monitoring.isResolvingInitialLiveSessions }
        set { monitoring.isResolvingInitialLiveSessions = newValue }
    }
    var overlayDisplayOptions: [OverlayDisplayOption] {
        get { overlay.overlayDisplayOptions }
        set { overlay.overlayDisplayOptions = newValue }
    }
    var overlayPlacementDiagnostics: OverlayPlacementDiagnostics? {
        get { overlay.overlayPlacementDiagnostics }
        set { overlay.overlayPlacementDiagnostics = newValue }
    }
    var showDockIcon: Bool = false {
        didSet {
            guard hasFinishedInit, showDockIcon != oldValue else { return }
            UserDefaults.standard.set(showDockIcon, forKey: Self.showDockIconDefaultsKey)
            NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
            if !showDockIcon {
                // macOS does not immediately refresh the Dock when switching to
                // .accessory at runtime. Briefly activating another app forces
                // the Dock to drop the icon.
                NSApp.hide(nil)
                DispatchQueue.main.async {
                    NSApp.unhide(nil)
                }
            }
        }
    }
    var hapticFeedbackEnabled: Bool = false {
        didSet {
            guard hasFinishedInit, hapticFeedbackEnabled != oldValue else { return }
            UserDefaults.standard.set(hapticFeedbackEnabled, forKey: Self.hapticFeedbackEnabledDefaultsKey)
        }
    }
    var showCodexUsage: Bool = false {
        didSet {
            guard hasFinishedInit, showCodexUsage != oldValue else { return }
            UserDefaults.standard.set(showCodexUsage, forKey: Self.showCodexUsageDefaultsKey)
        }
    }
    var islandTokenUsageDisplayMode: IslandTokenUsageDisplayMode = .both {
        didSet {
            guard hasFinishedInit, islandTokenUsageDisplayMode != oldValue else { return }
            UserDefaults.standard.set(islandTokenUsageDisplayMode.rawValue, forKey: Self.islandTokenUsageDisplayModeDefaultsKey)
            refreshOverlayPlacementIfVisible()
        }
    }
    var completionReplyEnabled: Bool = false {
        didSet {
            guard hasFinishedInit, completionReplyEnabled != oldValue else { return }
            UserDefaults.standard.set(completionReplyEnabled, forKey: Self.completionReplyEnabledDefaultsKey)
            refreshOverlayPlacementIfVisible()
        }
    }
    var questionOptionLayout: QuestionOptionLayout = .horizontal {
        didSet {
            guard hasFinishedInit, questionOptionLayout != oldValue else { return }
            UserDefaults.standard.set(questionOptionLayout.rawValue, forKey: Self.questionOptionLayoutDefaultsKey)
            measuredNotificationContentHeight = 0
            refreshOverlayPlacementIfVisible()
        }
    }
    var suppressFrontmostNotifications: Bool = true {
        didSet {
            guard hasFinishedInit, suppressFrontmostNotifications != oldValue else { return }
            UserDefaults.standard.set(suppressFrontmostNotifications, forKey: Self.suppressFrontmostNotificationsDefaultsKey)
        }
    }
    var isSoundMuted = false {
        didSet {
            guard isSoundMuted != oldValue else {
                return
            }

            UserDefaults.standard.set(isSoundMuted, forKey: Self.soundMutedDefaultsKey)
            lastActionMessage = isSoundMuted
                ? "Island sound notifications muted."
                : "Island sound notifications enabled."
        }
    }
    var selectedSoundName: String = NotificationSoundService.defaultSoundName {
        didSet {
            guard selectedSoundName != oldValue else { return }
            NotificationSoundService.selectedSoundName = selectedSoundName
        }
    }
    var temporaryChatProvider: LLMProviderKind = .openAI {
        didSet {
            guard temporaryChatProvider != oldValue else { return }
            if temporaryChatModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || temporaryChatModel == oldValue.defaultModel {
                temporaryChatModel = temporaryChatProvider.defaultModel
            }
            if temporaryChatBaseURL == oldValue.defaultBaseURL {
                temporaryChatBaseURL = temporaryChatProvider.defaultBaseURL
            }
            resetTemporaryChatAPIKeyForProviderChange()
            refreshTemporaryChatTokenStats()
            persistTemporaryChatConfigurationIfReady()
        }
    }
    var temporaryChatModel: String = LLMProviderKind.openAI.defaultModel {
        didSet {
            guard temporaryChatModel != oldValue else { return }
            refreshTemporaryChatTokenStats()
            persistTemporaryChatConfigurationIfReady()
        }
    }
    var temporaryChatBaseURL: String = LLMProviderKind.openAI.defaultBaseURL {
        didSet {
            guard temporaryChatBaseURL != oldValue else { return }
            persistTemporaryChatConfigurationIfReady()
        }
    }
    var temporaryChatAPIKey: String = "" {
        didSet {
            guard hasFinishedInit, !isRestoringTemporaryChatAPIKey, temporaryChatAPIKey != oldValue else { return }
            temporaryChatAPIKeyLoadedProvider = temporaryChatProvider
            temporaryChatAPIKeySaver(temporaryChatAPIKey, temporaryChatProvider)
        }
    }
    var temporaryChatMessages: [TemporaryChatMessage] = [] {
        didSet {
            refreshTemporaryChatTokenStats()
        }
    }
    var temporaryChatPendingParts: [TemporaryChatMessagePart] = []
    var temporaryChatWebSearchMode: TemporaryChatWebSearchMode = .auto
    var temporaryChatWebSearchEnabled: Bool {
        get { temporaryChatWebSearchMode != .off }
        set { temporaryChatWebSearchMode = newValue ? .on : .off }
    }
    var temporaryChatTokenStats = TemporaryChatTokenStats.estimate(
        messages: [],
        provider: .openAI,
        model: LLMProviderKind.openAI.defaultModel
    )
    var temporaryChatIsSending = false
    var temporaryChatLastError: String?
    var temporaryChatSkills: [TemporaryChatSkillDefinition] = []
    var temporaryChatInstalledSkills: [TemporaryChatInstalledSkill] = []
    var temporaryChatSkillLastError: String?
    var isTemporaryChatSkillImporting = false
    var whiteNoiseState = WhiteNoiseSelectionState() {
        didSet {
            guard hasFinishedInit else { return }
            persistWhiteNoiseState()
            whiteNoisePlayerService.apply(state: whiteNoiseState, soundsByID: WhiteNoiseCatalog.soundsByID)
        }
    }
    var shortcuts: [IslandShortcutAction: IslandKeyboardShortcut] = IslandKeyboardShortcut.defaultShortcuts {
        didSet {
            guard hasFinishedInit else { return }
            persistShortcuts()
            shortcutController.reloadShortcuts(shortcuts)
        }
    }
    var recordingShortcutAction: IslandShortcutAction?
    var overlayDisplaySelectionID: String {
        get { overlay.overlayDisplaySelectionID }
        set { overlay.overlayDisplaySelectionID = newValue }
    }

    // MARK: - Appearance

    var interfaceTheme: IslandInterfaceTheme = .cyberMinimalist {
        didSet {
            guard interfaceTheme != oldValue else { return }
            UserDefaults.standard.set(interfaceTheme.rawValue, forKey: Self.interfaceThemeDefaultsKey)
            if Self.statusColorsAreThemeDefaults(statusColorHexes) {
                statusColorHexes = Self.themeDefaultStatusColors(for: interfaceTheme)
            } else {
                _cachedStatusColors = [:]
            }
        }
    }

    var interfaceTransparency: Double = InterfaceTransparencySetting.defaultValue {
        didSet {
            let clamped = InterfaceTransparencySetting.clamped(interfaceTransparency)
            guard interfaceTransparency == clamped else {
                interfaceTransparency = clamped
                return
            }
            guard hasFinishedInit, interfaceTransparency != oldValue else { return }
            UserDefaults.standard.set(interfaceTransparency, forKey: Self.interfaceTransparencyDefaultsKey)
        }
    }

    var isCustomAppearance: Bool { true }

    var islandClosedDisplayStyle: IslandClosedDisplayStyle = .detailed {
        didSet {
            guard islandClosedDisplayStyle != oldValue else { return }
            UserDefaults.standard.set(islandClosedDisplayStyle.rawValue, forKey: Self.islandClosedDisplayStyleDefaultsKey)
            refreshOverlayPlacementIfVisible()
        }
    }
    var hideIdleIslandToEdge: Bool = false {
        didSet {
            guard hideIdleIslandToEdge != oldValue else { return }
            UserDefaults.standard.set(hideIdleIslandToEdge, forKey: Self.islandHideIdleToEdgeDefaultsKey)
            refreshOverlayPlacementIfVisible()
        }
    }
    var islandPixelShapeStyle: IslandPixelShapeStyle = .bars {
        didSet {
            guard islandPixelShapeStyle != oldValue else { return }
            UserDefaults.standard.set(islandPixelShapeStyle.rawValue, forKey: Self.islandPixelShapeStyleDefaultsKey)
        }
    }
    var statusColorHexes: [SessionPhase: String] = AppModel.defaultStatusColors {
        didSet {
            guard statusColorHexes != oldValue else { return }
            let encoded = statusColorHexes.reduce(into: [String: String]()) { $0[$1.key.rawValue] = $1.value }
            UserDefaults.standard.set(encoded, forKey: Self.islandStatusColorsDefaultsKey)
            _cachedStatusColors = [:]
        }
    }
    var customAvatarImage: NSImage? = nil
    private var _cachedStatusColors: [SessionPhase: Color] = [:]

    func statusColor(for phase: SessionPhase) -> Color {
        if let cached = _cachedStatusColors[phase] { return cached }
        let hex = statusColorHexes[phase] ?? Self.defaultStatusColors[phase] ?? "#6E9FFF"
        let color = Color(hex: hex) ?? .white
        _cachedStatusColors[phase] = color
        return color
    }

    func setStatusColor(_ color: Color, for phase: SessionPhase) {
        guard let hex = color.opaqueHexString else { return }
        statusColorHexes[phase] = hex
    }

    var showsIdleEdgeWhenCollapsed: Bool {
        hideIdleIslandToEdge && notchStatus == .closed
    }

    func importCustomAvatar() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            customAvatarImage = try AvatarImageStore.importImage(from: url)
            islandPixelShapeStyle = .custom
        } catch {
            lastActionMessage = error.localizedDescription
        }
    }

    func removeCustomAvatar() {
        do {
            try AvatarImageStore.removeCurrentImage()
            customAvatarImage = nil
            if islandPixelShapeStyle == .custom {
                islandPixelShapeStyle = .bars
            }
        } catch {
            lastActionMessage = error.localizedDescription
        }
    }

    @ObservationIgnored
    var openSettingsWindow: (() -> Void)?

    @ObservationIgnored
    private var hasFinishedInit = false

    var ignoresPointerExitDuringHarness = false
    var disablesOverlayEventMonitoringDuringHarness = false

    @ObservationIgnored
    private var bridgeTask: Task<Void, Never>?

    @ObservationIgnored
    private var bridgeReconnectTask: Task<Void, Never>?

    @ObservationIgnored
    private var hasStarted = false

    @ObservationIgnored
    private let bridgeServer = BridgeServer()

    @ObservationIgnored
    private var bridgeClient = LocalBridgeClient()

    @ObservationIgnored
    private let terminalJumpAction: @Sendable (JumpTarget) throws -> String

    @ObservationIgnored
    private let isNotificationSessionAlreadyFrontmost: @Sendable (AgentSession) async -> Bool

    @ObservationIgnored
    private let temporaryChatStream: TemporaryChatStreamFactory

    @ObservationIgnored
    private let temporaryChatConfigurationStore: TemporaryChatConfigurationStore

    @ObservationIgnored
    private let temporaryChatAPIKeyLoader: @Sendable (LLMProviderKind) -> String

    @ObservationIgnored
    private let temporaryChatAPIKeySaver: @Sendable (String, LLMProviderKind) -> Void

    @ObservationIgnored
    private let whiteNoiseDefaults: UserDefaults

    @ObservationIgnored
    private let whiteNoisePlayerService: WhiteNoisePlayerServicing

    @ObservationIgnored
    private let temporaryChatSkillInstallManager = TemporaryChatSkillInstallManager()


    @ObservationIgnored
    var harnessRuntimeMonitor: HarnessRuntimeMonitor?


    @ObservationIgnored
    private var jumpTask: Task<Void, Never>?

    @ObservationIgnored
    private var notificationPresentationTask: Task<Void, Never>?

    @ObservationIgnored
    private var temporaryChatTask: Task<Void, Never>?

    @ObservationIgnored
    private var isRestoringTemporaryChatAPIKey = false

    @ObservationIgnored
    private var temporaryChatAPIKeyLoadedProvider: LLMProviderKind?

    init(
        terminalJumpAction: @escaping @Sendable (JumpTarget) throws -> String = { target in
            try TerminalJumpService().jump(to: target)
        },
        isNotificationSessionAlreadyFrontmost: @escaping @Sendable (AgentSession) async -> Bool = { session in
            await ForegroundTerminalSessionProbe().matches(session: session)
        },
        temporaryChatStream: @escaping TemporaryChatStreamFactory = { messages, configuration in
            try TemporaryChatClient().stream(messages: messages, configuration: configuration)
        },
        temporaryChatConfigurationStore: TemporaryChatConfigurationStore = TemporaryChatConfigurationStore(),
        temporaryChatAPIKeyLoader: @escaping @Sendable (LLMProviderKind) -> String = { TemporaryChatCredentials.loadAPIKey(for: $0) },
        temporaryChatAPIKeySaver: @escaping @Sendable (String, LLMProviderKind) -> Void = { TemporaryChatCredentials.saveAPIKey($0, for: $1) },
        whiteNoiseDefaults: UserDefaults = .standard,
        whiteNoisePlayerService: WhiteNoisePlayerServicing = WhiteNoisePlayerService()
    ) {
        self.terminalJumpAction = terminalJumpAction
        self.isNotificationSessionAlreadyFrontmost = isNotificationSessionAlreadyFrontmost
        self.temporaryChatStream = temporaryChatStream
        self.temporaryChatConfigurationStore = temporaryChatConfigurationStore
        self.temporaryChatAPIKeyLoader = temporaryChatAPIKeyLoader
        self.temporaryChatAPIKeySaver = temporaryChatAPIKeySaver
        self.whiteNoiseDefaults = whiteNoiseDefaults
        self.whiteNoisePlayerService = whiteNoisePlayerService
        UserDefaults.standard.register(defaults: [
            Self.showDockIconDefaultsKey: true,
            Self.hapticFeedbackEnabledDefaultsKey: false,
            Self.completionReplyEnabledDefaultsKey: false,
            Self.suppressFrontmostNotificationsDefaultsKey: true,
            Self.questionOptionLayoutDefaultsKey: QuestionOptionLayout.horizontal.rawValue,
            Self.interfaceTransparencyDefaultsKey: InterfaceTransparencySetting.defaultValue,
        ])
        isSoundMuted = UserDefaults.standard.bool(forKey: Self.soundMutedDefaultsKey)
        selectedSoundName = NotificationSoundService.selectedSoundName
        showDockIcon = UserDefaults.standard.bool(forKey: Self.showDockIconDefaultsKey)
        hapticFeedbackEnabled = UserDefaults.standard.bool(forKey: Self.hapticFeedbackEnabledDefaultsKey)
        suppressFrontmostNotifications = UserDefaults.standard.bool(forKey: Self.suppressFrontmostNotificationsDefaultsKey)
        let hasSavedCodexUsagePreference = UserDefaults.standard.object(forKey: Self.showCodexUsageDefaultsKey) != nil
        if hasSavedCodexUsagePreference {
            showCodexUsage = UserDefaults.standard.bool(forKey: Self.showCodexUsageDefaultsKey)
        } else {
            showCodexUsage = FileManager.default.fileExists(
                atPath: CodexRolloutDiscovery.defaultRootURL.path
            )
        }
        let migratedTokenUsageMode: IslandTokenUsageDisplayMode = hasSavedCodexUsagePreference
            ? (showCodexUsage ? .both : .claude)
            : .both
        islandTokenUsageDisplayMode = IslandTokenUsageDisplayMode(
            rawValue: UserDefaults.standard.string(forKey: Self.islandTokenUsageDisplayModeDefaultsKey) ?? ""
        ) ?? migratedTokenUsageMode
        completionReplyEnabled = UserDefaults.standard.bool(forKey: Self.completionReplyEnabledDefaultsKey)
        questionOptionLayout = QuestionOptionLayout(
            rawValue: UserDefaults.standard.string(forKey: Self.questionOptionLayoutDefaultsKey) ?? ""
        ) ?? .horizontal
        let storedChatConfiguration = Self.loadTemporaryChatConfiguration(
            store: temporaryChatConfigurationStore
        )
        temporaryChatProvider = storedChatConfiguration.provider
        temporaryChatModel = storedChatConfiguration.model
        temporaryChatBaseURL = storedChatConfiguration.baseURL
        refreshTemporaryChatTokenStats()
        whiteNoiseState = Self.loadWhiteNoiseState(defaults: whiteNoiseDefaults)
        shortcuts = Self.loadShortcuts()
        interfaceTheme = IslandInterfaceTheme(
            rawValue: UserDefaults.standard.string(forKey: Self.interfaceThemeDefaultsKey) ?? ""
        ) ?? .cyberMinimalist
        interfaceTransparency = InterfaceTransparencySetting.clamped(
            UserDefaults.standard.double(forKey: Self.interfaceTransparencyDefaultsKey)
        )
        islandClosedDisplayStyle = IslandClosedDisplayStyle(
            rawValue: UserDefaults.standard.string(forKey: Self.islandClosedDisplayStyleDefaultsKey) ?? ""
        ) ?? .detailed
        hideIdleIslandToEdge = UserDefaults.standard.bool(forKey: Self.islandHideIdleToEdgeDefaultsKey)
        islandPixelShapeStyle = IslandPixelShapeStyle(
            rawValue: UserDefaults.standard.string(forKey: Self.islandPixelShapeStyleDefaultsKey) ?? ""
        ) ?? .bars
        customAvatarImage = AvatarImageStore.currentImage()
        if let saved = UserDefaults.standard.dictionary(forKey: Self.islandStatusColorsDefaultsKey) as? [String: String] {
            var colors = Self.themeDefaultStatusColors(for: interfaceTheme)
            for (key, value) in saved {
                if let phase = SessionPhase(rawValue: key) {
                    colors[phase] = value.normalizedHexColorString
                }
            }
            statusColorHexes = colors == Self.legacyDefaultStatusColors
                ? Self.themeDefaultStatusColors(for: interfaceTheme)
                : colors
        } else {
            statusColorHexes = Self.themeDefaultStatusColors(for: interfaceTheme)
        }
        overlay.appModel = self
        overlay.restoreDisplayPreference()
        overlay.onStatusMessage = { [weak self] message in
            self?.lastActionMessage = message
        }
        overlay.activeIslandCardSessionAccessor = { [weak self] in
            self?.activeIslandCardSession
        }
        overlay.isSoundMutedAccessor = { [weak self] in
            self?.isSoundMuted ?? false
        }
        overlay.ignoresPointerExitAccessor = { [weak self] in
            self?.ignoresPointerExitDuringHarness ?? false
        }

        hooks.onStatusMessage = { [weak self] message in
            self?.lastActionMessage = message
        }

        discovery.syntheticClaudeSessionPrefix = Self.syntheticClaudeSessionPrefix
        discovery.onStatusMessage = { [weak self] message in
            self?.lastActionMessage = message
        }
        discovery.stateAccessor = { [weak self] in self?.state ?? SessionState() }
        discovery.stateUpdater = { [weak self] in self?.state = $0 }
        discovery.onStateChanged = { [weak self] in
            self?.synchronizeSelection()
            self?.refreshOverlayPlacementIfVisible()
        }

        discovery.codexRolloutWatcher.eventHandler = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.applyTrackedEvent(
                    event,
                    updateLastActionMessage: false,
                    ingress: .rollout
                )
            }
        }

        codexAppServer.onEvent = { [weak self] event in
            self?.applyTrackedEvent(event, ingress: .bridge)
        }
        codexAppServer.onStatusMessage = { [weak self] message in
            self?.lastActionMessage = message
        }
        codexAppServer.isSessionTracked = { [weak self] id in
            self?.state.session(id: id) != nil
        }

        monitoring.syntheticClaudeSessionPrefix = Self.syntheticClaudeSessionPrefix
        monitoring.stateAccessor = { [weak self] in self?.state ?? SessionState() }
        monitoring.stateUpdater = { [weak self] in self?.state = $0 }
        monitoring.onSessionsReconciled = { [weak self] in
            self?.synchronizeSelection()
            self?.refreshOverlayPlacementIfVisible()
        }
        monitoring.onPersistenceNeeded = { [weak self] in
            self?.discovery.scheduleCodexSessionPersistence()
            self?.discovery.scheduleClaudeSessionPersistence()
            self?.discovery.scheduleOpenCodeSessionPersistence()
        }
        monitoring.onCodexAppRunningChanged = { [weak self] isRunning in
            guard let self else { return }
            if isRunning {
                self.codexAppServer.ensureConnected()
            } else {
                self.codexAppServer.disconnect()
            }
        }

        refreshOverlayDisplayConfiguration()
        refreshTemporaryChatSkills()
        hasFinishedInit = true
    }

    var sessions: [AgentSession] {
        state.sessions
    }

    var allSessions: [AgentSession] {
        state.sessions
    }

    /// Measured by SwiftUI GeometryReader in notification mode. Used by panel controller for sizing.
    /// Uses a tolerance of 2pt to avoid infinite layout loops caused by floating-point jitter
    /// in GeometryReader measurements across consecutive layout passes.
    var measuredNotificationContentHeight: CGFloat = 0 {
        didSet {
            let delta = abs(measuredNotificationContentHeight - oldValue)
            if delta >= 2, measuredNotificationContentHeight > 0 {
                overlay.refreshOverlayPlacementIfVisible()
            }
        }
    }

    var surfacedSessions: [AgentSession] {
        sessionBuckets.primary
    }

    var recentSessions: [AgentSession] {
        sessionBuckets.overflow
    }

    var islandListSessions: [AgentSession] {
        surfacedSessions
    }

    var recentSessionCount: Int {
        recentSessions.count
    }

    var liveSessionCount: Int {
        surfacedSessions.count
    }

    var liveAttentionCount: Int {
        surfacedSessions.filter { $0.phase.requiresAttention }.count
    }

    var liveRunningCount: Int {
        surfacedSessions.filter { $0.phase == .running }.count
    }

    var shouldShowSessionBootstrapPlaceholder: Bool {
        isResolvingInitialLiveSessions
            && liveSessionCount == 0
            && state.sessions.contains(where: \.isTrackedLiveSession)
    }

    var focusedSession: AgentSession? {
        state.session(id: selectedSessionID) ?? surfacedSessions.first ?? state.activeActionableSession ?? state.sessions.first
    }

    var activeIslandCardSession: AgentSession? {
        guard let sessionID = islandSurface.sessionID else {
            return nil
        }

        return state.session(id: sessionID)
    }

    var lastSwitchableIslandSurface: IslandSurface {
        islandSurface.switchableTab?.selectionSurface ?? .sessionList()
    }

    var hasAnySession: Bool {
        !sessions.isEmpty
    }

    var hasCodexSession: Bool {
        sessions.contains(where: { $0.tool == .codex })
    }

    var hasJumpableSession: Bool {
        sessions.contains(where: { $0.jumpTarget != nil })
    }

    var acceptanceSteps: [AcceptanceStep] {
        [
            AcceptanceStep(
                id: "bridge",
                title: "Bridge ready",
                detail: "The app must own the local socket and register as a bridge observer.",
                isComplete: isBridgeReady
            ),
            AcceptanceStep(
                id: "hooks",
                title: "Codex hooks installed",
                detail: "Managed `hooks.json` entries should be present in `~/.codex`.",
                isComplete: hooks.codexHooksInstalled
            ),
            AcceptanceStep(
                id: "overlay",
                title: "Island visible",
                detail: "Show the overlay at least once so the notch/top-bar surface is visible.",
                isComplete: isOverlayVisible
            ),
            AcceptanceStep(
                id: "session",
                title: "A Codex session is observed",
                detail: "Start Codex in Terminal and wait for the first session row to appear.",
                isComplete: hasCodexSession
            ),
            AcceptanceStep(
                id: "jump",
                title: "Jump target captured",
                detail: "At least one session should include terminal jump metadata.",
                isComplete: hasJumpableSession
            ),
        ]
    }

    var acceptanceCompletedCount: Int {
        acceptanceSteps.filter(\.isComplete).count
    }

    var isReadyForFirstAcceptance: Bool {
        acceptanceSteps.prefix(3).allSatisfy(\.isComplete)
    }

    var hasPassedAcceptanceFlow: Bool {
        acceptanceSteps.allSatisfy(\.isComplete)
    }

    var acceptanceStatusTitle: String {
        if hasPassedAcceptanceFlow {
            return "v0.1 acceptance passed"
        }

        if isReadyForFirstAcceptance {
            return "Ready for v0.1 acceptance"
        }

        return "v0.1 acceptance not ready"
    }

    var acceptanceStatusSummary: String {
        if hasPassedAcceptanceFlow {
            return "The current build has completed the first-run checklist end to end."
        }

        if isReadyForFirstAcceptance {
            return "You can start your first acceptance run now. Launch Codex in Terminal and walk the last two steps."
        }

        return "Finish the setup steps in the left column, then start Codex from Terminal."
    }

    func startIfNeeded(
        startBridge: Bool = true,
        shouldPerformBootAnimation: Bool = true,
        loadRuntimeState: Bool = true
    ) {
        guard !hasStarted else {
            return
        }
        hasStarted = true

        if loadRuntimeState {
            isResolvingInitialLiveSessions = true

            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let payload = self.discovery.loadStartupDiscoveryPayload()
                await MainActor.run {
                    self.applyStartupDiscoveryPayload(payload)
                }
            }

            // These are already async or lightweight — safe to start immediately.
            hooks.refreshCodexHookStatus()
            hooks.refreshClaudeHookStatus()
            hooks.refreshOpenCodePluginStatus()
            hooks.refreshClaudeUsageState()
            hooks.startClaudeUsageMonitoringIfNeeded()
            if showCodexUsage {
                hooks.refreshCodexUsageState()
                hooks.startCodexUsageMonitoringIfNeeded()
            }
            usageAnalytics.refreshNow()
            usageAnalytics.startMonitoringIfNeeded()
            updateChecker.startIfNeeded()

        } else {
            isResolvingInitialLiveSessions = false
        }
        refreshOverlayDisplayConfiguration()
        ensureOverlayPanel()
        if shouldPerformBootAnimation {
            performBootAnimation()
        }

        guard startBridge else {
            isBridgeReady = false
            lastActionMessage = loadRuntimeState
                ? "Harness mode active. Bridge startup skipped."
                : "Deterministic harness mode active. Runtime discovery and bridge startup skipped."
            harnessRuntimeMonitor?.recordMilestone("bridgeSkipped", message: lastActionMessage)
            return
        }

        do {
            try bridgeServer.start()
            connectBridgeObserver()
        } catch {
            isBridgeReady = false
            lastActionMessage = "Failed to start local bridge: \(error.localizedDescription)"
            harnessRuntimeMonitor?.recordMilestone("bridgeStartFailed", message: lastActionMessage)
        }
    }

    // MARK: - Bridge observer connection

    private static let bridgeReconnectDelay: Duration = .seconds(2)
    private static let bridgeMaxReconnectDelay: Duration = .seconds(30)

    private func connectBridgeObserver() {
        bridgeTask?.cancel()
        bridgeReconnectTask?.cancel()

        // Explicitly disconnect the old client so its DispatchSource is
        // cancelled deterministically rather than relying on dealloc timing.
        bridgeClient.disconnect()

        // Create a fresh client for each connection attempt so we don't
        // have to worry about stale file-descriptor state.
        let client = LocalBridgeClient()
        bridgeClient = client

        let stream: AsyncThrowingStream<AgentEvent, Error>
        do {
            stream = try client.connect()
        } catch {
            isBridgeReady = false
            lastActionMessage = "Failed to connect bridge observer: \(error.localizedDescription)"
            scheduleBridgeReconnect()
            return
        }

        // A single task handles both registration and event consumption so
        // there is no untracked task that could race with a reconnect.
        bridgeTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await client.send(.registerClient(role: .observer))
                self.isBridgeReady = true
                self.lastActionMessage = "Bridge ready. Waiting for Claude and Codex hook events."
                self.harnessRuntimeMonitor?.recordMilestone("bridgeReady", message: self.lastActionMessage)
            } catch {
                guard !Task.isCancelled else { return }
                self.isBridgeReady = false
                self.lastActionMessage = "Failed to register bridge observer: \(error.localizedDescription)"
                self.harnessRuntimeMonitor?.recordMilestone(
                    "bridgeRegistrationFailed",
                    message: self.lastActionMessage
                )
                self.scheduleBridgeReconnect()
                return
            }

            do {
                for try await event in stream {
                    self.applyTrackedEvent(event)
                }
            } catch {}

            // Stream ended (server closed our connection or transient error).
            // Mark as disconnected and schedule reconnection.
            guard !Task.isCancelled else { return }
            self.isBridgeReady = false
            self.lastActionMessage = "Bridge observer disconnected. Reconnecting…"
            self.harnessRuntimeMonitor?.recordMilestone("bridgeDisconnected", message: self.lastActionMessage)
            self.scheduleBridgeReconnect()
        }
    }

    private func scheduleBridgeReconnect() {
        bridgeReconnectTask?.cancel()
        bridgeReconnectTask = Task { [weak self] in
            var delay = Self.bridgeReconnectDelay
            while !Task.isCancelled {
                try? await Task.sleep(for: delay)
                guard let self, !Task.isCancelled else { return }
                self.connectBridgeObserver()
                // If we're now connected, stop retrying.
                if self.isBridgeReady { return }
                delay = min(delay * 2, Self.bridgeMaxReconnectDelay)
            }
        }
    }

    func select(sessionID: String) {
        selectedSessionID = sessionID
    }

    // MARK: - Overlay forwarding

    func toggleOverlay() { overlay.toggleOverlay() }
    func notchOpen(reason: NotchOpenReason, surface: IslandSurface = .sessionList()) { overlay.notchOpen(reason: reason, surface: surface) }
    func notchClose() { overlay.notchClose() }
    func notchPop() { overlay.notchPop() }
    func performBootAnimation() { overlay.performBootAnimation() }
    func ensureOverlayPanel() { overlay.ensureOverlayPanel() }
    func showOverlay() { overlay.showOverlay() }
    func hideOverlay() { overlay.hideOverlay() }
    func expandNotificationToSessionList(clearExpansion: Bool = false) {
        overlay.expandNotificationToSessionList(clearExpansion: clearExpansion)
    }
    func refreshOverlayDisplayConfiguration() { overlay.refreshOverlayDisplayConfiguration() }
    func refreshOverlayPlacement() { overlay.refreshOverlayPlacement() }
    private func refreshOverlayPlacementIfVisible() { overlay.refreshOverlayPlacementIfVisible() }
    func notePointerInsideIslandSurface() { overlay.notePointerInsideIslandSurface() }
    func handlePointerExitedIslandSurface() { overlay.handlePointerExitedIslandSurface() }
    private func presentNotificationSurface(_ surface: IslandSurface) { overlay.presentNotificationSurface(surface) }
    private func reconcileIslandSurfaceAfterStateChange() { overlay.reconcileIslandSurfaceAfterStateChange() }
    private func dismissNotificationSurfaceIfPresent(for sessionID: String) { overlay.dismissNotificationSurfaceIfPresent(for: sessionID) }
    private func dismissOverlayForJump() { overlay.dismissOverlayForJump() }

    var shouldAutoCollapseOnMouseLeave: Bool { overlay.shouldAutoCollapseOnMouseLeave }
    var autoCollapseOnMouseLeaveRequiresPriorSurfaceEntry: Bool { overlay.autoCollapseOnMouseLeaveRequiresPriorSurfaceEntry }
    var showsNotificationCard: Bool { overlay.showsNotificationCard }

    private static func loadWhiteNoiseState(defaults: UserDefaults) -> WhiteNoiseSelectionState {
        let availableSoundIDs = Set(WhiteNoiseCatalog.soundsByID.keys)
        let selectedIDs = (defaults.array(forKey: whiteNoiseSelectedSoundIDsDefaultsKey) as? [String] ?? [])
            .reduce(into: [String]()) { result, soundID in
                guard availableSoundIDs.contains(soundID), !result.contains(soundID) else { return }
                result.append(soundID)
            }
        let volumes = (defaults.dictionary(forKey: whiteNoiseItemVolumesDefaultsKey) ?? [:])
            .reduce(into: [String: Double]()) { result, entry in
                guard availableSoundIDs.contains(entry.key) else { return }
                if let value = entry.value as? Double {
                    result[entry.key] = clampedVolume(value)
                } else if let value = entry.value as? NSNumber {
                    result[entry.key] = clampedVolume(value.doubleValue)
                }
            }
        let savedGlobalVolume = defaults.object(forKey: whiteNoiseGlobalVolumeDefaultsKey) as? Double

        return WhiteNoiseSelectionState(
            selectedSoundIDs: selectedIDs,
            itemVolumes: volumes,
            globalVolume: clampedVolume(savedGlobalVolume ?? WhiteNoiseSelectionState.defaultGlobalVolume),
            isPaused: true
        )
    }

    private func persistWhiteNoiseState() {
        whiteNoiseDefaults.set(whiteNoiseState.selectedSoundIDs, forKey: Self.whiteNoiseSelectedSoundIDsDefaultsKey)
        whiteNoiseDefaults.set(whiteNoiseState.itemVolumes, forKey: Self.whiteNoiseItemVolumesDefaultsKey)
        whiteNoiseDefaults.set(whiteNoiseState.globalVolume, forKey: Self.whiteNoiseGlobalVolumeDefaultsKey)
    }

    private static func clampedVolume(_ volume: Double) -> Double {
        min(1, max(0, volume))
    }

    // MARK: - Temporary chat

    private static func loadTemporaryChatConfiguration(
        store: TemporaryChatConfigurationStore,
        userDefaults: UserDefaults = .standard
    ) -> TemporaryChatStoredConfiguration {
        if let stored = try? store.loadConfiguration() {
            return stored
        }

        let provider = LLMProviderKind(
            rawValue: userDefaults.string(forKey: legacyLLMProviderDefaultsKey) ?? ""
        ) ?? .openAI
        let migrated = TemporaryChatStoredConfiguration(
            provider: provider,
            model: userDefaults.string(forKey: legacyLLMModelDefaultsKey) ?? provider.defaultModel,
            baseURL: userDefaults.string(forKey: legacyLLMBaseURLDefaultsKey) ?? provider.defaultBaseURL
        )
        try? store.saveConfiguration(migrated)
        return migrated
    }

    private func persistTemporaryChatConfigurationIfReady() {
        guard hasFinishedInit else { return }
        do {
            try temporaryChatConfigurationStore.saveConfiguration(TemporaryChatStoredConfiguration(
                provider: temporaryChatProvider,
                model: temporaryChatModel,
                baseURL: temporaryChatBaseURL
            ))
        } catch {
            lastActionMessage = "Temporary chat configuration save failed: \(error.localizedDescription)"
        }
    }

    func loadTemporaryChatAPIKeyIfNeeded() {
        guard temporaryChatAPIKeyLoadedProvider != temporaryChatProvider else { return }

        isRestoringTemporaryChatAPIKey = true
        temporaryChatAPIKey = temporaryChatAPIKeyLoader(temporaryChatProvider)
        temporaryChatAPIKeyLoadedProvider = temporaryChatProvider
        isRestoringTemporaryChatAPIKey = false
    }

    private func resetTemporaryChatAPIKeyForProviderChange() {
        isRestoringTemporaryChatAPIKey = true
        temporaryChatAPIKey = ""
        temporaryChatAPIKeyLoadedProvider = nil
        isRestoringTemporaryChatAPIKey = false
    }

    private func refreshTemporaryChatTokenStats(source: TemporaryChatTokenStatsSource = .estimated) {
        switch source {
        case .estimated:
            temporaryChatTokenStats = TemporaryChatTokenStats.estimate(
                messages: temporaryChatMessages,
                provider: temporaryChatProvider,
                model: temporaryChatModel
            )
        case .provider:
            break
        }
    }

    private func noteTemporaryChatUsage(_ usage: TemporaryChatUsage, configuration: LLMChatConfiguration) {
        guard let inputTokens = usage.inputTokens else { return }
        temporaryChatTokenStats = TemporaryChatTokenStats.providerReported(
            inputTokens: inputTokens,
            provider: configuration.provider,
            model: configuration.effectiveModel
        )
    }

    var temporaryChatConfiguration: LLMChatConfiguration {
        LLMChatConfiguration(
            provider: temporaryChatProvider,
            model: temporaryChatModel,
            baseURL: temporaryChatBaseURL,
            apiKey: temporaryChatAPIKey,
            enabledCapabilities: temporaryChatWebSearchMode == .off ? [] : [.webSearch],
            webSearchMode: temporaryChatWebSearchMode
        )
    }

    var temporaryChatCapabilities: Set<TemporaryChatCapability> {
        TemporaryChatCapabilityRegistry.capabilities(
            provider: temporaryChatProvider,
            model: temporaryChatModel
        )
    }

    var temporaryChatCanUseWebSearch: Bool {
        temporaryChatCapabilities.contains(.webSearch)
    }

    var temporaryChatCanAttachImages: Bool {
        temporaryChatCapabilities.contains(.imageInput)
    }

    var temporaryChatCanAttachFiles: Bool {
        temporaryChatCapabilities.contains(.fileInput)
    }

    func openTemporaryChatFromShortcut() {
        notchOpen(reason: .shortcut, surface: .temporaryChat)
    }

    func performShortcutAction(_ action: IslandShortcutAction) {
        switch action {
        case .openIsland:
            notchOpen(reason: .shortcut, surface: islandSurface.switchableTab?.selectionSurface ?? .sessionList())
        case .openSessions:
            notchOpen(reason: .shortcut, surface: .sessionList())
        case .openChat:
            notchOpen(reason: .shortcut, surface: .temporaryChat)
        }
    }

    func cycleIslandSurface(backwards: Bool = false) {
        guard let nextSurface = islandSurface.nextSwitchableSurface(backwards: backwards) else {
            return
        }

        islandSurface = nextSurface
        refreshOverlayPlacementIfVisible()
    }

    func showIslandSurface(_ tab: IslandSurfaceTab) {
        islandSurface = tab.selectionSurface
        refreshOverlayPlacementIfVisible()
    }

    func showSessionListSurface() {
        showIslandSurface(.sessions)
    }

    func showTemporaryChatSurface() {
        showIslandSurface(.chat)
    }

    // MARK: - White noise

    var whiteNoiseCategories: [WhiteNoiseCategory] {
        WhiteNoiseCatalog.categories
    }

    var selectedWhiteNoiseSounds: [WhiteNoiseSound] {
        whiteNoiseState.selectedSoundIDs.compactMap { WhiteNoiseCatalog.sound(id: $0) }
    }

    var isWhiteNoisePlaying: Bool {
        whiteNoiseState.isPlaying
    }

    func showWhiteNoiseSurface() {
        showIslandSurface(.whiteNoise)
    }

    func toggleWhiteNoiseSound(_ sound: WhiteNoiseSound) {
        if let index = whiteNoiseState.selectedSoundIDs.firstIndex(of: sound.id) {
            whiteNoiseState.selectedSoundIDs.remove(at: index)
            if whiteNoiseState.selectedSoundIDs.isEmpty {
                whiteNoiseState.isPaused = true
            }
            lastActionMessage = "Removed \(sound.label) from white noise mix."
        } else {
            whiteNoiseState.selectedSoundIDs.append(sound.id)
            whiteNoiseState.itemVolumes[sound.id] = whiteNoiseState.volume(for: sound.id)
            whiteNoiseState.isPaused = false
            lastActionMessage = "Added \(sound.label) to white noise mix."
        }
    }

    func setWhiteNoiseVolume(_ volume: Double, for sound: WhiteNoiseSound) {
        whiteNoiseState.itemVolumes[sound.id] = Self.clampedVolume(volume)
    }

    func setWhiteNoiseGlobalVolume(_ volume: Double) {
        whiteNoiseState.globalVolume = Self.clampedVolume(volume)
    }

    func toggleWhiteNoisePaused() {
        guard whiteNoiseState.hasSelection else {
            return
        }
        whiteNoiseState.isPaused.toggle()
        lastActionMessage = whiteNoiseState.isPaused
            ? "White noise mix paused."
            : "White noise mix resumed."
    }

    func clearWhiteNoiseMix() {
        whiteNoiseState = WhiteNoiseSelectionState(
            selectedSoundIDs: [],
            itemVolumes: [:],
            globalVolume: whiteNoiseState.globalVolume,
            isPaused: true
        )
        whiteNoisePlayerService.stopAll()
        lastActionMessage = "White noise mix cleared."
    }

    func clearTemporaryChat() {
        temporaryChatTask?.cancel()
        temporaryChatTask = nil
        temporaryChatMessages.removeAll()
        temporaryChatPendingParts.removeAll()
        temporaryChatWebSearchMode = .auto
        temporaryChatLastError = nil
        temporaryChatIsSending = false
    }

    func cancelTemporaryChatResponse() {
        guard temporaryChatIsSending else { return }
        temporaryChatTask?.cancel()
    }

    func retryLastTemporaryChatMessage() {
        guard !temporaryChatIsSending,
              let lastUserIndex = temporaryChatMessages.lastIndex(where: { $0.role == .user }) else {
            return
        }

        let parts = temporaryChatMessages[lastUserIndex].parts
        temporaryChatMessages = Array(temporaryChatMessages.prefix(upTo: lastUserIndex))
        sendTemporaryChatMessage(parts: parts)
    }

    func toggleTemporaryChatWebSearch() {
        guard temporaryChatCanUseWebSearch, !temporaryChatIsSending else { return }
        temporaryChatWebSearchMode = temporaryChatWebSearchMode.next
    }

    func importTemporaryChatImageAttachments() {
        importTemporaryChatAttachments(
            allowedContentTypes: [.image],
            as: .imageInput
        )
    }

    func importTemporaryChatFileAttachments() {
        importTemporaryChatAttachments(
            allowedContentTypes: [.pdf, .plainText, .text, .json, .data],
            as: .fileInput
        )
    }

    func removeTemporaryChatPendingPart(id: UUID) {
        temporaryChatPendingParts.removeAll { $0.id == id }
    }

    func refreshTemporaryChatSkills() {
        let discovery = TemporaryChatSkillDiscovery(roots: TemporaryChatSkillDiscovery.defaultRoots())
        temporaryChatSkills = discovery.discover()
        temporaryChatInstalledSkills = discovery.installedSkills(
            managedDirectoryURL: temporaryChatSkillInstallManager.installDirectoryURL
        )
    }

    func importTemporaryChatSkill() {
        guard !isTemporaryChatSkillImporting else { return }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.title = lang.t("settings.skills.import")
        panel.prompt = lang.t("settings.general.install")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isTemporaryChatSkillImporting = true
        temporaryChatSkillLastError = nil
        defer { isTemporaryChatSkillImporting = false }

        do {
            let skill = try temporaryChatSkillInstallManager.importSkill(from: url)
            refreshTemporaryChatSkills()
            lastActionMessage = "Installed Skill \(skill.title)."
        } catch {
            temporaryChatSkillLastError = error.localizedDescription
            lastActionMessage = "Skill import failed: \(error.localizedDescription)"
        }
    }

    func uninstallTemporaryChatSkill(_ skill: TemporaryChatInstalledSkill) {
        temporaryChatSkillLastError = nil
        do {
            try temporaryChatSkillInstallManager.uninstallSkill(skill)
            refreshTemporaryChatSkills()
            lastActionMessage = "Uninstalled Skill \(skill.definition.title)."
        } catch {
            temporaryChatSkillLastError = error.localizedDescription
            lastActionMessage = "Skill uninstall failed: \(error.localizedDescription)"
        }
    }

    func revealTemporaryChatSkill(_ skill: TemporaryChatInstalledSkill) {
        NSWorkspace.shared.activateFileViewerSelecting([skill.definition.fileURL])
    }

    private func importTemporaryChatAttachments(
        allowedContentTypes: [UTType],
        as capability: TemporaryChatCapability
    ) {
        guard temporaryChatCapabilities.contains(capability), !temporaryChatIsSending else { return }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = allowedContentTypes
        guard panel.runModal() == .OK else { return }

        do {
            for url in panel.urls {
                try appendTemporaryChatAttachment(from: url, as: capability)
            }
            lastActionMessage = "Attached \(panel.urls.count) item\(panel.urls.count == 1 ? "" : "s") to temporary chat."
        } catch {
            temporaryChatLastError = error.localizedDescription
            lastActionMessage = "Temporary chat attachment failed: \(error.localizedDescription)"
        }
    }

    private func appendTemporaryChatAttachment(from url: URL, as capability: TemporaryChatCapability) throws {
        let data = try Data(contentsOf: url)
        guard data.count <= 20 * 1024 * 1024 else {
            throw TemporaryChatError.attachmentTooLarge(url.lastPathComponent)
        }

        let mediaType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        let attachment = TemporaryChatAttachmentPart(
            filename: url.lastPathComponent,
            mediaType: mediaType,
            data: data
        )
        switch capability {
        case .imageInput:
            temporaryChatPendingParts.append(.image(attachment))
        case .fileInput:
            temporaryChatPendingParts.append(.file(attachment))
        case .webSearch:
            break
        }
    }

    func sendTemporaryChatMessage(_ text: String) {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!prompt.isEmpty || !temporaryChatPendingParts.isEmpty), !temporaryChatIsSending else {
            return
        }

        temporaryChatLastError = nil
        let userParts = ([prompt.isEmpty ? nil : TemporaryChatMessagePart.text(TemporaryChatTextPart(text: prompt))]
            + temporaryChatPendingParts.map(Optional.some))
            .compactMap { $0 }
        temporaryChatPendingParts.removeAll()
        loadTemporaryChatAPIKeyIfNeeded()
        let configuration = temporaryChatConfiguration
        temporaryChatWebSearchMode = .auto

        sendTemporaryChatMessage(parts: userParts, configuration: configuration)
    }

    private func sendTemporaryChatMessage(
        parts userParts: [TemporaryChatMessagePart],
        configuration: LLMChatConfiguration? = nil
    ) {
        guard !userParts.isEmpty, !temporaryChatIsSending else {
            return
        }

        temporaryChatLastError = nil
        if configuration == nil {
            loadTemporaryChatAPIKeyIfNeeded()
        }
        let configuration = configuration ?? temporaryChatConfiguration
        temporaryChatMessages.append(TemporaryChatMessage(role: .user, parts: userParts))
        let messages = temporaryChatMessages
        let assistantMessage = TemporaryChatMessage(role: .assistant, content: "")
        temporaryChatMessages.append(assistantMessage)
        temporaryChatIsSending = true
        lastActionMessage = "Sending temporary chat message…"

        let task = Task.detached { [weak self, temporaryChatStream] in
            do {
                let stream = try temporaryChatStream(messages, configuration)
                var reply = ""
                for try await event in stream {
                    switch event {
                    case let .text(chunk) where !chunk.isEmpty:
                        reply.append(chunk)
                        await self?.replaceTemporaryChatMessage(id: assistantMessage.id, content: reply)
                    case let .usage(usage):
                        await self?.noteTemporaryChatUsage(usage, configuration: configuration)
                    case let .source(source):
                        await self?.appendTemporaryChatMessagePart(id: assistantMessage.id, part: .webCitation(source))
                    case let .toolResult(result):
                        await self?.appendTemporaryChatMessagePart(id: assistantMessage.id, part: .toolResult(result))
                    case .searchStarted, .searchQuery, .searchCompleted, .searchFailed:
                        continue
                    case .text:
                        continue
                    }
                }

                let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedReply.isEmpty else {
                    throw TemporaryChatError.emptyResponse
                }
                await self?.finishTemporaryChatMessage(id: assistantMessage.id, content: trimmedReply)
            } catch {
                if Task.isCancelled {
                    await self?.cancelTemporaryChatMessage(id: assistantMessage.id)
                } else {
                    await self?.failTemporaryChatMessage(id: assistantMessage.id, error: error)
                }
            }
        }
        temporaryChatTask = task
    }

    private func replaceTemporaryChatMessage(id: UUID, content: String) {
        guard let index = temporaryChatMessages.firstIndex(where: { $0.id == id }) else {
            return
        }
        temporaryChatMessages[index] = temporaryChatMessages[index].replacingContent(content)
    }

    private func appendTemporaryChatMessagePart(id: UUID, part: TemporaryChatMessagePart) {
        guard let index = temporaryChatMessages.firstIndex(where: { $0.id == id }),
              !temporaryChatMessages[index].parts.contains(where: { $0 == part }) else {
            return
        }
        temporaryChatMessages[index] = temporaryChatMessages[index].appendingPart(part)
    }

    private func finishTemporaryChatMessage(id: UUID, content: String) {
        let reportedStats = temporaryChatTokenStats.source == .provider ? temporaryChatTokenStats : nil
        replaceTemporaryChatMessage(id: id, content: content)
        if let reportedStats {
            temporaryChatTokenStats = reportedStats
        }
        temporaryChatIsSending = false
        temporaryChatTask = nil
        lastActionMessage = "Temporary chat reply received."
    }

    private func cancelTemporaryChatMessage(id: UUID) {
        if let index = temporaryChatMessages.firstIndex(where: { $0.id == id }),
           temporaryChatMessages[index].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            temporaryChatMessages.remove(at: index)
        }
        temporaryChatIsSending = false
        temporaryChatTask = nil
        lastActionMessage = "Temporary chat response stopped."
    }

    private func failTemporaryChatMessage(id: UUID, error: Error) {
        if let index = temporaryChatMessages.firstIndex(where: { $0.id == id }),
           temporaryChatMessages[index].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            temporaryChatMessages.remove(at: index)
        }
        temporaryChatLastError = error.localizedDescription
        temporaryChatIsSending = false
        temporaryChatTask = nil
        lastActionMessage = "Temporary chat failed: \(error.localizedDescription)"
    }

    // MARK: - Shortcut settings

    func shortcutDescription(for action: IslandShortcutAction) -> String {
        shortcuts[action]?.displayText ?? "—"
    }

    func startRecordingShortcut(_ action: IslandShortcutAction) {
        recordingShortcutAction = action
    }

    func cancelRecordingShortcut() {
        recordingShortcutAction = nil
    }

    func captureShortcutEvent(_ event: NSEvent) {
        guard let action = recordingShortcutAction,
              let shortcut = IslandKeyboardShortcut(event: event) else {
            return
        }

        shortcuts[action] = shortcut
        recordingShortcutAction = nil
        lastActionMessage = "Updated shortcut for \(action.rawValue) to \(shortcut.displayText)."
    }

    func resetShortcutsToDefaults() {
        shortcuts = IslandKeyboardShortcut.defaultShortcuts
        recordingShortcutAction = nil
    }

    private static func loadShortcuts() -> [IslandShortcutAction: IslandKeyboardShortcut] {
        guard let data = UserDefaults.standard.data(forKey: islandShortcutsDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: IslandKeyboardShortcut].self, from: data) else {
            return IslandKeyboardShortcut.defaultShortcuts
        }

        var merged = IslandKeyboardShortcut.defaultShortcuts
        for (rawAction, shortcut) in decoded {
            guard let action = IslandShortcutAction(rawValue: rawAction) else { continue }
            merged[action] = shortcut
        }
        return merged
    }

    private func persistShortcuts() {
        let encoded = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        guard let data = try? JSONEncoder().encode(encoded) else { return }
        UserDefaults.standard.set(data, forKey: Self.islandShortcutsDefaultsKey)
    }

    func loadDebugSnapshot(
        _ snapshot: IslandDebugSnapshot,
        presentOverlay: Bool = false,
        autoCollapseNotificationCards: Bool = false
    ) {
        state = SessionState(sessions: snapshot.sessions)
        selectedSessionID = snapshot.selectedSessionID ?? snapshot.sessions.first?.id
        lastActionMessage = "Loaded debug scenario: \(snapshot.title)."
        harnessRuntimeMonitor?.recordMilestone("scenarioLoaded", message: snapshot.title)

        overlay.applyOverlayState(from: snapshot, presentOverlay: presentOverlay, autoCollapseNotificationCards: autoCollapseNotificationCards)
    }

    func showSettings() {
        openSettingsWindow?()
        if let window = NSApp.windows.first(where: { $0.title == "Aisland Settings" }) {
            window.orderFrontRegardless()
            window.makeKey()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Opens Settings on General so users can review app behavior and
    /// macOS authorization shortcuts after the install guide was removed.
    func showOnboarding() {
        showSettings()
        NotificationCenter.default.post(name: .openIslandSelectGeneralTab, object: nil)
    }

    func showControlCenter() {
        guard let window = NSApp.windows.first(where: { $0.title == "Aisland Debug" }) else {
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        window.orderFrontRegardless()
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideControlCenter() {
        guard let window = NSApp.windows.first(where: { $0.title == "Aisland Debug" }) else {
            return
        }

        window.orderOut(nil)
    }

    func toggleSoundMuted() {
        isSoundMuted.toggle()
    }

    func approveFocusedPermission(_ approved: Bool) {
        guard let session = focusedSession else {
            return
        }

        send(
            .resolvePermission(sessionID: session.id, resolution: permissionResolution(for: approved)),
            userMessage: approved
                ? "Approving permission for \(session.title)."
                : "Denying permission for \(session.title)."
        )
    }

    func answerFocusedQuestion(_ answer: String) {
        guard let session = focusedSession else {
            return
        }

        if session.tool == .codex {
            answerQuestion(for: session.id, answer: QuestionPromptResponse(answer: answer))
            return
        }

        send(
            .answerQuestion(sessionID: session.id, response: QuestionPromptResponse(answer: answer)),
            userMessage: "Sending answer \"\(answer)\" for \(session.title)."
        )
    }

    func jumpToFocusedSession() {
        jump(to: focusedSession?.jumpTarget)
    }

    func jumpToSession(_ session: AgentSession) {
        guard let jumpTarget = session.jumpTarget,
              jumpTarget.terminalApp.lowercased() != "unknown" else {
            lastActionMessage = "Cannot jump: terminal app is unknown."
            return
        }
        jump(to: jumpTarget)
    }

    private func jump(to jumpTarget: JumpTarget?) {
        guard let jumpTarget else {
            lastActionMessage = "No jump target is available yet."
            return
        }

        let shouldDelayForDismissAnimation = isOverlayVisible
        let jumpAction = terminalJumpAction

        dismissOverlayForJump()
        jumpTask?.cancel()
        jumpTask = Task { [weak self] in
            if shouldDelayForDismissAnimation {
                try? await Task.sleep(for: Self.jumpOverlayDismissLeadTime)
            }

            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try jumpAction(jumpTarget)
                }.value

                guard !Task.isCancelled else {
                    return
                }

                self?.lastActionMessage = result
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                self?.lastActionMessage = "Jump failed: \(error.localizedDescription)"
            }
        }
    }

    func approvePermission(for sessionID: String, approved: Bool) {
        guard let session = state.session(id: sessionID) else {
            return
        }

        let resolution = permissionResolution(for: approved)
        dismissNotificationSurfaceIfPresent(for: sessionID)
        state.resolvePermission(sessionID: session.id, resolution: resolution)
        synchronizeSelection()
        refreshOverlayPlacementIfVisible()

        send(
            .resolvePermission(sessionID: session.id, resolution: resolution),
            userMessage: approved
                ? "Approving permission for \(session.title)."
                : "Denying permission for \(session.title)."
        )
    }

    func approvePermission(for sessionID: String, action: ApprovalAction) {
        guard let session = state.session(id: sessionID) else {
            return
        }

        let resolution: PermissionResolution
        let message: String

        switch action {
        case .deny:
            resolution = .deny(message: "Permission denied in Aisland.", interrupt: false)
            message = "Denying permission for \(session.title)."
        case .allowOnce:
            resolution = .allowOnce()
            message = "Approving permission for \(session.title)."
        case let .allowWithUpdates(updates):
            resolution = .allowOnce(updatedPermissions: updates)
            message = "Always allowing for \(session.title)."
        }

        dismissNotificationSurfaceIfPresent(for: sessionID)
        state.resolvePermission(sessionID: session.id, resolution: resolution)
        synchronizeSelection()
        refreshOverlayPlacementIfVisible()

        send(
            .resolvePermission(sessionID: session.id, resolution: resolution),
            userMessage: message
        )
    }

    func answerQuestion(for sessionID: String, answer: QuestionPromptResponse) {
        guard let session = state.session(id: sessionID) else {
            return
        }
        let prompt = session.questionPrompt

        dismissNotificationSurfaceIfPresent(for: sessionID)
        state.answerQuestion(sessionID: session.id, response: answer)
        synchronizeSelection()
        refreshOverlayPlacementIfVisible()

        if session.tool == .codex {
            submitCodexQuestionAnswer(session: session, prompt: prompt, answer: answer)
            return
        }

        send(
            .answerQuestion(sessionID: session.id, response: answer),
            userMessage: "Sending answer for \(session.title)."
        )
    }

    private func submitCodexQuestionAnswer(
        session: AgentSession,
        prompt: QuestionPrompt?,
        answer: QuestionPromptResponse
    ) {
        if let prompt,
           codexAppServer.submitUserInput(for: session.id, response: answer, prompt: prompt) {
            lastActionMessage = "Sent answer to Codex app-server for \(session.title)."
            return
        }

        let answerText = terminalAnswerText(for: answer)
        guard !answerText.isEmpty else {
            lastActionMessage = "No answer text to send to Codex."
            return
        }

        lastActionMessage = "Sending answer to Codex terminal for \(session.title)…"
        prepareForTerminalTextInjection()
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            let success = await Task.detached(priority: .userInitiated) {
                TerminalTextSender.send(answerText, to: session)
            }.value

            self?.lastActionMessage = success
                ? "Sent answer to Codex terminal for \(session.title)."
                : "Could not inject answer into Codex terminal for \(session.title)."
        }
    }

    private func terminalAnswerText(for answer: QuestionPromptResponse) -> String {
        if let rawAnswer = answer.rawAnswer?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawAnswer.isEmpty {
            return rawAnswer
        }

        let values = answer.answers.values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if values.count == 1 {
            return values[0]
        }

        return answer.displaySummary
    }

    func replyToSession(_ session: AgentSession, text: String) {
        dismissNotificationSurfaceIfPresent(for: session.id)
        synchronizeSelection()
        refreshOverlayPlacementIfVisible()

        lastActionMessage = "Sending reply to \(session.title)…"
        prepareForTerminalTextInjection()

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            let success = await Task.detached(priority: .userInitiated) {
                TerminalTextSender.send(text, to: session)
            }.value

            self?.lastActionMessage = success
                ? "Sent reply to \(session.title)."
                : "Failed to send reply to \(session.title)."
        }
    }

    private func prepareForTerminalTextInjection() {
        dismissOverlayForJump()
        NSApp.deactivate()
    }


    private func send(_ command: BridgeCommand, userMessage: String) {
        lastActionMessage = userMessage

        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await self.bridgeClient.send(command)
            } catch {
                self.lastActionMessage = "Failed to send bridge command: \(error.localizedDescription)"
            }
        }
    }

    private func permissionResolution(for approved: Bool) -> PermissionResolution {
        if approved {
            return .allowOnce()
        }

        return .deny(message: "Permission denied in Aisland.", interrupt: false)
    }

    func applyTrackedEvent(
        _ event: AgentEvent,
        updateLastActionMessage: Bool = true,
        ingress: TrackedEventIngress = .bridge
    ) {
        // Snapshot whether this session was already completed before applying
        // the event. Used to suppress duplicate/stale completion notifications
        // (e.g. rollout watcher re-discovering an old completion on startup,
        // or producing a duplicate sessionCompleted that races with the bridge).
        let wasAlreadyCompleted: Bool = {
            guard case let .sessionCompleted(payload) = event else { return false }
            return state.session(id: payload.sessionID)?.phase == .completed
        }()

        // Guard: don't let rollout events downgrade a session from completed
        // back to running. The bridge's sessionCompleted is authoritative; the
        // rollout watcher may have read the JSONL before task_complete was
        // flushed, producing a stale activityUpdated(phase: .running).
        if ingress == .rollout,
           case let .activityUpdated(payload) = event,
           payload.phase == .running,
           state.session(id: payload.sessionID)?.phase == .completed {
            return
        }

        state.apply(event)
        reconcileIslandSurfaceAfterStateChange()
        if ingress == .bridge {
            monitoring.markSessionProcessAlive(for: event)
        }
        synchronizeSelection()
        discovery.refreshCodexRolloutTracking()
        refreshOverlayPlacementIfVisible()
        discovery.scheduleCodexSessionPersistence()
        discovery.scheduleClaudeSessionPersistence()
        discovery.scheduleOpenCodeSessionPersistence()

        if updateLastActionMessage {
            lastActionMessage = describe(event)
        }

        if let surface = IslandSurface.notificationSurface(for: event) {
            scheduleNotificationSurfacePresentationIfNeeded(
                surface,
                wasAlreadyCompleted: wasAlreadyCompleted,
                ingress: ingress
            )
        }
    }

    private func scheduleNotificationSurfacePresentationIfNeeded(
        _ surface: IslandSurface,
        wasAlreadyCompleted: Bool,
        ingress: TrackedEventIngress
    ) {
        guard !wasAlreadyCompleted,
              notificationSurfaceIsEligibleForPresentation(surface, ingress: ingress),
              let sessionID = surface.sessionID,
              let session = state.session(id: sessionID) else {
            return
        }

        guard suppressFrontmostNotifications else {
            presentNotificationSurface(surface)
            return
        }

        notificationPresentationTask?.cancel()
        notificationPresentationTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let shouldSuppress = await self.isNotificationSessionAlreadyFrontmost(session)
            guard !Task.isCancelled,
                  !shouldSuppress,
                  self.notificationSurfaceIsEligibleForPresentation(surface, ingress: ingress) else {
                return
            }

            self.presentNotificationSurface(surface)
        }
    }

    private func notificationSurfaceIsEligibleForPresentation(
        _ surface: IslandSurface,
        ingress: TrackedEventIngress
    ) -> Bool {
        guard let sessionID = surface.sessionID,
              let session = state.session(id: sessionID) else {
            return false
        }

        return (ingress == .bridge || !isResolvingInitialLiveSessions)
            && (notchStatus == .closed || notchOpenReason == .notification)
            && surface.matchesCurrentState(of: session)
    }

    private func synchronizeSelection() {
        let surfacedIDs = Set(surfacedSessions.map(\.id))

        if let activeAction = state.activeActionableSession {
            selectedSessionID = activeAction.id
            return
        }

        guard let selectedSessionID,
              surfacedIDs.contains(selectedSessionID),
              state.session(id: selectedSessionID) != nil else {
            self.selectedSessionID = surfacedSessions.first?.id ?? state.sessions.first?.id
            return
        }
    }

    /// Applies startup discovery results on the main thread after background I/O completes.
    private func applyStartupDiscoveryPayload(_ payload: SessionDiscoveryCoordinator.StartupDiscoveryPayload) {
        discovery.applyStartupDiscoveryPayload(payload)

        // Apply hooks binary URL and update the installed copy if the app ships a newer version.
        hooks.hooksBinaryURL = payload.hooksBinaryURL
        hooks.updateHooksBinaryIfNeeded()

        // Auto-install missing hooks and usage bridge, then run health checks.
        if payload.hooksBinaryURL != nil {
            Task { @MainActor [weak self] in
                guard let self else { return }

                // Wait for all status reads to complete before checking install state.
                await self.hooks.refreshAllHookStatusAndWait()

                // Reconcile persisted intent with what is actually on disk. For
                // legacy users this records existing hooks as `.installed` and
                // marks first-launch as complete so onboarding does not appear
                // on upgrade. Must run after status reads and before any
                // install decision.
                self.hooks.migrateIntentStoreIfNeeded()

                // Install every managed hook by default while preserving
                // explicit user opt-outs.
                if self.hooks.shouldAutoInstall(.claudeCode) { self.installClaudeHooks() }
                if self.hooks.shouldAutoInstall(.codex) { self.installCodexHooks() }
                if self.hooks.shouldAutoInstall(.openCode) { self.installOpenCodePlugin() }
                if self.hooks.shouldAutoInstall(.claudeUsageBridge) { self.installClaudeUsageBridge() }

                // Run health checks after install to detect stale paths, conflicts, etc.
                try? await Task.sleep(for: .milliseconds(500))
                await self.hooks.repairHooksIfNeeded()
            }
        }

        // Reconcile attachments and start monitoring (requires sessions to be loaded).
        monitoring.reconcileSessionAttachments()
        monitoring.startMonitoringIfNeeded()
    }


    private var sessionBuckets: (primary: [AgentSession], overflow: [AgentSession]) {
        if let cached = _cachedSessionBuckets {
            return cached
        }
        let result = computeSessionBuckets()
        _cachedSessionBuckets = result
        return result
    }

    private func computeSessionBuckets() -> (primary: [AgentSession], overflow: [AgentSession]) {
        let now = Date.now
        let rankedSessions = state.sessions.sorted { lhs, rhs in
            let lhsScore = displayPriority(for: lhs, now: now)
            let rhsScore = displayPriority(for: rhs, now: now)

            if lhsScore == rhsScore {
                if lhs.islandActivityDate == rhs.islandActivityDate {
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }

                return lhs.islandActivityDate > rhs.islandActivityDate
            }

            return lhsScore > rhsScore
        }

        var primary: [AgentSession] = []

        for session in rankedSessions where session.isVisibleInIsland {
            guard !session.isSubagentSession else { continue }

            primary.append(session)
        }

        let primaryIDs = Set(primary.map(\.id))
        let overflow = rankedSessions.filter { !primaryIDs.contains($0.id) && !$0.isSubagentSession }
        return (primary, overflow)
    }

    private func displayPriority(for session: AgentSession, now: Date) -> Int {
        var score = 0

        let presence = session.islandPresence(at: now)

        if session.isProcessAlive {
            score += presence == .inactive ? 3_000 : 12_000
        } else if session.isDemoSession || session.phase.requiresAttention {
            score += 6_000
        }

        if session.phase.requiresAttention {
            score += 10_000
        }

        if session.currentToolName?.isEmpty == false {
            score += 6_000
        }

        if session.jumpTarget != nil {
            score += 4_000
        }

        switch session.phase {
        case .running:
            score += 2_000
        case .waitingForApproval:
            score += 1_500
        case .waitingForAnswer:
            score += 1_200
        case .completed:
            score += 600
        }

        let age = now.timeIntervalSince(session.islandActivityDate)
        switch age {
        case ..<120:
            score += 500
        case ..<900:
            score += 250
        case ..<3_600:
            score += 120
        case ..<21_600:
            score += 40
        default:
            break
        }

        return score
    }

    private func describe(_ event: AgentEvent) -> String {
        switch event {
        case let .sessionStarted(payload):
            return "Session started: \(payload.title)"
        case let .activityUpdated(payload):
            return payload.summary
        case let .permissionRequested(payload):
            return payload.request.summary
        case let .questionAsked(payload):
            return payload.prompt.title
        case let .sessionCompleted(payload):
            return payload.summary
        case let .jumpTargetUpdated(payload):
            return "Jump target updated to \(payload.jumpTarget.terminalApp)."
        case let .sessionMetadataUpdated(payload):
            if let currentTool = payload.codexMetadata.currentTool {
                return "Codex is running \(currentTool)."
            }

            return payload.codexMetadata.lastAssistantMessage ?? "Codex session metadata updated."
        case let .claudeSessionMetadataUpdated(payload):
            if let currentTool = payload.claudeMetadata.currentTool {
                return "Claude is running \(currentTool)."
            }

            return payload.claudeMetadata.lastAssistantMessage ?? "Claude session metadata updated."
        case let .openCodeSessionMetadataUpdated(payload):
            if let currentTool = payload.openCodeMetadata.currentTool {
                return "OpenCode is running \(currentTool)."
            }

            return payload.openCodeMetadata.lastAssistantMessage ?? "OpenCode session metadata updated."
        case let .actionableStateResolved(payload):
            return "Actionable state resolved for session \(payload.sessionID)."
        }
    }

    func quitApplication() {
        NSApplication.shared.terminate(nil)
    }

    deinit {
        MainActor.assumeIsolated {
            whiteNoisePlayerService.stopAll()
        }
    }

}

// MARK: - Hex color helpers

extension String {
    var normalizedHexColorString: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard raw.count == 6, raw.allSatisfy(\.isHexDigit) else { return "#6E9FFF" }
        return "#\(raw.uppercased())"
    }
}

extension Color {
    init?(hex: String) {
        let raw = String(hex.normalizedHexColorString.dropFirst())
        guard let value = Int(raw, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self = Color(red: red, green: green, blue: blue)
    }

    var opaqueHexString: String? {
        guard let nsColor = NSColor(self).usingColorSpace(.deviceRGB) else { return nil }
        let r = Int(round(nsColor.redComponent * 255))
        let g = Int(round(nsColor.greenComponent * 255))
        let b = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
