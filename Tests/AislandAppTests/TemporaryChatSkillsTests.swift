import Foundation
import AISDKProviderUtils
import Testing
@testable import AislandApp

struct TemporaryChatSkillsTests {
    @Test
    func skillInstallManagerImportsSingleSkillMarkdownFile() throws {
        let rootURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let sourceURL = rootURL.appendingPathComponent("source", isDirectory: true)
        let installURL = rootURL.appendingPathComponent("AislandSkills", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        let skillFileURL = sourceURL.appendingPathComponent("SKILL.md")
        try """
        ---
        name: Code Review
        description: Review workflow.
        ---
        # Code Review

        Prioritize findings first.
        """.write(to: skillFileURL, atomically: true, encoding: .utf8)

        let installed = try TemporaryChatSkillInstallManager(installDirectoryURL: installURL)
            .importSkill(from: skillFileURL)

        #expect(installed.id == "code-review")
        #expect(installed.fileURL == installURL.appendingPathComponent("code-review/SKILL.md"))
        #expect(FileManager.default.fileExists(atPath: installed.fileURL.path))
    }

    @Test
    func skillInstallManagerImportsFolderContainingSkillMarkdown() throws {
        let rootURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let sourceURL = rootURL.appendingPathComponent("planner", isDirectory: true)
        let installURL = rootURL.appendingPathComponent("AislandSkills", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try """
        # Planning

        Keep changes incremental and reviewable.
        """.write(to: sourceURL.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try "reference".write(to: sourceURL.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let installed = try TemporaryChatSkillInstallManager(installDirectoryURL: installURL)
            .importSkill(from: sourceURL)

        #expect(installed.id == "planner")
        #expect(FileManager.default.fileExists(atPath: installURL.appendingPathComponent("planner/SKILL.md").path))
        #expect(FileManager.default.fileExists(atPath: installURL.appendingPathComponent("planner/notes.txt").path))
    }

    @Test
    func skillInstallManagerRejectsDuplicateManagedSkill() throws {
        let rootURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let sourceURL = rootURL.appendingPathComponent("source", isDirectory: true)
        let installURL = rootURL.appendingPathComponent("AislandSkills", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        let skillFileURL = sourceURL.appendingPathComponent("SKILL.md")
        try """
        ---
        name: Figma
        ---
        # Figma

        Use screenshots and variables.
        """.write(to: skillFileURL, atomically: true, encoding: .utf8)
        let manager = TemporaryChatSkillInstallManager(installDirectoryURL: installURL)

        _ = try manager.importSkill(from: skillFileURL)
        do {
            _ = try manager.importSkill(from: skillFileURL)
            Issue.record("Expected duplicate import to throw")
        } catch let error as TemporaryChatSkillInstallError {
            #expect(error == .skillAlreadyExists("figma"))
        }
    }

    @Test
    func skillInstallManagerOnlyUninstallsManagedSkillDirectories() throws {
        let rootURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let installURL = rootURL.appendingPathComponent("AislandSkills", isDirectory: true)
        let managedURL = installURL.appendingPathComponent("managed", isDirectory: true)
        let externalURL = rootURL.appendingPathComponent("external", isDirectory: true)
        try FileManager.default.createDirectory(at: managedURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: externalURL, withIntermediateDirectories: true)
        let manager = TemporaryChatSkillInstallManager(installDirectoryURL: installURL)

        try manager.uninstallSkill(at: managedURL)
        #expect(!FileManager.default.fileExists(atPath: managedURL.path))

        do {
            try manager.uninstallSkill(at: externalURL)
            Issue.record("Expected unmanaged uninstall to throw")
        } catch let error as TemporaryChatSkillInstallError {
            if case .unmanagedSkill = error {
                #expect(true)
            } else {
                Issue.record("Expected unmanagedSkill error")
            }
        }
        #expect(FileManager.default.fileExists(atPath: externalURL.path))
    }

    @Test
    func skillDiscoveryUsesRepositoryProjectUserPriority() throws {
        let rootURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let repositoryURL = rootURL.appendingPathComponent("repo", isDirectory: true)
        let projectURL = rootURL.appendingPathComponent("project", isDirectory: true)
        let userURL = rootURL.appendingPathComponent("home", isDirectory: true)

        try writeSkill(
            """
            ---
            name: Figma
            description: Repository design implementation workflow.
            tags: [figma, design]
            ---
            # Repository Figma

            Follow repository Figma conventions.
            """,
            id: "figma",
            under: repositoryURL
        )
        try writeSkill(
            """
            ---
            name: Figma
            description: User fallback Figma workflow.
            ---
            # User Figma

            Follow user Figma conventions.
            """,
            id: "figma",
            under: userURL
        )
        try writeSkill(
            """
            ---
            name: Obsidian
            description: Project note workflow.
            ---
            # Obsidian

            Use wikilinks and properties.
            """,
            id: "obsidian",
            under: projectURL
        )

        let skills = TemporaryChatSkillDiscovery(roots: [
            TemporaryChatSkillRoot(source: .user, url: userURL),
            TemporaryChatSkillRoot(source: .project, url: projectURL),
            TemporaryChatSkillRoot(source: .repository, url: repositoryURL),
        ]).discover()

        #expect(skills.map(\.id).sorted() == ["figma", "obsidian"])
        let figma = try #require(skills.first { $0.id == "figma" })
        #expect(figma.source == .repository)
        #expect(figma.title == "Figma")
        #expect(figma.summary == "Repository design implementation workflow.")
        #expect(figma.tags.contains("figma"))
    }

    @Test
    func skillDiscoveryScansAislandSkillsDirectoryAndMarksOverriddenManagedSkill() throws {
        let rootURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let repositoryURL = rootURL.appendingPathComponent("repo", isDirectory: true)
        let aislandSkillsURL = rootURL.appendingPathComponent("Aisland/Skills", isDirectory: true)

        try writeSkill(
            """
            ---
            name: Figma
            description: Repository workflow.
            ---
            # Figma

            Follow repository workflow.
            """,
            id: "figma",
            under: repositoryURL
        )
        try writeDirectSkill(
            """
            ---
            name: Figma
            description: User managed workflow.
            ---
            # Figma

            Follow user workflow.
            """,
            id: "figma",
            underSkillsDirectory: aislandSkillsURL
        )

        let discovery = TemporaryChatSkillDiscovery(roots: [
            TemporaryChatSkillRoot(source: .user, url: aislandSkillsURL),
            TemporaryChatSkillRoot(source: .repository, url: repositoryURL),
        ])

        let active = discovery.discover()
        #expect(active.count == 1)
        #expect(active.first?.source == .repository)

        let installed = discovery.installedSkills(managedDirectoryURL: aislandSkillsURL)
        let managed = try #require(installed.first { $0.isAislandManaged })
        #expect(managed.definition.source == .user)
        #expect(managed.isOverridden)
        #expect(managed.activeDefinition?.source == .repository)
    }

    @Test
    func settingsTabPlacesSkillsUnderAIChatSection() {
        #expect(SettingsTab.skills.section == .aiChat)
    }

    @Test
    func skillContextSelectsRelevantMarkdownAsSystemGuidance() {
        let skills = [
            TemporaryChatSkillDefinition(
                id: "figma",
                title: "Figma",
                summary: "Design implementation workflow.",
                body: "Use node metadata, screenshots, and variables before coding.",
                source: .repository,
                fileURL: URL(fileURLWithPath: "/repo/.codex/skills/figma/SKILL.md")
            ),
            TemporaryChatSkillDefinition(
                id: "spreadsheet",
                title: "Spreadsheet",
                summary: "Excel workbook workflow.",
                body: "Use formulas and recalculation checks.",
                source: .user,
                fileURL: URL(fileURLWithPath: "/home/.codex/skills/spreadsheet/SKILL.md")
            ),
        ]
        let messages = [
            TemporaryChatMessage(role: .user, content: "Implement this Figma node in the app."),
        ]

        let context = TemporaryChatSkillContextBuilder().context(from: skills, messages: messages)

        #expect(context.selectedSkills.map(\.id) == ["figma"])
        #expect(context.systemPrompt.contains("Aisland selected the following local read-only Skills"))
        #expect(context.systemPrompt.contains("Use node metadata, screenshots, and variables before coding."))
        #expect(!context.systemPrompt.contains("Use formulas and recalculation checks."))
        #expect(context.displaySummary == "Using Skills: Figma (Repository)")
    }

    @Test
    func temporaryChatClientPrependsSelectedSkillsAsSystemMessage() {
        let skillContext = TemporaryChatSkillContext(
            selectedSkills: [
                TemporaryChatSkillDefinition(
                    id: "code-review",
                    title: "Code Review",
                    summary: "Review workflow.",
                    body: "Prioritize findings first.",
                    source: .user,
                    fileURL: URL(fileURLWithPath: "/home/.codex/skills/code-review/SKILL.md")
                ),
            ],
            systemPrompt: "Use the code review Skill."
        )
        let client = TemporaryChatClient(skillContextProvider: .disabled)

        let modelMessages = client.preparedModelMessages(
            messages: [TemporaryChatMessage(role: .user, content: "Review this diff.")],
            skillContext: skillContext
        )

        #expect(modelMessages.count == 2)
        guard case let .system(systemMessage)? = modelMessages.first else {
            Issue.record("Expected a system message containing selected Skills")
            return
        }
        #expect(systemMessage.content == "Use the code review Skill.")
        guard case .user = modelMessages[1] else {
            Issue.record("Expected original user message after system Skill context")
            return
        }
    }
}

private func writeSkill(_ content: String, id: String, under rootURL: URL) throws {
    let skillURL = rootURL
        .appendingPathComponent(".codex/skills", isDirectory: true)
        .appendingPathComponent(id, isDirectory: true)
    try FileManager.default.createDirectory(at: skillURL, withIntermediateDirectories: true)
    try content.write(
        to: skillURL.appendingPathComponent("SKILL.md"),
        atomically: true,
        encoding: .utf8
    )
}

private func writeDirectSkill(_ content: String, id: String, underSkillsDirectory rootURL: URL) throws {
    let skillURL = rootURL.appendingPathComponent(id, isDirectory: true)
    try FileManager.default.createDirectory(at: skillURL, withIntermediateDirectories: true)
    try content.write(
        to: skillURL.appendingPathComponent("SKILL.md"),
        atomically: true,
        encoding: .utf8
    )
}

private func temporaryDirectoryURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("aisland-skills-\(UUID().uuidString)", isDirectory: true)
}
