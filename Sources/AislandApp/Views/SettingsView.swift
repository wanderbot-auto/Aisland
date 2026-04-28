import SwiftUI
import AppKit
import AislandCore

// MARK: - Settings tabs

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case ai
    case skills
    case usage
    case appearance
    case shortcuts

    var id: String { rawValue }

    func label(_ lang: LanguageManager) -> String {
        switch self {
        case .general:    lang.t("settings.tab.general")
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
        case .ai:         theme.primary
        case .skills:     theme.secondary
        case .appearance: theme.primary
        case .usage:      theme.primary
        case .shortcuts:  theme.textTertiary
        }
    }

    var section: SettingsSection {
        switch self {
        case .usage:
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
        .onReceive(NotificationCenter.default.publisher(for: .openIslandSelectGeneralTab)) { _ in
            selectedTab = .general
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

            Section(lang.t("settings.general.authorization")) {
                authorizationRow(
                    titleKey: "settings.general.authorization.accessibility",
                    descriptionKey: "settings.general.authorization.accessibilityDesc",
                    systemImage: "figure.child.circle",
                    pane: .accessibility
                )

                authorizationRow(
                    titleKey: "settings.general.authorization.automation",
                    descriptionKey: "settings.general.authorization.automationDesc",
                    systemImage: "applescript",
                    pane: .automation
                )
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

    private func authorizationRow(
        titleKey: String,
        descriptionKey: String,
        systemImage: String,
        pane: MacOSPrivacyPane
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t(titleKey))
                    Text(lang.t(descriptionKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }

            Spacer()

            Button(lang.t("settings.general.authorization.open")) {
                openSystemSettings(pane)
            }
        }
    }

    private func openSystemSettings(_ pane: MacOSPrivacyPane) {
        guard let url = URL(string: pane.urlString) else { return }
        if NSWorkspace.shared.open(url) { return }
        if let fallbackURL = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(fallbackURL)
        }
    }
}

private enum MacOSPrivacyPane {
    case accessibility
    case automation

    var urlString: String {
        switch self {
        case .accessibility:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .automation:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        }
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
    @Environment(\.islandTheme) private var theme

    private var lang: LanguageManager { model.lang }
    private var installedSkills: [TemporaryChatInstalledSkill] { model.temporaryChatInstalledSkills }
    private var projectSkills: [TemporaryChatInstalledSkill] {
        installedSkills.filter { installScope(for: $0) == .project }
    }
    private var globalSkills: [TemporaryChatInstalledSkill] {
        installedSkills.filter { installScope(for: $0) == .global }
    }
    private var skillGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    }

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

            Section {
                if installedSkills.isEmpty {
                    ContentUnavailableView(
                        lang.t("settings.skills.empty.title"),
                        systemImage: "wand.and.stars",
                        description: Text(lang.t("settings.skills.empty.body"))
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    skillGroup(
                        title: lang.t("settings.skills.project"),
                        skills: projectSkills,
                        scope: .project
                    )
                    skillGroup(
                        title: lang.t("settings.skills.global"),
                        skills: globalSkills,
                        scope: .global
                    )
                }
            } header: {
                Text(lang.t("settings.skills.installed"))
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

    private func skillGroup(
        title: String,
        skills: [TemporaryChatInstalledSkill],
        scope: TemporaryChatSkillInstallScope
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: scope.systemImageName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(scope.color(theme: theme))
                    .frame(width: 24, height: 24)
                    .background(scope.color(theme: theme).opacity(0.12), in: Circle())
                Text(title)
                    .font(IslandTheme.bodyFont(size: 13, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text("\(skills.count)")
                    .font(IslandTheme.labelFont(size: 10))
                    .foregroundStyle(scope.color(theme: theme))
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(scope.color(theme: theme).opacity(0.10), in: Capsule())
                Spacer(minLength: 0)
            }

            if skills.isEmpty {
                Text(lang.t("settings.skills.empty.scope"))
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(theme.surfaceContainer.opacity(0.26))
                    )
            } else {
                LazyVGrid(columns: skillGridColumns, alignment: .leading, spacing: 12) {
                    ForEach(skills) { skill in
                        skillCard(skill)
                    }
                }
            }
        }
        .padding(.bottom, scope == .project ? 12 : 0)
    }

    private func skillCard(_ skill: TemporaryChatInstalledSkill) -> some View {
        let scope = installScope(for: skill)
        let iconColor = skillIconColor(for: skill, scope: scope)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor.opacity(0.14))
                    Image(systemName: skillIconName(for: skill))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.definition.title)
                        .font(IslandTheme.bodyFont(size: 13, weight: .semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        badge(scope.title(lang), color: scope.color(theme: theme))
                        badge(
                            skill.isAislandManaged ? lang.t("settings.skills.managed") : lang.t("settings.skills.readOnly"),
                            color: skill.isAislandManaged ? theme.success : theme.textSecondary
                        )
                        if skill.definition.alwaysApply {
                            badge(lang.t("settings.skills.alwaysApply"), color: theme.primary)
                        }
                        if skill.isOverridden {
                            badge(lang.t("settings.skills.overridden"), color: theme.warning)
                        } else {
                            badge(lang.t("settings.skills.active"), color: theme.success)
                        }
                    }
                    .lineLimit(1)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                Text(skillRootDirectory(for: skill))
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Spacer(minLength: 0)

                if skill.isAislandManaged {
                    Button(lang.t("settings.general.uninstall"), role: .destructive) {
                        pendingUninstallSkill = skill
                    }
                    .buttonStyle(.borderless)
                }
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceContainer.opacity(0.38), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            if skill.isOverridden, let active = skill.activeDefinition {
                Text(lang.t("settings.skills.overridden.help", installScope(for: active).title(lang)))
                    .font(.caption2)
                    .foregroundStyle(theme.warning)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.card.opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(scope.color(theme: theme).opacity(0.18), lineWidth: 1)
        )
        .shadow(color: theme.shadow.opacity(0.10), radius: 10, x: 0, y: 5)
    }

    private func skillIconName(for skill: TemporaryChatInstalledSkill) -> String {
        let attributes = skillAttributeText(for: skill)

        if attributes.containsAny(["figma", "design", "ui", "ux", "logo", "svg", "image", "visual"]) {
            return "paintpalette.fill"
        }
        if attributes.containsAny(["swift", "python", "javascript", "typescript", "react", "code", "coding", "api", "sdk"]) {
            return "chevron.left.forwardslash.chevron.right"
        }
        if attributes.containsAny(["browser", "web", "website", "frontend", "html", "css"]) {
            return "safari.fill"
        }
        if attributes.containsAny(["doc", "docs", "docx", "documentation", "markdown", "writing", "report", "memo"]) {
            return "text.book.closed.fill"
        }
        if attributes.containsAny(["excel", "spreadsheet", "csv", "data", "sql", "table"]) {
            return "tablecells.fill"
        }
        if attributes.containsAny(["slides", "powerpoint", "ppt", "pptx", "presentation"]) {
            return "rectangle.on.rectangle.angled.fill"
        }
        if attributes.containsAny(["chat", "message", "wecom", "slack", "discord"]) {
            return "bubble.left.and.bubble.right.fill"
        }
        if attributes.containsAny(["calendar", "schedule", "meeting", "todo", "reminder"]) {
            return "calendar.badge.clock"
        }
        if attributes.containsAny(["terminal", "shell", "cli", "git", "ci", "build", "test"]) {
            return "terminal.fill"
        }
        if attributes.containsAny(["ai", "llm", "openai", "prompt", "agent"]) {
            return "brain.head.profile"
        }
        if attributes.containsAny(["plugin", "mcp", "extension"]) {
            return "puzzlepiece.extension.fill"
        }
        if skill.definition.alwaysApply {
            return "sparkles"
        }

        return installScope(for: skill).systemImageName
    }

    private func skillIconColor(
        for skill: TemporaryChatInstalledSkill,
        scope: TemporaryChatSkillInstallScope
    ) -> Color {
        if skill.isOverridden {
            return theme.warning
        }
        if skill.definition.alwaysApply {
            return theme.primary
        }
        if skill.definition.tags.isEmpty {
            return scope.color(theme: theme)
        }
        return scope == .project ? theme.tertiary : theme.secondary
    }

    private func skillAttributeText(for skill: TemporaryChatInstalledSkill) -> String {
        ([skill.definition.id, skill.definition.title, skill.definition.summary] + skill.definition.tags)
            .joined(separator: " ")
            .lowercased()
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func installScope(for skill: TemporaryChatInstalledSkill) -> TemporaryChatSkillInstallScope {
        if skill.isAislandManaged {
            return .global
        }

        return installScope(for: skill.definition)
    }

    private func installScope(for definition: TemporaryChatSkillDefinition) -> TemporaryChatSkillInstallScope {
        switch definition.source {
        case .repository, .project:
            return .project
        case .user:
            return .global
        }
    }

    private func skillRootDirectory(for skill: TemporaryChatInstalledSkill) -> String {
        let skillDirectory = skill.definition.fileURL.deletingLastPathComponent()
        let parentDirectory = skillDirectory.deletingLastPathComponent()
        if parentDirectory.lastPathComponent.lowercased() == "skills" {
            return parentDirectory.path
        }
        return skillDirectory.path
    }
}

private enum TemporaryChatSkillInstallScope: CaseIterable, Identifiable {
    case global
    case project

    var id: String {
        switch self {
        case .global: "global"
        case .project: "project"
        }
    }

    var systemImageName: String {
        switch self {
        case .global: "globe"
        case .project: "folder.badge.gearshape"
        }
    }

    func title(_ lang: LanguageManager) -> String {
        switch self {
        case .global:
            lang.t("settings.skills.scope.global")
        case .project:
            lang.t("settings.skills.scope.project")
        }
    }

    func color(theme: IslandThemePalette) -> Color {
        switch self {
        case .global:
            theme.primary
        case .project:
            theme.tertiary
        }
    }
}

private extension String {
    func containsAny(_ needles: [String]) -> Bool {
        let tokens = Set(
            components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
        )

        return needles.contains { needle in
            let normalizedNeedle = needle.lowercased()
            return tokens.contains(normalizedNeedle)
                || (normalizedNeedle.count > 3 && contains(normalizedNeedle))
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
