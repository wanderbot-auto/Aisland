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

enum IslandInterfaceTheme: String, CaseIterable, Identifiable {
    case cyberMinimalist
    case graphiteClassic

    var id: String { rawValue }
}

enum InterfaceTransparencySetting {
    static let defaultValue = 0.10
    static let presetPercentages = [0, 5, 10, 15, 20, 25, 30, 35, 40, 50]
    static let range: ClosedRange<Double> = 0...0.50

    static func clamped(_ value: Double) -> Double {
        let clampedValue = min(max(value, range.lowerBound), range.upperBound)
        return presetPercentages
            .map { Double($0) / 100 }
            .min { abs($0 - clampedValue) < abs($1 - clampedValue) }
            ?? defaultValue
    }
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
    case kitten
    case corgi
    case puppy
    case hamster
    case bunny
    case panda
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
