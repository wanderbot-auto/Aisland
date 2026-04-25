import Foundation
import Testing
@testable import AislandApp

struct HarnessLaunchConfigurationTests {
    @Test
    func defaultsMatchNormalAppLaunch() {
        let configuration = HarnessLaunchConfiguration(environment: [:])

        #expect(configuration.scenario == nil)
        #expect(!configuration.presentOverlay)
        #expect(configuration.shouldShowControlCenter)
        #expect(configuration.shouldStartBridge)
        #expect(configuration.shouldPerformBootAnimation)
        #expect(configuration.captureDelay == nil)
        #expect(configuration.autoExitAfter == nil)
        #expect(configuration.artifactDirectoryURL == nil)
    }

    @Test
    func parsesScenarioFlagsAndAutoExit() {
        let configuration = HarnessLaunchConfiguration(
            environment: [
                "AISLAND_HARNESS_SCENARIO": "approvalcard",
                "AISLAND_HARNESS_PRESENT_OVERLAY": "true",
                "AISLAND_HARNESS_SHOW_CONTROL_CENTER": "0",
                "AISLAND_HARNESS_START_BRIDGE": "no",
                "AISLAND_HARNESS_BOOT_ANIMATION": "off",
                "AISLAND_HARNESS_CAPTURE_DELAY_SECONDS": "1.5",
                "AISLAND_HARNESS_AUTO_EXIT_SECONDS": "2.5",
                "AISLAND_HARNESS_ARTIFACT_DIR": "/tmp/aisland-artifacts",
            ]
        )

        #expect(configuration.scenario == .approvalCard)
        #expect(configuration.presentOverlay)
        #expect(!configuration.shouldShowControlCenter)
        #expect(!configuration.shouldStartBridge)
        #expect(!configuration.shouldPerformBootAnimation)
        #expect(configuration.captureDelay == 1.5)
        #expect(configuration.autoExitAfter == 2.5)
        #expect(configuration.artifactDirectoryURL?.path == "/tmp/aisland-artifacts")
    }

    @Test
    func ignoresInvalidInputs() {
        let configuration = HarnessLaunchConfiguration(
            environment: [
                "AISLAND_HARNESS_SCENARIO": "missing",
                "AISLAND_HARNESS_PRESENT_OVERLAY": "unexpected",
                "AISLAND_HARNESS_CAPTURE_DELAY_SECONDS": "0",
                "AISLAND_HARNESS_AUTO_EXIT_SECONDS": "-1",
                "AISLAND_HARNESS_ARTIFACT_DIR": "   ",
            ]
        )

        #expect(configuration.scenario == nil)
        #expect(!configuration.presentOverlay)
        #expect(configuration.captureDelay == nil)
        #expect(configuration.autoExitAfter == nil)
        #expect(configuration.artifactDirectoryURL == nil)
    }
}
