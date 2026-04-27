import Foundation
import Testing
@testable import AislandApp
import AislandCore

@MainActor
struct HookInstallationCoordinatorTests {
    @Test
    func untouchedMissingAgentsAutoInstallByDefault() {
        let (store, _) = makeStore()
        let coordinator = HookInstallationCoordinator(intentStore: store)

        for agent in AgentIdentifier.allCases {
            #expect(coordinator.shouldAutoInstall(agent))
        }
    }

    @Test
    func explicitUninstallOptOutBlocksAutoInstall() {
        let (store, _) = makeStore()
        store.setIntent(.uninstalled, for: .codex)
        let coordinator = HookInstallationCoordinator(intentStore: store)

        #expect(!coordinator.shouldAutoInstall(.codex))
        #expect(coordinator.shouldAutoInstall(.claudeCode))
    }

    private func makeStore() -> (AgentIntentStore, UserDefaults) {
        let suiteName = "HookInstallationCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (AgentIntentStore(defaults: defaults), defaults)
    }
}
