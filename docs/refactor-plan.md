# Systematic Refactor Plan

This document captures the current repository shape, complexity hotspots, and a staged refactoring route for simplifying Aisland without losing critical behavior.

## Goals

- Keep the native macOS product centered on `AislandApp`.
- Preserve fail-open hook behavior and local-first runtime guarantees.
- Reduce the highest-coupling files before deleting or reshaping features.
- Make every refactor slice independently reviewable, testable, and reversible.
- Clarify which supported agents, terminals, and companion surfaces are core versus optional before removing code.

## Current System Shape

The repository is primarily a Swift package with four products:

| Target | Role |
|---|---|
| `AislandApp` | SwiftUI + AppKit app shell, menu bar extra, overlay/notch panel, settings, control center, discovery, process monitoring, terminal jump-back. |
| `AislandCore` | Shared domain and runtime layer: session/event models, reducer, Unix socket transport, bridge server, hook payloads, installers, registries, and usage loading. |
| `AislandHooks` | Hook CLI invoked by supported agents. It reads stdin JSON, decodes by `--source`, forwards to the app bridge, and writes blocking directives only when needed. |
| `AislandSetup` | Setup CLI for installing, uninstalling, and checking managed Codex and Claude hooks. |

Supporting areas:

| Area | Role |
|---|---|
| `Tests` | Unit coverage for core reducers, hook payloads, session tracking, jump behavior, and app state lists. |
| `scripts` | Build, package, smoke, appcast, icon, release, and local environment helper scripts. |
| `docs` | Architecture, product scope, hooks, quality, release, worktree, removal, and investigation notes. |

## Code Size Snapshot

Top-level source/documentation footprint:

| Area | Lines |
|---|---:|
| `Sources` | 33,838 |
| `Tests` | 8,510 |
| `docs` | 5,142 |
| `scripts` | 2,391 |
| Total measured | 49,881 |

Swift target footprint:

| Area | Swift lines |
|---|---:|
| `Sources/AislandApp` | 18,144 |
| `Sources/AislandCore` | 14,938 |
| `Tests/AislandCoreTests` | 5,212 |
| `Tests/AislandAppTests` | 3,298 |
| `Sources/AislandSetup` | 283 |
| `Sources/AislandHooks` | 135 |

Largest Swift files:

| File | Lines | Primary concern |
|---|---:|---|
| `Sources/AislandCore/BridgeServer.swift` | 2,534 | Socket server, command router, per-agent hook adapters, pending interaction store, event emission. |
| `Sources/AislandApp/Views/IslandPanelView.swift` | 2,375 | Root island UI, header, session list, rows, approvals, questions, replies, usage, menu bar content. |
| `Sources/AislandApp/AppModel.swift` | 1,449 | App-level observable state, bridge observer, user actions, overlay forwarding, discovery, monitoring, and persistence. |
| `Sources/AislandCore/ClaudeHooks.swift` | 1,385 | Claude-compatible payloads, directives, metadata, question, permission, subagent, and task parsing. |
| `Sources/AislandApp/TerminalSessionAttachmentProbe.swift` | 1,360 | Terminal session attachment probing and matching. |
| `Sources/AislandApp/TerminalJumpService.swift` | 1,318 | Multi-terminal jump-back implementation. |
| `Sources/AislandApp/HookInstallationCoordinator.swift` | 1,310 | App-facing hook setup status, install/uninstall, usage monitoring, health checks, repair. |
| `Sources/AislandApp/Views/SettingsView.swift` | 1,166 | Settings UI and agent/update setup sections. |
| `Sources/AislandCore/CodexSessionTracking.swift` | 1,140 | Codex rollout discovery, session store, reducer, and watcher. |
| `Sources/AislandApp/ProcessMonitoringCoordinator.swift` | 1,021 | Active process discovery and session liveness reconciliation. |

## Key Runtime Flows

### Agent Hook To UI

1. A supported agent invokes `AislandHooks`.
2. `AislandHooksCLI` decodes stdin based on `--source`.
3. `BridgeCommandClient` sends a `BridgeCommand` over the local Unix socket.
4. `BridgeServer` handles the command, translates payloads into `AgentEvent`s, and manages pending approval/question responses.
5. `AppModel` observes bridge events and calls `SessionState.apply(_:)`.
6. `OverlayUICoordinator` and `IslandPanelView` present session, approval, question, or completion state.

### App Startup

1. `AislandAppDelegate.applicationDidFinishLaunching` creates and starts `AppModel`.
2. `AppModel.startIfNeeded` runs startup discovery, hook status refreshes, usage monitoring, update checks, overlay setup, and bridge startup.
3. `LocalBridgeClient` registers as a bridge observer and streams `AgentEvent`s back into `AppModel`.

