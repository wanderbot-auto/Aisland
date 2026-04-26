import Foundation
import AISDKProviderUtils
import Testing
@testable import AislandApp

struct TemporaryChatSkillsTests {
    @Test
    func skillDiscoveryUsesRepositoryProjectUserPriority() throws {
        let rootURL = temporaryDirectoryURL()
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

private func temporaryDirectoryURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("aisland-skills-\(UUID().uuidString)", isDirectory: true)
}
