import Foundation

enum TemporaryChatRole: String, Codable, Sendable {
    case user
    case assistant
}

struct TemporaryChatMessage: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let role: TemporaryChatRole
    let content: String
    let createdAt: Date

    init(id: UUID = UUID(), role: TemporaryChatRole, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
