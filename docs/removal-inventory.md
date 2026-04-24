# Removal Inventory

This inventory tracks the planned removal of non-core surfaces during the systematic refactor. The retained core agent set is Codex, Claude Code, and OpenCode.

## Retained Core Agents

| Agent | Keep scope |
|---|---|
| Codex | Native hook payloads, bridge conversion, session tracking, setup/status UI, usage where still relevant, terminal jump metadata. |
| Claude Code | Native hook payloads, bridge conversion, permission/question flows, subagent/task presentation, transcript discovery, setup/status UI. |
| OpenCode | Plugin integration, bridge conversion, permission/question flows, session registry, setup/status UI. |

## Unsupported Agent Removal Inventory

These agent-specific paths should be removed or replaced by generic adapter support in later slices.

### Dedicated Source Files

| Surface | Files |
|---|---|
| Cursor | `Sources/OpenIslandCore/CursorHookInstallationManager.swift`, `Sources/OpenIslandCore/CursorHookInstaller.swift`, `Sources/OpenIslandCore/CursorHooks.swift`, `Sources/OpenIslandCore/CursorSessionRegistry.swift`, `Sources/OpenIslandCore/CursorTranscriptReader.swift` |
| Gemini CLI | `Sources/OpenIslandCore/GeminiHookInstallationManager.swift`, `Sources/OpenIslandCore/GeminiHookInstaller.swift`, `Sources/OpenIslandCore/GeminiHooks.swift` |
| Kimi CLI | `Sources/OpenIslandCore/KimiHookInstallationManager.swift`, `Sources/OpenIslandCore/KimiHookInstaller.swift` |

### Shared Files With Unsupported-Agent Branches

| File | Cleanup needed |
|---|---|
| `Sources/OpenIslandCore/AgentSession.swift` | Remove enum cases and display metadata for Cursor, Gemini, Kimi, Qoder, Qwen Code, Factory, and CodeBuddy once generic support exists. |
| `Sources/OpenIslandCore/AgentHookIntent.swift` | Remove agent identifiers/intents that are no longer first-class integrations. |
| `Sources/OpenIslandCore/BridgeTransport.swift` | Remove first-class bridge command/response cases for removed agents, or route them through a generic adapter command. |
| `Sources/OpenIslandCore/BridgeServer.swift` | Remove dedicated `handleCursorHook`, `handleGeminiHook`, Kimi/fork branches, and associated pending state. |
| `Sources/OpenIslandCore/ClaudeHooks.swift` | Keep Claude Code support; remove hard-coded fork mapping for Qoder, Qwen Code, Factory, CodeBuddy, and Kimi. |
| `Sources/OpenIslandApp/HookInstallationCoordinator.swift` | Remove status, busy flags, install/uninstall actions, and summaries for removed agents. |
| `Sources/OpenIslandApp/AppModel.swift` | Remove app facade properties and actions for removed agents. |
| `Sources/OpenIslandApp/Views/SettingsView.swift` | Remove setup UI sections for removed agents. |
| `Sources/OpenIslandHooks/OpenIslandHooksCLI.swift` | Remove `--source` cases for removed dedicated integrations or map future generic sources through one adapter. |
| `Sources/OpenIslandSetup/OpenIslandSetupCLI.swift` | Remove Kimi setup commands. |
| `Sources/OpenIslandApp/ActiveAgentProcessDiscovery.swift` | Remove process classifiers for removed first-class agents, or map generic ones to a generic process identity. |
| `Sources/OpenIslandApp/ProcessMonitoringCoordinator.swift` | Remove first-class liveness logic for removed agents after generic identity is introduced. |
| `Sources/OpenIslandApp/SessionDiscoveryCoordinator.swift` | Remove persistence/discovery for removed first-class registries. |
| `Sources/OpenIslandApp/IslandDebugScenario.swift` | Remove debug fixtures for removed first-class agents. |
| `Sources/OpenIslandApp/Views/ControlCenterView.swift` | Remove removed-agent setup/debug status display. |

### Tests And Docs

