import AppKit
import Carbon.HIToolbox

@MainActor
final class IslandShortcutController {
    static let shortcutDescription = "Control + Option + Space"

    private weak var model: AppModel?
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?

    func start(model: AppModel) {
        self.model = model
        guard eventHandler == nil, hotKeyRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let controller = Unmanaged<IslandShortcutController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                Task { @MainActor in
                    controller.openTemporaryChat()
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandler
        )

        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func stop() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKeyRef = nil
        eventHandler = nil
    }

    private func openTemporaryChat() {
        model?.openTemporaryChatFromShortcut()
    }

    private static let hotKeySignature: OSType = 0x4169_736C // "Aisl"
}