### Terminal Jump-Back

1. Hook payloads and process discovery enrich sessions with `JumpTarget`.
2. `TerminalJumpTargetResolver` and terminal probes improve target precision.
3. `TerminalJumpService.jump(to:)` dispatches to terminal-specific AppleScript, CLI, URL scheme, or socket logic.

## Main Complexity Drivers

- Focused agent support: Claude Code, Codex, OpenCode, and General Agent.
- Broad terminal support: Terminal.app, Ghostty, cmux, Kaku, WezTerm, iTerm2, tmux, Zellij, Warp fallback, VS Code family, and JetBrains workspace jumps.
- Large state facade: `AppModel` coordinates bridge, overlay, settings, hooks, process discovery, persistence, sounds, usage, and jump actions.
- Mixed protocol responsibilities: `BridgeServer` combines socket mechanics, command routing, event adaptation, pending interactions, and local state merging.
- UI concentration: `IslandPanelView` includes root panel behavior, presentation logic, all row variants, action controls, structured questions, reply input, usage, and menu content.
- Domain model pressure: `AgentSession` carries terminal metadata, per-agent metadata, permissions, questions, tasks, subagents, liveness, and display state.

## Refactor Route

### Phase 0: Scope And Guardrails

Scope decision for this refactor pass:

| Surface | Decision | Notes |
|---|---|---|
| Codex | Keep core | Preserve hook support, session tracking, usage where still relevant, and terminal jump enrichment. |
| Claude Code | Keep core | Preserve Claude Code hook support, permission/question flows, subagent/task presentation, and transcript discovery where needed. |
| OpenCode | Keep core | Preserve plugin support, permission/question flows, session registry, and process discovery. |
| Unsupported one-off agents | Removed | Dedicated adapters, payload handling, installer/status UI, tests, and docs references have been removed. Future compatibility must use the generic adapter boundary. |
| iOS companion app | Removed | Mobile project/code/docs references were deleted in the iOS/Watch removal slice. |
| Watch companion app | Removed | Watch target/code/docs references and app-side relay integration were deleted in the iOS/Watch removal slice. |
| Terminal jump support | Keep for now | Defer terminal support pruning until jump strategies are split and independently testable. |
| Usage dashboards | Keep for now | Reassess after unsupported agent removal simplifies setup and session metadata. |
| Sparkle auto-update | Keep for now | Not coupled to agent scope; preserve unless release scope changes. |
| Debug harnesses and packaging | Keep for now | Useful during refactor verification and release checks. |

Guardrails before deleting code:

- Keep Codex, Claude Code, and OpenCode behavior intact until adapter and facade boundaries are in place.
- Remove unsupported agents in narrow vertical slices: core payloads, bridge handling, app coordinator state, settings UI, tests, and docs.
- Keep iOS/Watch removal separate from agent removal because it touched app relay state, `ios/`, docs, and project files.
- Classify terminal jump implementations later, after strategy extraction exposes per-terminal ownership.

### Phase 1: Strengthen Verification Around Core Behavior

Before structural edits, lock down the behavior that must survive.

- Add or expand golden tests for hook payload to `AgentEvent` conversion.
- Cover permission approval, question answer, completion, and stale/duplicate completion handling.
- Cover `AppModel.applyTrackedEvent` state transitions at the app boundary.
- Keep existing `SessionState`, hook parser, session tracking, and terminal jump tests green.
- Use `swift test` as the default verification for each code slice.

### Phase 2: Split `BridgeServer`

Target: reduce the highest-coupled runtime file without changing the socket protocol.

- Keep `BridgeServer` as the socket owner and envelope broadcaster.
- Extract command dispatch into a focused router.
- Extract per-agent event adapters:
  - `CodexBridgeAdapter`
  - `ClaudeBridgeAdapter`
  - `OpenCodeBridgeAdapter`
- Do not extract new unsupported one-off adapters; route future compatibility through the generic adapter boundary instead.
- Extract pending approval/question state into `PendingInteractionStore`.
- Have adapters return explicit effects: events to emit, responses to send, and pending interaction mutations.
- Preserve current `BridgeCommand`, `BridgeResponse`, and JSON envelope formats.

### Phase 3: Slim `AppModel`

Target: make `AppModel` a SwiftUI-facing facade instead of the owner of every side effect.

- Extract bridge observer lifecycle into `BridgeObserverController`.
- Extract user actions into `SessionActionController` or focused methods owned by a session controller.
- Extract persisted settings state into a smaller settings model.
- Keep `AppModel` as the observable facade that SwiftUI views already depend on.
- Avoid changing view bindings until state ownership is clearer.

