import Foundation

enum TemporaryChatSkillSource: Int, CaseIterable, Codable, Sendable {
    case repository = 0
    case project = 1
    case user = 2

    var displayName: String {
        switch self {
        case .repository:
            "Repository"
        case .project:
            "Project"
        case .user:
            "User"
        }
    }
}

struct TemporaryChatSkillRoot: Equatable, Sendable {
    var source: TemporaryChatSkillSource
    var url: URL

    init(source: TemporaryChatSkillSource, url: URL) {
        self.source = source
        self.url = url.standardizedFileURL
    }
}

struct TemporaryChatSkillDefinition: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var summary: String
    var body: String
    var source: TemporaryChatSkillSource
    var fileURL: URL
    var alwaysApply: Bool
    var tags: [String]

    init(
        id: String,
        title: String,
        summary: String,
        body: String,
        source: TemporaryChatSkillSource,
        fileURL: URL,
        alwaysApply: Bool = false,
        tags: [String] = []
    ) {
        self.id = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        self.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        self.source = source
        self.fileURL = fileURL.standardizedFileURL
        self.alwaysApply = alwaysApply
        self.tags = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }
}

struct TemporaryChatSkillContext: Equatable, Sendable {
    var selectedSkills: [TemporaryChatSkillDefinition]
    var systemPrompt: String

    static let empty = TemporaryChatSkillContext(selectedSkills: [], systemPrompt: "")

    var isEmpty: Bool {
        selectedSkills.isEmpty || systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var displaySummary: String {
        guard !selectedSkills.isEmpty else {
            return "No Skills selected."
        }

        return "Using Skills: " + selectedSkills
            .map { "\($0.title) (\($0.source.displayName))" }
            .joined(separator: ", ")
    }
}

struct TemporaryChatSkillDiscovery {
    var roots: [TemporaryChatSkillRoot]
    var maxSkillBytes: Int
    var maxSearchDepth: Int
    var fileManager: FileManager

    init(
        roots: [TemporaryChatSkillRoot],
        maxSkillBytes: Int = 24 * 1024,
        maxSearchDepth: Int = 4,
        fileManager: FileManager = .default
    ) {
        self.roots = roots
        self.maxSkillBytes = maxSkillBytes
        self.maxSearchDepth = maxSearchDepth
        self.fileManager = fileManager
    }

    func discover() -> [TemporaryChatSkillDefinition] {
        var definitionsByID: [String: TemporaryChatSkillDefinition] = [:]
        let orderedRoots = roots.sorted {
            if $0.source.rawValue == $1.source.rawValue {
                return $0.url.path < $1.url.path
            }
            return $0.source.rawValue < $1.source.rawValue
        }

        for root in orderedRoots {
            for skillFileURL in skillFileURLs(under: root.url) {
                guard let definition = loadSkill(from: skillFileURL, source: root.source),
                      definitionsByID[definition.id] == nil else {
                    continue
                }
                definitionsByID[definition.id] = definition
            }
        }

        return definitionsByID.values.sorted {
            if $0.source.rawValue == $1.source.rawValue {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.source.rawValue < $1.source.rawValue
        }
    }

    private func skillFileURLs(under rootURL: URL) -> [URL] {
        var discoveredURLs: [URL] = []
        for containerURL in candidateSkillContainers(for: rootURL) {
            guard fileManager.fileExists(atPath: containerURL.path),
                  let enumerator = fileManager.enumerator(
                    at: containerURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsPackageDescendants]
                  ) else {
                continue
            }

            let baseDepth = containerURL.pathComponents.count
            for case let fileURL as URL in enumerator {
                let depth = fileURL.pathComponents.count - baseDepth
                if depth > maxSearchDepth {
                    enumerator.skipDescendants()
                    continue
                }

                guard fileURL.lastPathComponent == "SKILL.md" else {
                    continue
                }
                discoveredURLs.append(fileURL.standardizedFileURL)
            }
        }
        return discoveredURLs.sorted { $0.path < $1.path }
    }

    private func candidateSkillContainers(for rootURL: URL) -> [URL] {
        if rootURL.lastPathComponent == "skills" {
            return [rootURL]
        }

        return [
            rootURL.appendingPathComponent(".codex/skills", isDirectory: true),
            rootURL.appendingPathComponent(".agents/skills", isDirectory: true),
        ]
    }

