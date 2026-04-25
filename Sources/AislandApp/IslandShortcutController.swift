import AppKit
import Carbon.HIToolbox

@MainActor
final class IslandShortcutController {
    static let shortcutDescription = IslandKeyboardShortcut.defaultShortcuts[.openIsland]?.displayText ?? "Control + Option + Space"

    private weak var model: AppModel?
    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [IslandShortcutAction: EventHotKeyRef] = [:]
    private var actionsByHotKeyID: [UInt32: IslandShortcutAction] = [:]

    func start(model: AppModel) {
        self.model = model
        installHandlerIfNeeded()
        reloadShortcuts(model.shortcuts)
    }

    func reloadShortcuts(_ shortcuts: [IslandShortcutAction: IslandKeyboardShortcut]) {
        unregisterHotKeys()

        for action in IslandShortcutAction.allCases {
            guard let shortcut = shortcuts[action], shortcut.isValid else { continue }
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: action.hotKeyID)
            let status = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.carbonModifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            guard status == noErr, let hotKeyRef else { continue }
            hotKeyRefs[action] = hotKeyRef
            actionsByHotKeyID[action.hotKeyID] = action
        }
    }

    func stop() {
        unregisterHotKeys()
        if let eventHandler { RemoveEventHandler(eventHandler) }
        eventHandler = nil
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData, let eventRef else { return noErr }
                let controller = Unmanaged<IslandShortcutController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                Task { @MainActor in
                    controller.performAction(forHotKeyID: hotKeyID.id)
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandler
        )
    }

    private func performAction(forHotKeyID id: UInt32) {
        guard let action = actionsByHotKeyID[id] else { return }
        model?.performShortcutAction(action)
    }

    private func unregisterHotKeys() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        actionsByHotKeyID.removeAll()
    }

    private static let hotKeySignature: OSType = 0x4169_736C // "Aisl"
}
