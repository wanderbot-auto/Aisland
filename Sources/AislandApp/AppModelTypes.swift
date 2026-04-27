import AppKit
import CoreGraphics
import Foundation

enum NotchStatus: Equatable {
    case closed
    case opened
    case popping
}

enum NotchOpenReason: Equatable {
    case click
    case hover
    case notification
    case shortcut
    case boot
}

enum TrackedEventIngress {
    case bridge
    case rollout
}

// MARK: - Island appearance

enum IslandAppearanceMode: String, CaseIterable, Identifiable {
    case `default`
    case custom

    var id: String { rawValue }
}

enum IslandInterfaceTheme: String, CaseIterable, Identifiable {
    case cyberMinimalist
    case graphiteClassic

    var id: String { rawValue }
}

enum IslandClosedDisplayStyle: String, CaseIterable, Identifiable {
    case minimal
    case detailed

    var id: String { rawValue }
}

enum IslandPixelShapeStyle: String, CaseIterable, Identifiable {
    case bars
    case steps
    case blocks
    case custom

    var id: String { rawValue }
}

enum IslandTokenUsageDisplayMode: String, CaseIterable, Identifiable {
    case claude
    case codex
    case both

    var id: String { rawValue }
}

enum QuestionOptionLayout: String, CaseIterable, Identifiable {
    case horizontal
    case vertical

    var id: String { rawValue }
}
