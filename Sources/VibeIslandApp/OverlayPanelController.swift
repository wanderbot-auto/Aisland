import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController {
    private var panel: IslandPanel?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show(model: AppModel) {
        let panel = panel ?? makePanel(model: model)
        self.panel = panel
        position(panel: panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel(model: AppModel) -> IslandPanel {
        let panel = IslandPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 256),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.contentViewController = NSHostingController(rootView: IslandPanelView(model: model))
        return panel
    }

    private func position(panel: NSPanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else {
            return
        }

        let size = panel.frame.size
        let visibleFrame = screen.visibleFrame
        let frame = NSRect(
            x: visibleFrame.midX - (size.width / 2),
            y: visibleFrame.maxY - size.height - 18,
            width: size.width,
            height: size.height
        )
        panel.setFrame(frame, display: true)
    }
}

private final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
