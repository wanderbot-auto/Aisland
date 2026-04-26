import SwiftUI
import AppKit
import AislandCore

// MARK: - Settings tabs

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case setup
    case ai
    case skills
    case whiteNoise
    case display
    case usage
    case sound
    case appearance
    case shortcuts

    var id: String { rawValue }

    func label(_ lang: LanguageManager) -> String {
        switch self {
        case .general:    lang.t("settings.tab.general")
        case .setup:      lang.t("settings.tab.setup")
        case .ai:         lang.t("settings.tab.ai")
        case .skills:     lang.t("settings.tab.skills")
        case .whiteNoise: lang.t("settings.tab.whiteNoise")
        case .appearance: lang.t("settings.tab.appearance")
        case .display:    lang.t("settings.tab.display")
        case .usage:      lang.t("settings.tab.usage")
        case .sound:      lang.t("settings.tab.sound")
        case .shortcuts:  lang.t("settings.tab.shortcuts")
        }
    }

    var icon: String {
        switch self {
        case .general:    "gearshape.fill"
        case .setup:      "arrow.down.circle.fill"
        case .ai:         "sparkles"
        case .skills:     "wand.and.stars"
        case .whiteNoise: "waveform"
        case .appearance: "paintbrush.fill"
        case .display:    "textformat.size"
        case .usage:      "chart.bar.xaxis"
        case .sound:      "speaker.wave.2.fill"
        case .shortcuts:  "keyboard.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .general:    .gray
        case .setup:      .orange
        case .ai:         .cyan
        case .skills:     .teal
        case .whiteNoise: .mint
        case .appearance: .purple
        case .display:    .blue
        case .usage:      .mint
        case .sound:      .green
        case .shortcuts:  .gray
        }
    }

    var section: SettingsSection {
        switch self {
        case .setup, .usage, .display:
            .agentTasks
        case .ai, .skills:
            .aiChat
        case .whiteNoise, .sound:
            .whiteNoise
        case .general, .appearance, .shortcuts:
            .appSettings
        }
    }
}

enum SettingsSection: String, CaseIterable {
    case agentTasks
    case aiChat
    case whiteNoise
    case appSettings

    func header(_ lang: LanguageManager) -> String {
        switch self {
        case .agentTasks:  lang.t("settings.section.agentTasks")
        case .aiChat:      lang.t("settings.section.aiChat")
        case .whiteNoise:  lang.t("settings.section.whiteNoise")
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

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detailView
        }
        .frame(minWidth: 680, idealWidth: 780, minHeight: 480, idealHeight: 560)
        .preferredColorScheme(.dark)
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
                                    .foregroundStyle(tab.iconColor)
                            }
                            .tag(tab)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
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
            case .whiteNoise:
                WhiteNoiseSettingsPane(model: model)
            case .appearance:
                AppearanceSettingsPane(model: model)
            case .display:
                DisplaySettingsPane(model: model)
            case .usage:
                UsageAnalyticsPane(model: model)
            case .sound:
                SoundSettingsPane(model: model)
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
                Toggle(lang.t("settings.general.suppressFrontmostNotifications"), isOn: Binding(
                    get: { model.suppressFrontmostNotifications },
                    set: { model.suppressFrontmostNotifications = $0 }
                ))
            }

        }
        .formStyle(.grouped)
        .navigationTitle(lang.t("settings.tab.general"))
    }
}

// MARK: - AI Chat