| Area | Files |
|---|---|
| Tests | `Tests/OpenIslandCoreTests/CursorHooksTests.swift`, `Tests/OpenIslandCoreTests/GeminiHooksTests.swift`, `Tests/OpenIslandCoreTests/KimiHooksTests.swift`, plus unsupported-agent expectations in `Tests/OpenIslandCoreTests/SessionStateTests.swift` and `Tests/OpenIslandCoreTests/AgentIntentStoreTests.swift`. |
| Public docs | `README.md`, `README.zh-CN.md`, `docs/product.md`, `docs/hooks.md`, `docs/roadmap.md`, `docs/roadmap.zh-CN.md`. |
| Internal docs/scripts | `docs/refactor-plan.md`, `docs/app-ghostty-codex-chain.md`, `docs/installed-app-bundle-analysis.md`, `scripts/clean-user-env.sh`. |

## Generic Unsupported-Agent Adapter Direction

Unsupported agents should not regain one-off first-class integrations during this refactor. If future compatibility is needed, it should go through a generic adapter surface:

- Define a single `genericAgentHook` bridge command with a stable minimal payload: agent name, session ID, event kind, summary, optional command/tool preview, optional permission request, optional question, and optional jump target.
- Map generic sessions to a single `AgentTool.generic(name:)`-style presentation model, or equivalent metadata that does not require new enum cases for every agent.
- Keep generic setup manual or plugin-driven; do not add per-agent installers unless the agent graduates back into core scope.
- Keep generic tests payload-driven so new community adapters can be added without touching `BridgeServer` switch cases.
- Document the generic payload contract separately after Codex, Claude Code, and OpenCode adapters are isolated.

## iOS / Watch Removal Inventory

This refactor pass removes the companion surfaces entirely.

### Deleted Companion Project Files

| Area | Files |
|---|---|
| Xcode project | `ios/OpenIslandMobile.xcodeproj/project.pbxproj` |
| iOS app | `ios/OpenIslandMobile/App.swift`, `ios/OpenIslandMobile/ContentView.swift`, `ios/OpenIslandMobile/Info.plist`, `ios/OpenIslandMobile/PrivacyInfo.xcprivacy` |
| iOS models | `ios/OpenIslandMobile/Models/WatchEvent.swift` |
| iOS networking | `ios/OpenIslandMobile/Network/BonjourDiscovery.swift`, `ios/OpenIslandMobile/Network/ConnectionManager.swift`, `ios/OpenIslandMobile/Network/SSEClient.swift`, `ios/OpenIslandMobile/Network/WatchConnectivityManager.swift` |
| iOS notifications | `ios/OpenIslandMobile/Notifications/NotificationManager.swift` |
| iOS views | `ios/OpenIslandMobile/Views/EventDetailView.swift`, `ios/OpenIslandMobile/Views/PairingView.swift`, `ios/OpenIslandMobile/Views/SettingsView.swift` |
| iOS assets | `ios/OpenIslandMobile/Assets.xcassets/**` |
| Watch app | `ios/OpenIslandWatch/ContentView.swift`, `ios/OpenIslandWatch/EventCardView.swift`, `ios/OpenIslandWatch/HapticManager.swift`, `ios/OpenIslandWatch/OpenIslandWatchApp.swift`, `ios/OpenIslandWatch/PrivacyInfo.xcprivacy`, `ios/OpenIslandWatch/WatchSessionManager.swift` |
| Watch assets | `ios/OpenIslandWatch/Assets.xcassets/**` |
| Shared mobile/watch messages | `ios/Shared/WatchMessage.swift` |

### Deleted macOS App-Side Watch Files

| File | Reason |
|---|---|
| `Sources/OpenIslandCore/WatchHTTPEndpoint.swift` | Removes embedded HTTP/SSE server and Bonjour pairing surface. |
| `Sources/OpenIslandCore/WatchNotificationRelay.swift` | Removes AppModel-to-Watch event relay and resolution callbacks. |

### macOS Files Cleaned In Place

| File | Cleanup |
|---|---|
| `Sources/OpenIslandApp/AppModel.swift` | Remove watch notification defaults, relay lifecycle, pairing state, and event forwarding. |
| `Sources/OpenIslandApp/Views/SettingsView.swift` | Remove Watch settings tab and `WatchSettingsPane`. |
| `docs/index.md` | Remove Watch/iOS documentation section. |
| `docs/roadmap.md` | Remove Watch/iOS roadmap row. |
| `docs/roadmap.zh-CN.md` | Remove Watch/iOS roadmap row. |
| `docs/refactor-plan.md` | Update code-size notes and remove companion references after deletion. |

### Deleted Watch Docs

| File | Reason |
|---|---|
| `docs/watch-notification-design.md` | Obsolete companion feature design. |
| `docs/watch-notification-impl-plan.md` | Obsolete companion feature implementation plan. |
