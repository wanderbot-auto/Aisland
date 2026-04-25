import Carbon.HIToolbox
import Testing
@testable import AislandApp

struct IslandKeyboardShortcutTests {
    @Test
    func letterAKeyShortcutRemainsValid() {
        let shortcut = IslandKeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_A),
            modifiers: UInt32(cmdKey)
        )

        #expect(shortcut.isValid)
    }

    @Test
    func modifierOnlyShortcutIsRejected() {
        let shortcut = IslandKeyboardShortcut(
            keyCode: UInt32(kVK_Command),
            modifiers: UInt32(cmdKey)
        )

        #expect(!shortcut.isValid)
    }
}
