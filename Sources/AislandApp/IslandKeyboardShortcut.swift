import AppKit
import Carbon.HIToolbox

enum IslandShortcutAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case openIsland
    case openSessions
    case openChat

    var id: String { rawValue }

    var hotKeyID: UInt32 {
        switch self {
        case .openIsland: 1
        case .openSessions: 2
        case .openChat: 3
        }
    }

    func title(_ lang: LanguageManager) -> String {
        switch self {
        case .openIsland: lang.t("settings.shortcuts.openIsland")
        case .openSessions: lang.t("settings.shortcuts.openSessions")
        case .openChat: lang.t("settings.shortcuts.openChat")
        }
    }

    func detail(_ lang: LanguageManager) -> String {
        switch self {
        case .openIsland: lang.t("settings.shortcuts.openIsland.help")
        case .openSessions: lang.t("settings.shortcuts.openSessions.help")
        case .openChat: lang.t("settings.shortcuts.openChat.help")
        }
    }
}

struct IslandKeyboardShortcut: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var modifiers: UInt32

    var isValid: Bool { keyCode > 0 && modifiers != 0 }

    var displayText: String {
        modifierDisplay + keyDisplayName
    }

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers & Self.commandMask != 0 { result |= UInt32(cmdKey) }
        if modifiers & Self.optionMask != 0 { result |= UInt32(optionKey) }
        if modifiers & Self.controlMask != 0 { result |= UInt32(controlKey) }
        if modifiers & Self.shiftMask != 0 { result |= UInt32(shiftKey) }
        return result
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= Self.commandMask }
        if flags.contains(.option) { modifiers |= Self.optionMask }
        if flags.contains(.control) { modifiers |= Self.controlMask }
        if flags.contains(.shift) { modifiers |= Self.shiftMask }
        guard modifiers != 0 else { return nil }
        self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    }

    static let defaultShortcuts: [IslandShortcutAction: IslandKeyboardShortcut] = [
        .openIsland: IslandKeyboardShortcut(keyCode: UInt32(kVK_Space), modifiers: controlMask | optionMask),
        .openSessions: IslandKeyboardShortcut(keyCode: UInt32(kVK_ANSI_1), modifiers: controlMask | optionMask),
        .openChat: IslandKeyboardShortcut(keyCode: UInt32(kVK_ANSI_2), modifiers: controlMask | optionMask),
    ]

    private var modifierDisplay: String {
        var parts = ""
        if modifiers & Self.controlMask != 0 { parts += "⌃" }
        if modifiers & Self.optionMask != 0 { parts += "⌥" }
        if modifiers & Self.shiftMask != 0 { parts += "⇧" }
        if modifiers & Self.commandMask != 0 { parts += "⌘" }
        return parts
    }

    private var keyDisplayName: String {
        switch Int(keyCode) {
        case kVK_Space: "Space"
        case kVK_Tab: "Tab"
        case kVK_Return: "Return"
        case kVK_Escape: "Esc"
        case kVK_Delete: "Delete"
        case kVK_ANSI_0: "0"
        case kVK_ANSI_1: "1"
        case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"
        case kVK_ANSI_4: "4"
        case kVK_ANSI_5: "5"
        case kVK_ANSI_6: "6"
        case kVK_ANSI_7: "7"
        case kVK_ANSI_8: "8"
        case kVK_ANSI_9: "9"
        case kVK_ANSI_A: "A"
        case kVK_ANSI_B: "B"
        case kVK_ANSI_C: "C"
        case kVK_ANSI_D: "D"
        case kVK_ANSI_E: "E"
        case kVK_ANSI_F: "F"
        case kVK_ANSI_G: "G"
        case kVK_ANSI_H: "H"
        case kVK_ANSI_I: "I"
        case kVK_ANSI_J: "J"
        case kVK_ANSI_K: "K"
        case kVK_ANSI_L: "L"
        case kVK_ANSI_M: "M"
        case kVK_ANSI_N: "N"
        case kVK_ANSI_O: "O"
        case kVK_ANSI_P: "P"
        case kVK_ANSI_Q: "Q"
        case kVK_ANSI_R: "R"
        case kVK_ANSI_S: "S"
        case kVK_ANSI_T: "T"
        case kVK_ANSI_U: "U"
        case kVK_ANSI_V: "V"
        case kVK_ANSI_W: "W"
        case kVK_ANSI_X: "X"
        case kVK_ANSI_Y: "Y"
        case kVK_ANSI_Z: "Z"
        default: "Key \(keyCode)"
        }
    }

    private static let commandMask: UInt32 = 1 << 0
    private static let optionMask: UInt32 = 1 << 1
    private static let controlMask: UInt32 = 1 << 2
    private static let shiftMask: UInt32 = 1 << 3
}