struct LLMSettingsPane: View {
    var model: AppModel
    @State private var providerSearchText = ""

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
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
                )

                LazyVGrid(columns: providerGridColumns, spacing: 10) {
                    ForEach(filteredProviders) { provider in
                        Button {
                            model.temporaryChatProvider = provider
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

            Section(lang.t("settings.ai.models")) {
                ForEach(Array(model.temporaryChatProvider.popularModels), id: \.self) { modelName in
                    suggestedModelButton(modelName)
                }
            }

            Section(lang.t("settings.ai.shortcut")) {
                LabeledContent(
                    lang.t("settings.ai.openChat"),
                    value: model.shortcutDescription(for: .openChat)
                )
                Text(lang.t("settings.ai.shortcutHelp"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(lang.t("settings.tab.ai"))
    }

    private func suggestedModelButton(_ modelName: String) -> some View {
        Button {
            model.temporaryChatModel = modelName
        } label: {
            HStack {
                Text(modelName)
                Spacer()
                if model.temporaryChatModel == modelName {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
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

// MARK: - White Noise

struct WhiteNoiseSettingsPane: View {
    var model: AppModel

    private var lang: LanguageManager { model.lang }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lang.t("settings.whiteNoise.title"))
                    .font(.title2.weight(.semibold))
                Text(lang.t("settings.whiteNoise.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            WhiteNoiseView(model: model)
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(lang.t("settings.tab.whiteNoise"))
    }
}

private struct LLMProviderCard: View {
    let provider: LLMProviderKind
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(provider.settingsAccentColor.opacity(isSelected ? 0.22 : 0.14))

                Image(systemName: provider.systemImageName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(provider.settingsAccentColor)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(provider.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(provider.defaultModel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)

                Text(provider.shortName)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(provider.settingsAccentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(provider.settingsAccentColor.opacity(0.12))
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
                    .foregroundStyle(Color.white, Color.accentColor)
                    .padding(8)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.16),
                    lineWidth: isSelected ? 1.8 : 1
                )
        )
        .shadow(
            color: isSelected ? Color.accentColor.opacity(0.16) : Color.black.opacity(0.04),
            radius: isSelected ? 10 : 4,
            x: 0,
            y: isSelected ? 5 : 2
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var cardBackground: Color {
        if isSelected {
            return provider.settingsAccentColor.opacity(0.10)
        }

        return Color(nsColor: .controlBackgroundColor).opacity(0.74)
    }
}

private extension LLMProviderKind {
    var settingsAccentColor: Color {
        switch self {
        case .openAI:
            Color(red: 0.16, green: 0.70, blue: 0.54)
        case .anthropic:
            Color(red: 0.80, green: 0.46, blue: 0.28)
        case .googleGemini:
            Color(red: 0.25, green: 0.52, blue: 0.96)
        case .openRouter:
            Color(red: 0.60, green: 0.47, blue: 0.93)
        case .groq:
            Color(red: 0.93, green: 0.29, blue: 0.20)
        case .mistral:
            Color(red: 0.93, green: 0.65, blue: 0.13)
        case .perplexity:
            Color(red: 0.11, green: 0.67, blue: 0.76)
        case .deepSeek:
            Color(red: 0.18, green: 0.45, blue: 0.86)
        case .xAI:
            Color(red: 0.34, green: 0.36, blue: 0.42)
        case .togetherAI:
            Color(red: 0.14, green: 0.63, blue: 0.37)
        case .customOpenAICompatible:
            Color(red: 0.48, green: 0.51, blue: 0.57)
        }
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

// MARK: - Display

struct DisplaySettingsPane: View {
    var model: AppModel

    private var lang: LanguageManager { model.lang }

    var body: some View {
        Form {
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
            }

            if let diag = model.overlayPlacementDiagnostics {
                Section(lang.t("settings.display.diagnostics")) {
                    LabeledContent(lang.t("settings.display.currentScreen"), value: diag.targetScreenName)
                    LabeledContent(lang.t("settings.display.layoutMode"), value: diag.modeDescription)
                }
            }

            Section(lang.t("settings.display.islandHeader")) {
                Picker(lang.t("settings.display.tokenUsageDisplay"), selection: Binding(
                    get: { model.islandTokenUsageDisplayMode },
                    set: { model.islandTokenUsageDisplayMode = $0 }
                )) {
                    ForEach(IslandTokenUsageDisplayMode.allCases) { mode in
                        Text(mode.displayName(lang)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(lang.t("settings.display.tokenUsageDisplay.help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(lang.t("settings.tab.display"))
    }
}

private extension IslandTokenUsageDisplayMode {
    func displayName(_ lang: LanguageManager) -> String {
        switch self {
        case .claude:
            lang.t("settings.display.tokenUsageDisplay.claude")
        case .codex:
            lang.t("settings.display.tokenUsageDisplay.codex")
        case .both:
            lang.t("settings.display.tokenUsageDisplay.both")
        }
    }
}

// MARK: - Sound

struct SoundSettingsPane: View {
    var model: AppModel

    private var lang: LanguageManager { model.lang }

    private var availableSounds: [String] {
        NotificationSoundService.availableSounds()
    }

    var body: some View {
        Form {
            Section(lang.t("settings.sound.notifications")) {
                Toggle(lang.t("settings.sound.mute"), isOn: Binding(
                    get: { model.isSoundMuted },
                    set: { _ in model.toggleSoundMuted() }
                ))
            }

            Section(lang.t("settings.sound.selectSound")) {
                List(availableSounds, id: \.self) { name in
                    Button {
                        model.selectedSoundName = name
                        NotificationSoundService.play(name)
                    } label: {
                        HStack {
                            Text(name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if name == model.selectedSoundName {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(lang.t("settings.tab.sound"))
    }
}

// MARK: - Setup

struct SetupSettingsPane: View {
    var model: AppModel

    @State private var confirmingUninstallClaude = false
    @State private var confirmingUninstallCodex = false
    @State private var confirmingUninstallOpenCode = false
    @State private var confirmingUninstallClaudeUsage = false

    private var lang: LanguageManager { model.lang }

    var body: some View {
        Form {
            if !model.hasAnyInstalledAgent {
                emptyStateBanner
            }

            claudeConfigDirectorySection

            Section(lang.t("setup.section.hooks")) {
                hookRow(
                    name: "Claude Code",
                    installed: model.claudeHooksInstalled,
                    busy: model.isClaudeHookSetupBusy,
                    configLocationURL: model.claudeHookStatus?.settingsURL,
                    installAction: { model.installClaudeHooks() },
                    uninstallAction: { confirmingUninstallClaude = true }
                )
                .alert(lang.t("settings.general.uninstallConfirmTitle"), isPresented: $confirmingUninstallClaude) {
                    Button(lang.t("settings.general.uninstallConfirmAction"), role: .destructive) {
                        model.uninstallClaudeHooks()
                    }
                    Button(lang.t("settings.general.cancel"), role: .cancel) {}
                } message: {
                    Text(lang.t("settings.general.uninstallConfirmMessage.claude"))
                }

                hookRow(
                    name: "Codex",
                    installed: model.codexHooksInstalled,
                    busy: model.isCodexSetupBusy,
                    configLocationURL: codexHookConfigURL,
                    installAction: { model.installCodexHooks() },
                    uninstallAction: { confirmingUninstallCodex = true }
                )
                .alert(lang.t("settings.general.uninstallConfirmTitle"), isPresented: $confirmingUninstallCodex) {
                    Button(lang.t("settings.general.uninstallConfirmAction"), role: .destructive) {
                        model.uninstallCodexHooks()
                    }
                    Button(lang.t("settings.general.cancel"), role: .cancel) {}
                } message: {
                    Text(lang.t("settings.general.uninstallConfirmMessage.codex"))
                }

                hookRow(
                    name: "OpenCode",
                    installed: model.openCodePluginInstalled,
                    busy: model.isOpenCodeSetupBusy,
                    requiresBinary: false,
                    configLocationURL: model.openCodePluginStatus?.configURL,
                    installAction: { model.installOpenCodePlugin() },
                    uninstallAction: { confirmingUninstallOpenCode = true }
                )
                .alert(lang.t("settings.general.uninstallConfirmTitle"), isPresented: $confirmingUninstallOpenCode) {
                    Button(lang.t("settings.general.uninstallConfirmAction"), role: .destructive) {
                        model.uninstallOpenCodePlugin()
                    }
                    Button(lang.t("settings.general.cancel"), role: .cancel) {}
                } message: {
                    Text("This will remove the Aisland plugin from ~/.config/opencode/plugins/.")
                }

            }

            Section {
                HStack {
                    Label(lang.t("setup.usageBridge"), systemImage: "chart.bar")
                    Spacer()
                    if model.claudeUsageInstalled {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(lang.t("setup.usageBridgeReady"))
                                .foregroundStyle(.secondary)
                        }
                        Button(lang.t("settings.general.uninstall")) {
                            confirmingUninstallClaudeUsage = true
                        }
                    } else if model.isClaudeUsageSetupBusy {
                        ProgressView().controlSize(.small)
                    } else {
                        Button(lang.t("settings.general.install")) {
                            model.installClaudeUsageBridge()
                        }
                    }
                }
                .alert(lang.t("settings.general.uninstallConfirmTitle"), isPresented: $confirmingUninstallClaudeUsage) {
                    Button(lang.t("settings.general.uninstallConfirmAction"), role: .destructive) {
                        model.uninstallClaudeUsageBridge()
                    }
                    Button(lang.t("settings.general.cancel"), role: .cancel) {}
                } message: {
                    Text(lang.t("settings.general.uninstallConfirmMessage.claudeUsage"))
                }

            } header: {
                HStack(spacing: 4) {
                    Text(lang.t("setup.section.usage"))
                    Text(lang.t("setup.optional"))
                        .foregroundStyle(.tertiary)
                }
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

            RemoteConnectionSection(model: model)

            Section {
                Button(lang.t("setup.installAll")) {
                    if !model.claudeHooksInstalled { model.installClaudeHooks() }
                    if !model.codexHooksInstalled { model.installCodexHooks() }
                    if !model.openCodePluginInstalled { model.installOpenCodePlugin() }
                    if !model.claudeUsageInstalled { model.installClaudeUsageBridge() }
                }
                .disabled(model.hooksBinaryURL == nil || allReady)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(lang.t("settings.tab.setup"))
    }

    @ViewBuilder
    private var claudeConfigDirectorySection: some View {
        Section {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.t("setup.claudeConfigDir.title"))
                        Text(ClaudeConfigDirectory.resolved().path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                } icon: {
                    Image(systemName: "folder")
                }
                Spacer()
                if ClaudeConfigDirectory.customDirectory != nil {
                    Button(lang.t("setup.claudeConfigDir.reset")) {
                        model.updateClaudeConfigDirectory(to: nil)
                    }
                    .font(.caption)
                }
                Button(lang.t("setup.claudeConfigDir.choose")) {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.canCreateDirectories = true
                    panel.showsHiddenFiles = true
                    panel.prompt = lang.t("setup.claudeConfigDir.choose")
                    if panel.runModal() == .OK, let url = panel.url {
                        model.updateClaudeConfigDirectory(to: url)
                    }
                }
            }
        } header: {
            HStack(spacing: 4) {
                Text(lang.t("setup.claudeConfigDir.section"))
                Text(lang.t("setup.optional"))
                    .foregroundStyle(.tertiary)
            }
        } footer: {
            Text(lang.t("setup.claudeConfigDir.footer"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var allReady: Bool {
        model.claudeHooksInstalled && model.codexHooksInstalled && model.openCodePluginInstalled && model.claudeUsageInstalled
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

    private var hasNotices: Bool {
        let claude = model.claudeHealthReport?.notices.isEmpty == false
        let codex = model.codexHealthReport?.notices.isEmpty == false
        let openCode = model.openCodeHealthReport?.notices.isEmpty == false
        return claude || codex || openCode
    }

    @ViewBuilder
    private var hookDiagnosticsSection: some View {
        Section {
            if let claudeReport = model.claudeHealthReport, !claudeReport.issues.isEmpty {
                issueList(report: claudeReport)
            }
            if let codexReport = model.codexHealthReport, !codexReport.issues.isEmpty {
                issueList(report: codexReport)
            }
            if let openCodeReport = model.openCodeHealthReport, !openCodeReport.issues.isEmpty {
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

            ForEach(Array(report.issues.enumerated()), id: \.offset) { _, issue in
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
    private func hookRow(
        name: String,
        installed: Bool,
        busy: Bool,
        requiresBinary: Bool = true,
        configLocationURL: URL? = nil,
        installAction: @escaping () -> Void,
        uninstallAction: @escaping () -> Void
    ) -> some View {
        HStack {
            Label(name, systemImage: "terminal")
            Spacer()
            if installed {
                HStack(spacing: 8) {
                    if let configLocationURL {
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
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(lang.t("settings.general.activated"))
                            .foregroundStyle(.secondary)
                    }
                    Button(lang.t("settings.general.uninstall")) {
                        uninstallAction()
                    }
                    .foregroundStyle(.red)
                    .font(.caption)
                }
            } else if busy {
                ProgressView().controlSize(.small)
            } else {
                Button(lang.t("settings.general.install")) {
                    installAction()
                }
                .disabled(requiresBinary && model.hooksBinaryURL == nil)
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

// MARK: - Remote Connection

struct RemoteConnectionSection: View {
    var model: AppModel

    @State private var copiedCommand: String?
    @State private var isExpanded = false

    private var remoteSessionCount: Int {
        model.state.sessions.filter(\.isRemote).count
    }

    private var socketName: String {
        "aisland-\(getuid()).sock"
    }

    private var setupCommand: String {
        "./scripts/remote-setup.sh user@host"
    }

    private var sshCommand: String {
        "ssh -R /tmp/\(socketName):/tmp/\(socketName) user@host"
    }

    private var sshConfigSnippet: String {
        """
        Host myserver
            RemoteForward /tmp/\(socketName) /tmp/\(socketName)
        """
    }

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Monitor Claude Code running on remote servers via SSH.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    remoteSetupStep(
                        number: "1",
                        title: "Deploy hooks to remote server",
                        description: "Run from the Aisland repo directory:",
                        command: setupCommand
                    )

                    remoteSetupStep(
                        number: "2",
                        title: "Connect with socket forwarding",
                        description: "Add to ~/.ssh/config (recommended):",
                        command: sshConfigSnippet,
                        multiline: true
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Or connect directly:")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                        copyableCommand(sshCommand)
                    }

                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue.opacity(0.8))
                            .padding(.top, 1)
                        Text("The remote sshd needs `StreamLocalBindUnlink yes` in /etc/ssh/sshd_config for reliable reconnects.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Label("Remote sessions: \(remoteSessionCount)", systemImage: "network")
                    Spacer()
                    Text("Beta")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func remoteSetupStep(
        number: String,
        title: String,
        description: String,
        command: String,
        multiline: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(number)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(.blue.opacity(0.7)))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            Text(description)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            copyableCommand(command, multiline: multiline)
        }
    }

    @ViewBuilder
    private func copyableCommand(_ command: String, multiline: Bool = false) -> some View {
        let isCopied = copiedCommand == command
        GroupBox {
            HStack(alignment: multiline ? .top : .center) {
                Text(command)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(multiline ? nil : 1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Spacer(minLength: 8)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    copiedCommand = command
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if copiedCommand == command {
                            copiedCommand = nil
                        }
                    }
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(isCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, multiline ? 2 : 0)
        }
    }
}

// MARK: - Update Banner

struct UpdateBanner: View {
    let version: String
    let lang: LanguageManager
    var onUpdate: () -> Void

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
                    .fill(Color.blue)
            )
        }
        .buttonStyle(.plain)
        .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)
    }
}
