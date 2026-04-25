# Removal Inventory

This inventory tracks the planned removal of non-core surfaces during the systematic refactor. The retained core agent set is Codex, Claude Code, and OpenCode.

## Retained Core Agents

| Agent | Keep scope |
|---|---|
| Codex | Native hook payloads, bridge conversion, session tracking, setup/status UI, usage where still relevant, terminal jump metadata. |
| Claude Code | Native hook payloads, bridge conversion, permission/question flows, subagent/task presentation, transcript discovery, setup/status UI. |
| OpenCode | Plugin integration, bridge conversion, permission/question flows, session registry, setup/status UI. |

## Unsupported Agent Removal Inventory

Unsupported one-off agent integrations have been removed from the first-class product boundary.
The retained setup, bridge, persistence, and UI surfaces now target only Codex, Claude Code, OpenCode, and the generic agent model.

Cleanup completed in this area:

- Removed dedicated unsupported-agent adapter source files and tests.
- Removed first-class bridge commands, responses, metadata events, and process liveness branches for unsupported adapters.
- Removed unsupported-agent hook installer status, setup actions, and configuration rows from the app UI.
- Removed unsupported `--source` hook CLI cases and setup CLI commands.
- Updated public docs to advertise only the retained agent set and the generic adapter boundary.

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
| Xcode project | `ios/AislandMobile.xcodeproj/project.pbxproj` |
| iOS app | `ios/AislandMobile/App.swift`, `ios/AislandMobile/ContentView.swift`, `ios/AislandMobile/Info.plist`, `ios/AislandMobile/PrivacyInfo.xcprivacy` |
| iOS models | `ios/AislandMobile/Models/WatchEvent.swift` |
| iOS networking | `ios/AislandMobile/Network/BonjourDiscovery.swift`, `ios/AislandMobile/Network/ConnectionManager.swift`, `ios/AislandMobile/Network/SSEClient.swift`, `ios/AislandMobile/Network/WatchConnectivityManager.swift` |
| iOS notifications | `ios/AislandMobile/Notifications/NotificationManager.swift` |
| iOS views | `ios/AislandMobile/Views/EventDetailView.swift`, `ios/AislandMobile/Views/PairingView.swift`, `ios/AislandMobile/Views/SettingsView.swift` |
| iOS assets | `ios/AislandMobile/Assets.xcassets/**` |
| Watch app | `ios/AislandWatch/ContentView.swift`, `ios/AislandWatch/EventCardView.swift`, `ios/AislandWatch/HapticManager.swift`, `ios/AislandWatch/AislandWatchApp.swift`, `ios/AislandWatch/PrivacyInfo.xcprivacy`, `ios/AislandWatch/WatchSessionManager.swift` |
| Watch assets | `ios/AislandWatch/Assets.xcassets/**` |
| Shared mobile/watch messages | `ios/Shared/WatchMessage.swift` |

### Deleted macOS App-Side Watch Files

| File | Reason |
|---|---|
| `Sources/AislandCore/WatchHTTPEndpoint.swift` | Removes embedded HTTP/SSE server and Bonjour pairing surface. |
| `Sources/AislandCore/WatchNotificationRelay.swift` | Removes AppModel-to-Watch event relay and resolution callbacks. |

### macOS Files Cleaned In Place

| File | Cleanup |
|---|---|
| `Sources/AislandApp/AppModel.swift` | Remove watch notification defaults, relay lifecycle, pairing state, and event forwarding. |
| `Sources/AislandApp/Views/SettingsView.swift` | Remove Watch settings tab and `WatchSettingsPane`. |
| `docs/index.md` | Remove Watch/iOS documentation section. |
| `docs/roadmap.md` | Remove Watch/iOS roadmap row. |
| `docs/roadmap.zh-CN.md` | Remove Watch/iOS roadmap row. |
| `docs/refactor-plan.md` | Update code-size notes and remove companion references after deletion. |

### Deleted Watch Docs

| File | Reason |
|---|---|
| `docs/watch-notification-design.md` | Obsolete companion feature design. |
| `docs/watch-notification-impl-plan.md` | Obsolete companion feature implementation plan. |
