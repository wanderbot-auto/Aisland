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
        self.id = Self.canonicalID(from: id)
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

    static func canonicalID(from rawID: String) -> String {
        let trimmed = rawID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let tokens = trimmed
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return tokens.isEmpty ? "skill" : tokens.joined(separator: "-")
    }
}

struct TemporaryChatInstalledSkill: Identifiable, Equatable, Sendable {
    var definition: TemporaryChatSkillDefinition
    var isAislandManaged: Bool
    var isActive: Bool
    var activeDefinition: TemporaryChatSkillDefinition?

    var id: String {
        definition.id + "::" + definition.fileURL.path
    }

    var isOverridden: Bool {
        !isActive && activeDefinition != nil
    }

    var installDirectoryURL: URL {
        definition.fileURL.deletingLastPathComponent()
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
        activeDefinitions(from: discoverAll())
    }

    func discoverAll() -> [TemporaryChatSkillDefinition] {
        var definitions: [TemporaryChatSkillDefinition] = []
        let orderedRoots = roots.sorted {
            if $0.source.rawValue == $1.source.rawValue {
                return $0.url.path < $1.url.path
            }
            return $0.source.rawValue < $1.source.rawValue
        }

        for root in orderedRoots {
            for skillFileURL in skillFileURLs(under: root.url) {
                guard let definition = loadSkill(from: skillFileURL, source: root.source) else {
                    continue
                }
                definitions.append(definition)
            }
        }

        return definitions.sorted {
            if $0.source.rawValue == $1.source.rawValue {
                if $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedSame {
                    return $0.fileURL.path < $1.fileURL.path
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.source.rawValue < $1.source.rawValue
        }
    }

    func installedSkills(
        managedDirectoryURL: URL = TemporaryChatSkillInstallManager.defaultInstallDirectoryURL
    ) -> [TemporaryChatInstalledSkill] {
        let allDefinitions = discoverAll()
        let activeByID = Dictionary(uniqueKeysWithValues: activeDefinitions(from: allDefinitions).map { ($0.id, $0) })
        return allDefinitions.map { definition in
            let activeDefinition = activeByID[definition.id]
            return TemporaryChatInstalledSkill(
                definition: definition,
                isAislandManaged: Self.isSkill(definition, inside: managedDirectoryURL),
                isActive: activeDefinition?.fileURL == definition.fileURL,
                activeDefinition: activeDefinition
            )
        }
    }

    private func activeDefinitions(from definitions: [TemporaryChatSkillDefinition]) -> [TemporaryChatSkillDefinition] {
        var definitionsByID: [String: TemporaryChatSkillDefinition] = [:]

        let orderedDefinitions = definitions.sorted {
            if $0.source.rawValue == $1.source.rawValue {
                return $0.fileURL.path < $1.fileURL.path
            }
            return $0.source.rawValue < $1.source.rawValue
        }

        for definition in orderedDefinitions where definitionsByID[definition.id] == nil {
            definitionsByID[definition.id] = definition
        }

        return definitionsByID.values.sorted {
            if $0.source.rawValue == $1.source.rawValue {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.source.rawValue < $1.source.rawValue
        }
    }

    static func isSkill(_ skill: TemporaryChatSkillDefinition, inside directoryURL: URL) -> Bool {
        isURL(skill.fileURL, inside: directoryURL)
    }

    static func isURL(_ url: URL, inside directoryURL: URL) -> Bool {
        let childPath = url.standardizedFileURL.path
        let parentPath = directoryURL.standardizedFileURL.path
        return childPath == parentPath || childPath.hasPrefix(parentPath + "/")
    }

    static func skillFileURL(forImportURL url: URL, fileManager: FileManager = .default) -> URL? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }

        if isDirectory.boolValue {
            let skillURL = url.appendingPathComponent("SKILL.md")
            return fileManager.fileExists(atPath: skillURL.path) ? skillURL : nil
        }

        return url.lastPathComponent == "SKILL.md" ? url : nil
    }

    static func loadSkillDefinition(
        from fileURL: URL,
        source: TemporaryChatSkillSource = .user,
        maxSkillBytes: Int = 24 * 1024
    ) -> TemporaryChatSkillDefinition? {
        guard let data = try? Data(contentsOf: fileURL),
              !data.isEmpty else {
            return nil
        }

        let limitedData = data.prefix(maxSkillBytes)
        let rawContent = String(decoding: limitedData, as: UTF8.self)
        let parsed = parseMarkdownSkill(rawContent, fallbackID: fileURL.deletingLastPathComponent().lastPathComponent)

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

    private func loadSkill(from fileURL: URL, source: TemporaryChatSkillSource) -> TemporaryChatSkillDefinition? {
        Self.loadSkillDefinition(from: fileURL, source: source, maxSkillBytes: maxSkillBytes)
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
        if rootURL.lastPathComponent.lowercased() == "skills" {
            return [rootURL]
        }

        return [
            rootURL.appendingPathComponent(".codex/skills", isDirectory: true),
            rootURL.appendingPathComponent(".agents/skills", isDirectory: true),
        ]
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

        roots.append(TemporaryChatSkillRoot(source: .user, url: TemporaryChatSkillInstallManager.defaultInstallDirectoryURL))
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

    static func parseMarkdownSkill(
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

enum TemporaryChatSkillInstallError: LocalizedError, Equatable {
    case missingSkillMarkdown
    case invalidSkillMarkdown
    case skillAlreadyExists(String)
    case unmanagedSkill(URL)

    var errorDescription: String? {
        switch self {
        case .missingSkillMarkdown:
            "Choose a SKILL.md file or a folder that contains SKILL.md."
        case .invalidSkillMarkdown:
            "The selected SKILL.md does not contain readable Skill instructions."
        case let .skillAlreadyExists(id):
            "A Skill named \"\(id)\" is already installed by Aisland."
        case .unmanagedSkill:
            "Aisland can only uninstall Skills from its managed Skills directory."
        }
    }
}

struct TemporaryChatSkillInstallManager {
    static let defaultInstallDirectoryURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first!
        .appendingPathComponent("Aisland", isDirectory: true)
        .appendingPathComponent("Skills", isDirectory: true)

    var installDirectoryURL: URL
    var fileManager: FileManager

    init(
        installDirectoryURL: URL = Self.defaultInstallDirectoryURL,
        fileManager: FileManager = .default
    ) {
        self.installDirectoryURL = installDirectoryURL.standardizedFileURL
        self.fileManager = fileManager
    }

    @discardableResult
    func importSkill(from sourceURL: URL) throws -> TemporaryChatSkillDefinition {
        guard let skillFileURL = TemporaryChatSkillDiscovery.skillFileURL(
            forImportURL: sourceURL,
            fileManager: fileManager
        ) else {
            throw TemporaryChatSkillInstallError.missingSkillMarkdown
        }

        guard let definition = TemporaryChatSkillDiscovery.loadSkillDefinition(from: skillFileURL) else {
            throw TemporaryChatSkillInstallError.invalidSkillMarkdown
        }

        let destinationDirectoryURL = installDirectoryURL.appendingPathComponent(definition.id, isDirectory: true)
        guard !fileManager.fileExists(atPath: destinationDirectoryURL.path) else {
            throw TemporaryChatSkillInstallError.skillAlreadyExists(definition.id)
        }

        try fileManager.createDirectory(at: installDirectoryURL, withIntermediateDirectories: true)

        var isDirectory: ObjCBool = false
        _ = fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory)
        if isDirectory.boolValue {
            try fileManager.copyItem(at: sourceURL, to: destinationDirectoryURL)
        } else {
            try fileManager.createDirectory(at: destinationDirectoryURL, withIntermediateDirectories: true)
            try fileManager.copyItem(
                at: skillFileURL,
                to: destinationDirectoryURL.appendingPathComponent("SKILL.md")
            )
        }

        let installedSkillURL = destinationDirectoryURL.appendingPathComponent("SKILL.md")
        return TemporaryChatSkillDiscovery.loadSkillDefinition(from: installedSkillURL) ?? TemporaryChatSkillDefinition(
            id: definition.id,
            title: definition.title,
            summary: definition.summary,
            body: definition.body,
            source: .user,
            fileURL: installedSkillURL,
            alwaysApply: definition.alwaysApply,
            tags: definition.tags
        )
    }

    func uninstallSkill(_ skill: TemporaryChatInstalledSkill) throws {
        try uninstallSkill(at: skill.installDirectoryURL)
    }

    func uninstallSkill(at skillDirectoryURL: URL) throws {
        let standardizedURL = skillDirectoryURL.standardizedFileURL
        guard TemporaryChatSkillDiscovery.isURL(standardizedURL, inside: installDirectoryURL),
              standardizedURL.deletingLastPathComponent().standardizedFileURL == installDirectoryURL else {
            throw TemporaryChatSkillInstallError.unmanagedSkill(standardizedURL)
        }

        if fileManager.fileExists(atPath: standardizedURL.path) {
            try fileManager.removeItem(at: standardizedURL)
        }
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