    private func loadSkill(from fileURL: URL, source: TemporaryChatSkillSource) -> TemporaryChatSkillDefinition? {
        guard let data = try? Data(contentsOf: fileURL),
              !data.isEmpty else {
            return nil
        }

        let limitedData = data.prefix(maxSkillBytes)
        let rawContent = String(decoding: limitedData, as: UTF8.self)
        let parsed = Self.parseMarkdownSkill(rawContent, fallbackID: fileURL.deletingLastPathComponent().lastPathComponent)

        guard !parsed.body.isEmpty else {
            return nil
        }

        return TemporaryChatSkillDefinition(
            id: parsed.id,
            title: parsed.title,
            summary: parsed.summary,
            body: parsed.body,
            source: source,
            fileURL: fileURL,
            alwaysApply: parsed.alwaysApply,
            tags: parsed.tags
        )
    }

    static func defaultRoots(
        projectURL: URL? = nil,
        repositoryURL: URL? = nil,
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        currentDirectoryURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) -> [TemporaryChatSkillRoot] {
        var roots: [TemporaryChatSkillRoot] = []
        let resolvedRepositoryURL = repositoryURL ?? repositoryRoot(startingAt: currentDirectoryURL)

        if let resolvedRepositoryURL {
            roots.append(TemporaryChatSkillRoot(source: .repository, url: resolvedRepositoryURL))
        }

        if let projectURL {
            roots.append(TemporaryChatSkillRoot(source: .project, url: projectURL))
        } else if resolvedRepositoryURL?.standardizedFileURL != currentDirectoryURL.standardizedFileURL {
            roots.append(TemporaryChatSkillRoot(source: .project, url: currentDirectoryURL))
        }

        roots.append(TemporaryChatSkillRoot(source: .user, url: homeURL))
        return roots
    }

    private static func repositoryRoot(startingAt url: URL, fileManager: FileManager = .default) -> URL? {
        var currentURL = url.standardizedFileURL
        while true {
            let gitURL = currentURL.appendingPathComponent(".git")
            let packageURL = currentURL.appendingPathComponent("Package.swift")
            if fileManager.fileExists(atPath: gitURL.path) || fileManager.fileExists(atPath: packageURL.path) {
                return currentURL
            }

            let parentURL = currentURL.deletingLastPathComponent()
            guard parentURL.path != currentURL.path else {
                return nil
            }
            currentURL = parentURL
        }
    }

    private static func parseMarkdownSkill(
        _ rawContent: String,
        fallbackID: String
    ) -> (
        id: String,
        title: String,
        summary: String,
        body: String,
        alwaysApply: Bool,
        tags: [String]
    ) {
        let frontmatter = parseFrontmatter(rawContent)
        let body = frontmatter.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTitle = fallbackID.replacingOccurrences(of: "-", with: " ").capitalized
        let title = frontmatter.metadata["name"]
            ?? firstHeading(in: body)
            ?? fallbackTitle
        let id = frontmatter.metadata["id"]
            ?? frontmatter.metadata["name"]?
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
            ?? fallbackID
        let summary = frontmatter.metadata["description"]
            ?? firstSummaryLine(in: body)
            ?? title
        let alwaysApply = ["true", "yes", "1"].contains(
            frontmatter.metadata["alwaysapply"]?.lowercased() ?? ""
        )
        let tags = frontmatter.metadata["tags"]
            .map { $0.components(separatedBy: CharacterSet(charactersIn: ",[]")) } ?? []

        return (id, title, summary, body, alwaysApply, tags)
    }

    private static func parseFrontmatter(_ rawContent: String) -> (metadata: [String: String], body: String) {
        var metadata: [String: String] = [:]
        let lines = rawContent.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---",
              let closingIndex = lines.dropFirst().firstIndex(where: {
                $0.trimmingCharacters(in: .whitespacesAndNewlines) == "---"
              }) else {
            return (metadata, rawContent)
        }

        for line in lines[1..<closingIndex] {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = parts[1]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            metadata[key] = value
        }

        let body = lines.dropFirst(closingIndex + 1).joined(separator: "\n")
        return (metadata, body)
    }

