import SwiftUI
import AppKit
import AislandCore

// MARK: - Settings tabs

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case setup
    case ai
    case skills
    case usage
    case appearance
    case shortcuts

    var id: String { rawValue }

    func label(_ lang: LanguageManager) -> String {
        switch self {
        case .general:    lang.t("settings.tab.general")
        case .setup:      lang.t("settings.tab.setup")
        case .ai:         lang.t("settings.tab.ai")
        case .skills:     lang.t("settings.tab.skills")
        case .appearance: lang.t("settings.tab.appearance")
        case .usage:      lang.t("settings.tab.usage")
        case .shortcuts:  lang.t("settings.tab.shortcuts")
        }
    }

    var icon: String {
        switch self {
        case .general:    "gearshape.fill"
        case .setup:      "arrow.down.circle.fill"
        case .ai:         "sparkles"
        case .skills:     "wand.and.stars"
        case .appearance: "paintbrush.fill"
        case .usage:      "chart.bar.xaxis"
        case .shortcuts:  "keyboard.fill"
        }
    }

    func iconColor(theme: IslandThemePalette) -> Color {
        switch self {
        case .general:    theme.textTertiary
        case .setup:      theme.warning
        case .ai:         theme.primary
        case .skills:     theme.secondary
        case .appearance: theme.primary
        case .usage:      theme.primary
        case .shortcuts:  theme.textTertiary
        }
    }

    var section: SettingsSection {
        switch self {
        case .setup, .usage:
            .agentTasks
        case .ai, .skills:
            .aiChat
        case .general, .appearance, .shortcuts:
            .appSettings
        }
    }
}

enum SettingsSection: String, CaseIterable {
    case agentTasks
    case aiChat
    case appSettings

    func header(_ lang: LanguageManager) -> String {
        switch self {
        case .agentTasks:  lang.t("settings.section.agentTasks")
        case .aiChat:      lang.t("settings.section.aiChat")
        case .appSettings: lang.t("settings.section.appSettings")
        }
    }

    var tabs: [SettingsTab] {
        SettingsTab.allCases.filter { $0.section == self }
    }
}

// MARK: - Root settings view

struct SettingsView: View {
    var model: AppModel
    @State private var selectedTab: SettingsTab = .general