### Phase 4: Decompose Island UI

Target: split the largest SwiftUI file into testable, previewable surfaces.

- Keep `IslandPanelView` as a root composition shell.
- Move header and usage display into `IslandHeaderView` and `UsageSummaryView`.
- Move list rendering into `IslandSessionListView`.
- Move row presentation into `IslandSessionRow`.
- Move approval, structured question, completion reply, and action controls into dedicated views.
- Move `MenuBarContentView` out of `IslandPanelView.swift`.
- Prefer behavior-preserving moves before visual redesign.

### Phase 5: Strategy-Based Terminal Jump

Target: make terminal support removable and independently testable.

- Introduce a `TerminalJumpStrategy` protocol.
- Keep `TerminalJumpService` as a dispatcher.
- Move terminal-specific logic into separate strategies for Terminal.app, iTerm2, Ghostty, WezTerm, tmux, Zellij, cmux, Warp, and IDE workspace jumps.
- Use one test file per strategy where practical.
- After strategy extraction, remove or demote unsupported terminals according to the Phase 0 scope.

### Phase 6: Data-Driven Hook Installation

Target: remove repeated app-level setup state and per-agent boilerplate for the retained agent set.

- Introduce `AgentIntegrationDescriptor` for display name, config location, installer, status, and supported actions.
- Introduce installer adapters only for Codex, Claude Code, and OpenCode.
- Replace repeated status title/summary logic with a shared view model.
- Simplify `SettingsView` setup sections so they render descriptors rather than hard-coded per-agent blocks.
- Keep unsupported one-off setup/status UI deleted; retained setup UI should render only Codex, Claude Code, and OpenCode.

### Phase 7: Model Boundary Cleanup

Target: reduce pressure on `AgentSession` and make deletions safer.

- Separate cross-agent session state from per-agent metadata.
- Keep `AgentEvent` small and stable.
- Move display-only summaries and colors out of core models where possible.
- Review whether `SessionOrigin`, attachment state, process liveness, task/subagent details, and watch fields belong in one model.
- Coordinate with `docs/session-state-refactor.md` before changing session liveness semantics.

### Phase 8: Feature Simplification And Deletion

Only delete or deeply simplify features after boundaries exist.

- Keep unsupported adapters, installers, CLI source cases, and UI sections removed.
- Remove terminal strategies classified as out of scope.
- Keep iOS and Watch companion features removed; do not reintroduce `ios/`, app-side watch relay wiring, watch settings, or watch documentation links.
- Remove stale docs and tests in the same focused slice as the feature deletion.
- Keep each deletion independently revertible.

## Suggested First Implementation Slice

Start with a non-destructive verification slice for the retained core agents:

1. Add golden tests around the current `BridgeServer` Codex, Claude Code, and OpenCode hook conversions before extraction.
2. Use `docs/removal-inventory.md` to drive unsupported-agent cleanup slices.
3. Run `swift test`.
4. Commit only the tests and inventory update.

This creates a behavior safety net before touching the largest files.

## Immediate Next Steps

Recommended order for the next work round:

1. Add bridge adapter golden tests for Codex, Claude Code, and OpenCode.
2. Keep unsupported agent support behind the generic adapter boundary; do not reintroduce one-off adapters without a new scope decision.
3. Keep iOS/Watch deleted and verify future changes do not recreate companion app, watch relay, or watch settings surfaces.
4. Begin `BridgeServer` extraction with one retained adapter at a time, starting with Codex because its hook flow is smaller than Claude-compatible flows.
5. After retained adapters are isolated, delete unsupported agent paths in narrow, independently verified commits.

## Verification Strategy

- Documentation-only changes: verify links and Markdown structure manually.
- Test additions or behavior-preserving moves: run `swift test`.
- Overlay/UI changes: run `swift test`, then a focused harness or manual launch when visual behavior matters.
- Hook installation changes: run unit tests plus install/status/uninstall checks against temporary config directories.
- Terminal jump changes: run the relevant terminal-specific tests and manual checks for any strategy touched.

## Risks

- `BridgeServer` extraction can subtly change blocking approval/question behavior if pending response ownership is not preserved.
- `AppModel` slimming can break SwiftUI observation if ownership changes faster than view bindings.
- `IslandPanelView` moves can introduce layout regressions even without logic changes.
- Terminal strategy extraction can regress edge cases that rely on AppleScript or CLI quirks.
- Agent support deletion can affect documented product scope, README claims, settings copy, and hook installers simultaneously.
