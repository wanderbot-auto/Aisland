import Foundation
import AislandCore

enum IslandSurfaceTab: String, CaseIterable, Identifiable {
    case sessions
    case chat
    case usage
    case whiteNoise

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .sessions:
            "checklist.checked"
        case .chat:
            "brain.head.profile"
        case .usage:
            "chart.bar.xaxis"
        case .whiteNoise:
            "waveform"
        }
    }

    var accessibilityLabelKey: String {
        switch self {
        case .sessions:
            "island.surface.sessions"
        case .chat:
            "island.surface.chat"
        case .usage:
            "island.surface.usage"
        case .whiteNoise:
            "island.surface.whiteNoise"
        }
    }

    var selectionSurface: IslandSurface {
        switch self {
        case .sessions:
            .sessionList()
        case .chat:
            .temporaryChat
        case .usage:
            .usage
        case .whiteNoise:
            .whiteNoise
        }
    }

    func matches(_ surface: IslandSurface) -> Bool {
        switch (self, surface) {
        case (.sessions, .sessionList):
            true
        case (.chat, .temporaryChat):
            true
        case (.usage, .usage):
            true
        case (.whiteNoise, .whiteNoise):
            true
        default:
            false
        }
    }
}

enum IslandSurface: Equatable {
    case sessionList(actionableSessionID: String? = nil)
    case temporaryChat
    case usage
    case whiteNoise

    static var switchableTabs: [IslandSurfaceTab] {
        IslandSurfaceTab.allCases
    }

    var sessionID: String? {
        switch self {
        case let .sessionList(actionableSessionID):
            actionableSessionID
        case .temporaryChat, .usage, .whiteNoise:
            nil
        }
    }

    var isNotificationCard: Bool {
        sessionID != nil
    }

    var switchableTab: IslandSurfaceTab? {
        guard !isNotificationCard else {
            return nil
        }

        switch self {
        case .sessionList:
            return IslandSurfaceTab.sessions
        case .temporaryChat:
            return IslandSurfaceTab.chat
        case .usage:
            return IslandSurfaceTab.usage
        case .whiteNoise:
            return IslandSurfaceTab.whiteNoise
        }
    }

    func nextSwitchableSurface(backwards: Bool = false) -> IslandSurface? {
        guard let currentTab = switchableTab else {
            return nil
        }

        let tabs = Self.switchableTabs
        guard tabs.count > 1,
              let currentIndex = tabs.firstIndex(of: currentTab) else {
            return nil
        }

        let nextIndex = backwards
            ? (currentIndex - 1 + tabs.count) % tabs.count
            : (currentIndex + 1) % tabs.count
        return tabs[nextIndex].selectionSurface
    }

    func autoDismissesWhenPresentedAsNotification(session: AgentSession?) -> Bool {
        guard sessionID != nil else { return false }
        return session?.phase == .completed
    }

    static func notificationSurface(for event: AgentEvent) -> IslandSurface? {
        switch event {
        case let .permissionRequested(payload):
            .sessionList(actionableSessionID: payload.sessionID)
        case let .questionAsked(payload):
            .sessionList(actionableSessionID: payload.sessionID)
        case let .sessionCompleted(payload):
            payload.isInterrupt == true ? nil : .sessionList(actionableSessionID: payload.sessionID)
        default:
            nil
        }
    }

    func matchesCurrentState(of session: AgentSession?) -> Bool {
        guard sessionID != nil else {
            return true
        }

        guard let session else {
            return false
        }

        switch session.phase {
        case .waitingForApproval:
            return session.permissionRequest != nil
        case .waitingForAnswer:
            return session.questionPrompt != nil
        case .completed:
            return true
        case .running:
            return false
        }
    }
}