    private var lang: LanguageManager { model.lang }
    private var theme: IslandThemePalette { IslandTheme.palette(for: model.interfaceTheme) }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detailView
        }
        .frame(minWidth: 680, idealWidth: 780, minHeight: 480, idealHeight: 560)
        .preferredColorScheme(.dark)
        .islandTheme(model.interfaceTheme)
        .background(theme.background.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: .openIslandSelectSetupTab)) { _ in
            selectedTab = .setup
        }
    }

    // MARK: Sidebar

    @ViewBuilder
    private var sidebar: some View {
        List(selection: $selectedTab) {
            ForEach(SettingsSection.allCases, id: \.self) { section in
                if !section.tabs.isEmpty {
                    Section(section.header(lang)) {
                        ForEach(section.tabs) { tab in
                            Label {
                                Text(tab.label(lang))
                            } icon: {
                                Image(systemName: tab.icon)
                                    .foregroundStyle(tab.iconColor(theme: theme))
                            }
                            .tag(tab)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(theme.backgroundElevated)
    }

    // MARK: Detail

    @ViewBuilder
    private var detailView: some View {
        ZStack(alignment: .topTrailing) {
            switch selectedTab {
            case .general:
                GeneralSettingsPane(model: model)
            case .setup:
                SetupSettingsPane(model: model)
            case .ai:
                LLMSettingsPane(model: model)
            case .skills:
                SkillsSettingsPane(model: model)
            case .appearance:
                AppearanceSettingsPane(model: model)
            case .usage:
                UsageAnalyticsPane(model: model)
            case .shortcuts:
                ShortcutSettingsPane(model: model)
            }

            if model.updateChecker.hasUpdate, let version = model.updateChecker.latestVersion {
                UpdateBanner(version: version, lang: lang) {
                    model.updateChecker.checkForUpdates()
                }
                .padding(.top, 8)
                .padding(.trailing, 16)
            }
        }
    }
}

// MARK: - General

struct GeneralSettingsPane: View {
    var model: AppModel

    private var lang: LanguageManager { model.lang }
    private var notificationSoundNames: [String] {
        let names = NotificationSoundService.availableSounds()
        guard !names.contains(model.selectedSoundName) else {
            return names
        }
        return [model.selectedSoundName] + names
    }

    var body: some View {
        Form {
            Section(lang.t("settings.general.language")) {
                Picker(lang.t("settings.general.language"), selection: Binding(
                    get: { lang.language },
                    set: { lang.language = $0 }
                )) {
                    Text(lang.t("settings.general.languageSystem")).tag(LanguageManager.AppLanguage.system)
                    Text(lang.t("settings.general.languageEnglish")).tag(LanguageManager.AppLanguage.en)
                    Text(lang.t("settings.general.languageChinese")).tag(LanguageManager.AppLanguage.zhHans)
                    Text(lang.t("settings.general.languageTraditionalChinese")).tag(LanguageManager.AppLanguage.zhHant)
                }
            }

            Section(lang.t("settings.display.monitor")) {
                Picker(lang.t("settings.display.position"), selection: Binding(
                    get: { model.overlayDisplaySelectionID },
                    set: { model.overlayDisplaySelectionID = $0 }
                )) {
                    Text(lang.t("settings.general.automatic")).tag(OverlayDisplayOption.automaticID)
                    ForEach(model.overlayDisplayOptions) { option in
                        Text(option.title).tag(option.id)
                    }
                }

                if let diag = model.overlayPlacementDiagnostics {
                    LabeledContent(lang.t("settings.display.currentScreen"), value: diag.targetScreenName)
                    LabeledContent(lang.t("settings.display.layoutMode"), value: diag.modeDescription)
                }
            }

            Section(lang.t("settings.general.behavior")) {
                Toggle(lang.t("settings.general.showDockIcon"), isOn: Binding(
                    get: { model.showDockIcon },
                    set: { model.showDockIcon = $0 }
                ))
                Toggle(lang.t("settings.general.hapticFeedback"), isOn: Binding(
                    get: { model.hapticFeedbackEnabled },
                    set: { model.hapticFeedbackEnabled = $0 }
                ))
                Toggle(lang.t("settings.general.completionReply"), isOn: Binding(
                    get: { model.completionReplyEnabled },
                    set: { model.completionReplyEnabled = $0 }
                ))
                Picker(lang.t("settings.general.questionOptionLayout"), selection: Binding(
                    get: { model.questionOptionLayout },
                    set: { model.questionOptionLayout = $0 }
                )) {
                    Text(lang.t("settings.general.questionOptionLayout.horizontal")).tag(QuestionOptionLayout.horizontal)
                    Text(lang.t("settings.general.questionOptionLayout.vertical")).tag(QuestionOptionLayout.vertical)
                }
                Toggle(lang.t("settings.general.suppressFrontmostNotifications"), isOn: Binding(
                    get: { model.suppressFrontmostNotifications },
                    set: { model.suppressFrontmostNotifications = $0 }
                ))
            }

            Section(lang.t("settings.sound.notifications")) {
                Toggle(lang.t("settings.sound.enabled"), isOn: Binding(
                    get: { !model.isSoundMuted },
                    set: { model.isSoundMuted = !$0 }
                ))

                Picker(lang.t("settings.sound.selectSound"), selection: Binding(
                    get: { model.selectedSoundName },
                    set: { name in
                        model.selectedSoundName = name
                        NotificationSoundService.play(name)
                    }
                )) {
                    ForEach(notificationSoundNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
                .disabled(model.isSoundMuted)
            }

        }
        .formStyle(.grouped)
        .islandSettingsPaneBackground()
        .navigationTitle(lang.t("settings.tab.general"))
    }
}

// MARK: - AI Chat

struct LLMSettingsPane: View {
    var model: AppModel
    @State private var providerSearchText = ""
    @Environment(\.islandTheme) private var theme

    private var lang: LanguageManager { model.lang }
    private let providerGridColumns = [
        GridItem(.adaptive(minimum: 176), spacing: 10, alignment: .top),
    ]

    private var filteredProviders: [LLMProviderKind] {
        let query = providerSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return LLMProviderKind.allCases }
        return LLMProviderKind.allCases.filter { provider in
            provider.searchTokens.contains(where: { $0.contains(query) })
        }
    }

    var body: some View {
        Form {
            Section(lang.t("settings.ai.provider")) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextField(lang.t("settings.ai.provider.search"), text: $providerSearchText)
                        .textFieldStyle(.plain)

                    if !providerSearchText.isEmpty {
                        Button {
                            providerSearchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear provider search")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.surfaceContainer.opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.outline.opacity(0.16), lineWidth: 1)
                )

                LazyVGrid(columns: providerGridColumns, spacing: 10) {
                    ForEach(filteredProviders) { provider in
                        Button {
                            model.temporaryChatProvider = provider
                            model.loadTemporaryChatAPIKeyIfNeeded()
                        } label: {
                            LLMProviderCard(
                                provider: provider,
                                isSelected: model.temporaryChatProvider == provider
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .animation(.easeInOut(duration: 0.16), value: model.temporaryChatProvider)

                Text(lang.t("settings.ai.provider.help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(lang.t("settings.ai.connection")) {
                TextField(lang.t("settings.ai.model"), text: Binding(
                    get: { model.temporaryChatModel },
                    set: { model.temporaryChatModel = $0 }
                ))
                TextField(lang.t("settings.ai.baseURL"), text: Binding(
                    get: { model.temporaryChatBaseURL },
                    set: { model.temporaryChatBaseURL = $0 }
                ))
                SecureField(lang.t("settings.ai.apiKey"), text: Binding(
                    get: { model.temporaryChatAPIKey },
                    set: { model.temporaryChatAPIKey = $0 }
                ))
                Text(lang.t("settings.ai.keychainHelp"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .islandSettingsPaneBackground()
        .navigationTitle(lang.t("settings.tab.ai"))
        .onAppear {
            model.loadTemporaryChatAPIKeyIfNeeded()
        }
    }
}

// MARK: - Skills

struct SkillsSettingsPane: View {
    var model: AppModel
    @State private var pendingUninstallSkill: TemporaryChatInstalledSkill?

    private var lang: LanguageManager { model.lang }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(lang.t("settings.skills.about.title"), systemImage: "doc.text.magnifyingglass")
                        .font(.headline)
                    Text(lang.t("settings.skills.about.body"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button {
                        model.importTemporaryChatSkill()
                    } label: {
                        Label(lang.t("settings.skills.import"), systemImage: "plus.circle.fill")
                    }
                    .disabled(model.isTemporaryChatSkillImporting)

                    if model.isTemporaryChatSkillImporting {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Spacer()

                    Button(lang.t("usage.refresh")) {
                        model.refreshTemporaryChatSkills()
                    }
                }

                if let error = model.temporaryChatSkillLastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(lang.t("settings.skills.installed")) {
                if model.temporaryChatInstalledSkills.isEmpty {
                    ContentUnavailableView(
                        lang.t("settings.skills.empty.title"),
                        systemImage: "wand.and.stars",
                        description: Text(lang.t("settings.skills.empty.body"))
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(model.temporaryChatInstalledSkills) { skill in
                        skillRow(skill)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .islandSettingsPaneBackground()
        .navigationTitle(lang.t("settings.tab.skills"))
        .onAppear {
            model.refreshTemporaryChatSkills()
        }
        .alert(
            lang.t("settings.skills.uninstall.title"),
            isPresented: Binding(
                get: { pendingUninstallSkill != nil },
                set: { if !$0 { pendingUninstallSkill = nil } }
            )
        ) {
            Button(lang.t("settings.general.uninstallConfirmAction"), role: .destructive) {
                if let pendingUninstallSkill {
                    model.uninstallTemporaryChatSkill(pendingUninstallSkill)
                }
                pendingUninstallSkill = nil
            }
            Button(lang.t("settings.general.cancel"), role: .cancel) {
                pendingUninstallSkill = nil
            }
        } message: {
            Text(lang.t("settings.skills.uninstall.message"))
        }
    }

    private func skillRow(_ skill: TemporaryChatInstalledSkill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(skill.definition.title)
                    .font(.system(size: 13, weight: .semibold))
                if skill.definition.alwaysApply {
                    badge(lang.t("settings.skills.alwaysApply"), color: .blue)
                }
                if skill.isAislandManaged {
                    badge(lang.t("settings.skills.managed"), color: .green)
                } else {
                    badge(lang.t("settings.skills.readOnly"), color: .secondary)
                }
                if skill.isOverridden {
                    badge(lang.t("settings.skills.overridden"), color: .orange)
                }
                Spacer(minLength: 8)
            }

            Text(skill.definition.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(sourceTitle(for: skill.definition.source))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(skill.definition.fileURL.path)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if !skill.definition.tags.isEmpty {
                Text(skill.definition.tags.map { "#\($0)" }.joined(separator: " "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if skill.isOverridden, let active = skill.activeDefinition {
                Text(lang.t("settings.skills.overridden.help", sourceTitle(for: active.source)))
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            HStack {
                Button(lang.t("settings.skills.reveal")) {
                    model.revealTemporaryChatSkill(skill)
                }

                if skill.isAislandManaged {
                    Button(lang.t("settings.general.uninstall"), role: .destructive) {
                        pendingUninstallSkill = skill
                    }
                }

                Spacer()
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func sourceTitle(for source: TemporaryChatSkillSource) -> String {
        switch source {
        case .repository:
            lang.t("settings.skills.source.repository")
        case .project:
            lang.t("settings.skills.source.project")
        case .user:
            lang.t("settings.skills.source.user")
        }
    }
}

private struct LLMProviderCard: View {
    let provider: LLMProviderKind
    let isSelected: Bool
    @Environment(\.islandTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? theme.primary.opacity(0.14) : theme.surfaceContainerHigh.opacity(0.62))

                Image(systemName: provider.systemImageName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isSelected ? theme.primary : theme.textSecondary.opacity(0.82))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(provider.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(provider.defaultModel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)

                Text(provider.shortName)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? theme.primary : theme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? theme.primary.opacity(0.10) : theme.surfaceContainerHigh.opacity(0.62))
                    )
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 86, maxHeight: 86, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(theme.onPrimary, theme.primary)
                    .padding(8)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isSelected ? theme.primary : theme.outline.opacity(0.16),
                    lineWidth: isSelected ? 1.8 : 1
                )
        )
        .shadow(
            color: isSelected ? theme.primary.opacity(0.10) : theme.shadow.opacity(0.08),
            radius: isSelected ? 8 : 3,
            x: 0,
            y: isSelected ? 4 : 2
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var cardBackground: Color {
        if isSelected {
            return theme.primary.opacity(0.06)
        }

        return theme.card.opacity(0.74)
    }
}

// MARK: - Shortcuts

struct ShortcutSettingsPane: View {
    var model: AppModel

    private var lang: LanguageManager { model.lang }

    var body: some View {
        Form {
            Section(lang.t("settings.shortcuts.global")) {
                ForEach(IslandShortcutAction.allCases) { action in
                    shortcutRow(action)
                }

                Button(lang.t("settings.shortcuts.reset")) {
                    model.resetShortcutsToDefaults()
                }
            }

            Section(lang.t("settings.shortcuts.navigation")) {
                LabeledContent(lang.t("settings.shortcuts.tabKey"), value: "Tab")
                Text(lang.t("settings.shortcuts.tabKey.help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .islandSettingsPaneBackground()
        .navigationTitle(lang.t("settings.tab.shortcuts"))
    }

    private func shortcutRow(_ action: IslandShortcutAction) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(action.title(lang))
                    .font(.system(size: 13, weight: .semibold))
                Text(action.detail(lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(model.recordingShortcutAction == action
                ? lang.t("settings.shortcuts.recording")
                : model.shortcutDescription(for: action))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.secondary.opacity(0.12), in: Capsule())
                .background(
                    ShortcutCaptureView(isRecording: model.recordingShortcutAction == action) { event in
                        model.captureShortcutEvent(event)
                    }
                )

            Button(model.recordingShortcutAction == action
                ? lang.t("settings.general.cancel")
                : lang.t("settings.shortcuts.record")) {
                if model.recordingShortcutAction == action {
                    model.cancelRecordingShortcut()
                } else {
                    model.startRecordingShortcut(action)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    var isRecording: Bool
    var onCapture: (NSEvent) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.onCapture = onCapture
        guard isRecording else { return }
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class CaptureView: NSView {
        var onCapture: ((NSEvent) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            onCapture?(event)
        }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            onCapture?(event)
            return true
        }
    }
}

// MARK: - Setup

struct SetupSettingsPane: View {
    var model: AppModel

    private var lang: LanguageManager { model.lang }

    var body: some View {
        Form {
            if !model.hasAnyInstalledAgent {
                emptyStateBanner
            }

            Section {
                automaticHookRow(
                    name: "Claude Code",
                    installed: model.claudeHooksInstalled,
                    busy: model.isClaudeHookSetupBusy,
                    configLocationURL: model.claudeHookStatus?.settingsURL
                )

                automaticHookRow(
                    name: "Codex",
                    installed: model.codexHooksInstalled,
                    busy: model.isCodexSetupBusy,
                    configLocationURL: codexHookConfigURL
                )

                automaticHookRow(
                    name: "OpenCode",
                    installed: model.openCodePluginInstalled,
                    busy: model.isOpenCodeSetupBusy,
                    configLocationURL: model.openCodePluginStatus?.configURL
                )
            } header: {
                Text(lang.t("setup.section.hooks"))
            } footer: {
                Text(lang.t("setup.hooks.autoManagedFooter"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Section(lang.t("setup.section.permissions")) {
                HStack(alignment: .top) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lang.t("setup.permissionsTitle"))
                            Text(lang.t("setup.permissionsDesc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.shield")
                    }
                    Spacer()
                }
            }

            hookDiagnosticsSection
        }
        .formStyle(.grouped)
        .islandSettingsPaneBackground()
        .navigationTitle(lang.t("settings.tab.setup"))
    }

    @ViewBuilder
    private var emptyStateBanner: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(lang.t("setup.banner.noHooks.title"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(lang.t("setup.banner.noHooks.message"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private var codexHookConfigURL: URL? {
        if let hooksURL = model.codexHookStatus?.hooksURL, FileManager.default.fileExists(atPath: hooksURL.path) {
            return hooksURL
        }
        return model.codexHookStatus?.configURL ?? model.codexHookStatus?.hooksURL
    }

    private var hasErrors: Bool {
        let claudeErrors = model.claudeHealthReport?.errors.count ?? 0
        let codexErrors = model.codexHealthReport?.errors.count ?? 0
        let openCodeErrors = model.openCodeHealthReport?.errors.count ?? 0
        return claudeErrors + codexErrors + openCodeErrors > 0
    }

    private var hasRepairableIssues: Bool {
        let claude = model.claudeHealthReport?.repairableIssues.isEmpty == false
        let codex = model.codexHealthReport?.repairableIssues.isEmpty == false
        let openCode = model.openCodeHealthReport?.repairableIssues.isEmpty == false
        return claude || codex || openCode
    }

    @ViewBuilder
    private var hookDiagnosticsSection: some View {
        Section {
            if let claudeReport = model.claudeHealthReport, !claudeReport.errors.isEmpty {
                issueList(report: claudeReport)
            }
            if let codexReport = model.codexHealthReport, !codexReport.errors.isEmpty {
                issueList(report: codexReport)
            }
            if let openCodeReport = model.openCodeHealthReport, !openCodeReport.errors.isEmpty {
                issueList(report: openCodeReport)
            }

            if model.claudeHealthReport == nil && model.codexHealthReport == nil && model.openCodeHealthReport == nil {
                HStack {
                    Text(lang.t("setup.diagnostics.notRun"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(lang.t("setup.diagnostics.runCheck")) {
                        model.runHealthChecks()
                    }
                }
            } else if !hasErrors {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(lang.t("setup.diagnostics.allHealthy"))
                    Spacer()
                    Button(lang.t("setup.diagnostics.recheck")) {
                        model.runHealthChecks()
                    }
                    .font(.caption)
                }
            } else {
                HStack(spacing: 10) {
                    Button(lang.t("setup.diagnostics.recheck")) {
                        model.runHealthChecks()
                    }

                    if hasRepairableIssues {
                        Button(lang.t("setup.diagnostics.repair")) {
                            model.repairHooks()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        } header: {
            HStack(spacing: 4) {
                Text(lang.t("setup.section.diagnostics"))
                if hasErrors {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption2)
                }
            }
        }
    }

    @ViewBuilder
    private func issueList(report: HookHealthReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(agentName(for: report.agent))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(Array(report.errors.enumerated()), id: \.offset) { _, issue in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: issueIcon(for: issue))
                        .font(.caption2)
                        .foregroundStyle(issueColor(for: issue))
                        .frame(width: 14)

                    Text(issue.description)
                        .font(.caption)
                        .foregroundStyle(issue.severity == .info ? .secondary : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let binaryPath = report.binaryPath {
                Text("Binary: \(binaryPath)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func agentName(for agent: String) -> String {
        switch agent {
        case "claude":
            return "Claude Code"
        case "codex":
            return "Codex"
        case "opencode":
            return "OpenCode"
        default:
            return agent
        }
    }

    private func issueIcon(for issue: HookHealthReport.Issue) -> String {
        switch issue.severity {
        case .info: "info.circle.fill"
        case .error: issue.isAutoRepairable ? "wrench.fill" : "exclamationmark.triangle.fill"
        }
    }

    private func issueColor(for issue: HookHealthReport.Issue) -> Color {
        switch issue.severity {
        case .info: .blue
        case .error: issue.isAutoRepairable ? .orange : .red
        }
    }

    @ViewBuilder
    private func automaticHookRow(
        name: String,
        installed: Bool,
        busy: Bool,
        configLocationURL: URL? = nil
    ) -> some View {
        HStack {
            Label(name, systemImage: "terminal")
            Spacer()
            if busy {
                ProgressView().controlSize(.small)
            } else {
                HStack(spacing: 8) {
                    if installed, let configLocationURL {
                        Button {
                            revealInFinder(configLocationURL)
                        } label: {
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(lang.t("setup.revealConfigLocation"))
                    }
                    HStack(spacing: 4) {
                        Image(systemName: installed ? "checkmark.circle.fill" : "clock.arrow.circlepath")
                            .foregroundStyle(installed ? .green : .secondary)
                        Text(installed ? lang.t("settings.general.activated") : lang.t("setup.hookAutomaticPending"))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func revealInFinder(_ url: URL) {
        let fileManager = FileManager.default
        let standardizedURL = url.standardizedFileURL

        if fileManager.fileExists(atPath: standardizedURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([standardizedURL])
            return
        }

        let directoryURL = standardizedURL.deletingLastPathComponent()
        if fileManager.fileExists(atPath: directoryURL.path) {
            NSWorkspace.shared.open(directoryURL)
        }
    }
}

// MARK: - Placeholder

struct PlaceholderSettingsPane: View {
    var model: AppModel
    let titleKey: String
    let subtitleKey: String

    private var lang: LanguageManager { model.lang }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(lang.t(subtitleKey))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .navigationTitle(lang.t(titleKey))
    }
}

// MARK: - Update Banner

struct UpdateBanner: View {
    let version: String
    let lang: LanguageManager
    var onUpdate: () -> Void
    @Environment(\.islandTheme) private var theme

    var body: some View {
        Button(action: onUpdate) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(lang.t("settings.update.available", version))
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(theme.primary)
            )
        }
        .buttonStyle(.plain)
        .shadow(color: theme.primary.opacity(0.3), radius: 4, y: 2)
    }
}
