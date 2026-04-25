import Foundation

public struct ClaudeTrackedSessionRecord: Equatable, Codable, Sendable {
    public var sessionID: String
    public var title: String
    public var summary: String
    public var phase: SessionPhase
    public var updatedAt: Date
    public var jumpTarget: JumpTarget?
    public var claudeMetadata: ClaudeSessionMetadata?

    public init(
        sessionID: String,
        title: String,
        summary: String,
        phase: SessionPhase,
        updatedAt: Date,
        jumpTarget: JumpTarget? = nil,
        claudeMetadata: ClaudeSessionMetadata? = nil
    ) {
        self.sessionID = sessionID
        self.title = title
        self.summary = summary
        self.phase = phase
        self.updatedAt = updatedAt
        self.jumpTarget = jumpTarget
        self.claudeMetadata = claudeMetadata
    }

    public init(session: AgentSession) {
        self.init(
            sessionID: session.id,
            title: session.title,
            summary: session.summary,
            phase: session.phase,
            updatedAt: session.updatedAt,
            jumpTarget: session.jumpTarget,
            claudeMetadata: session.claudeMetadata
        )
    }

    public var session: AgentSession {
        AgentSession(
            id: sessionID,
            title: title,
            tool: .claudeCode,
            phase: phase,
            summary: summary,
            updatedAt: updatedAt,
            jumpTarget: jumpTarget,
            claudeMetadata: claudeMetadata
        )
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID
        case title
        case summary
        case phase
        case updatedAt
        case jumpTarget
        case claudeMetadata
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(String.self, forKey: .sessionID)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        phase = try container.decode(SessionPhase.self, forKey: .phase)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        jumpTarget = try container.decodeIfPresent(JumpTarget.self, forKey: .jumpTarget)
        claudeMetadata = try container.decodeIfPresent(ClaudeSessionMetadata.self, forKey: .claudeMetadata)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(title, forKey: .title)
        try container.encode(summary, forKey: .summary)
        try container.encode(phase, forKey: .phase)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(jumpTarget, forKey: .jumpTarget)
        try container.encodeIfPresent(claudeMetadata, forKey: .claudeMetadata)
    }
}

public extension ClaudeTrackedSessionRecord {
    var restorableSession: AgentSession {
        session
    }

    var shouldRestoreToLiveState: Bool {
        true
    }
}

public final class ClaudeSessionRegistry: @unchecked Sendable {
    public let fileURL: URL
    private let fileManager: FileManager

    public static var defaultDirectoryURL: URL {
        CodexSessionStore.defaultDirectoryURL
    }

    public static var defaultFileURL: URL {
        defaultDirectoryURL.appendingPathComponent("claude-session-registry.json")
    }

    public init(
        fileURL: URL = ClaudeSessionRegistry.defaultFileURL,
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func load() throws -> [ClaudeTrackedSessionRecord] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ClaudeTrackedSessionRecord].self, from: data)
    }

    public func save(_ records: [ClaudeTrackedSessionRecord]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(records)
        try data.write(to: fileURL, options: .atomic)
    }
}