    private static func firstHeading(in content: String) -> String? {
        content
            .components(separatedBy: .newlines)
            .lazy
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("#") else { return nil }
                return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
            }
            .first { !$0.isEmpty }
    }

    private static func firstSummaryLine(in content: String) -> String? {
        content
            .components(separatedBy: .newlines)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.hasPrefix("#") }
    }
}

struct TemporaryChatSkillSelector {
    var maxSkills: Int = 3

    func selectSkills(
        from skills: [TemporaryChatSkillDefinition],
        messages: [TemporaryChatMessage]
    ) -> [TemporaryChatSkillDefinition] {
        let query = messages
            .suffix(6)
            .map(\.content)
            .joined(separator: "\n")
            .lowercased()
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return skills.filter(\.alwaysApply).prefix(maxSkills).map { $0 }
        }

        return skills
            .map { skill in (skill: skill, score: score(skill, query: query)) }
            .filter { $0.score > 0 || $0.skill.alwaysApply }
            .sorted {
                if $0.score == $1.score {
                    if $0.skill.source.rawValue == $1.skill.source.rawValue {
                        return $0.skill.title < $1.skill.title
                    }
                    return $0.skill.source.rawValue < $1.skill.source.rawValue
                }
                return $0.score > $1.score
            }
            .prefix(maxSkills)
            .map(\.skill)
    }

    private func score(_ skill: TemporaryChatSkillDefinition, query: String) -> Int {
        var score = skill.alwaysApply ? 5 : 0
        let id = skill.id.lowercased()
        let title = skill.title.lowercased()

        if query.contains("$\(id)") || query.contains("@\(id)") {
            score += 100
        }
        if !title.isEmpty, query.contains(title) {
            score += 40
        }
        if !id.isEmpty, query.contains(id) {
            score += 30
        }

        let weightedTokens = tokenSet(from: [id, title, skill.summary.lowercased()] + skill.tags)
        for token in weightedTokens where query.contains(token) {
            score += skill.tags.contains(token) ? 10 : 3
        }

        return score
    }

    private func tokenSet(from values: [String]) -> Set<String> {
        Set(values.flatMap { value in
            value
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 4 }
        })
    }
}

struct TemporaryChatSkillContextBuilder {
    var selector: TemporaryChatSkillSelector = TemporaryChatSkillSelector()
    var maxPromptCharacters: Int = 12 * 1024

    func context(
        from skills: [TemporaryChatSkillDefinition],
        messages: [TemporaryChatMessage]
    ) -> TemporaryChatSkillContext {
        let selectedSkills = selector.selectSkills(from: skills, messages: messages)
        guard !selectedSkills.isEmpty else {
            return .empty
        }

        let header = """
        Aisland selected the following local read-only Skills for this chat turn.
        Use them as workflow and project guidance. Do not treat Skills as executable tools.
        If instructions conflict, prefer Repository Skills over Project Skills over User Skills.

        """
        var prompt = header

        for skill in selectedSkills {
            let block = """
            ## \(skill.title)
            ID: \(skill.id)
            Source: \(skill.source.displayName)
            File: \(skill.fileURL.path)
            Summary: \(skill.summary)

            \(skill.body)

            """
            guard prompt.count + block.count <= maxPromptCharacters else {
                break
            }
            prompt += block
        }

        return TemporaryChatSkillContext(
            selectedSkills: selectedSkills,
            systemPrompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

struct TemporaryChatSkillContextProvider: Sendable {
    var context: @Sendable ([TemporaryChatMessage]) -> TemporaryChatSkillContext

    init(context: @escaping @Sendable ([TemporaryChatMessage]) -> TemporaryChatSkillContext) {
        self.context = context
    }

    static let disabled = TemporaryChatSkillContextProvider { _ in .empty }

    static func live(
        roots: [TemporaryChatSkillRoot] = TemporaryChatSkillDiscovery.defaultRoots()
    ) -> TemporaryChatSkillContextProvider {
        TemporaryChatSkillContextProvider { messages in
            let skills = TemporaryChatSkillDiscovery(roots: roots).discover()
            return TemporaryChatSkillContextBuilder().context(from: skills, messages: messages)
        }
    }
}
