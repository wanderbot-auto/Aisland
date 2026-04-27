# AGENTS

This file defines the working agreement for the coding agent in this repository.

## Goal

Keep all work incremental, reviewable, and reversible. Every meaningful round of changes must end with a Git commit so commits become the control surface for progress, rollback, and review.

## Current Repository Shape

- This checkout is a Swift package named `Aisland` with four products declared in `Package.swift`: `AislandApp`, `AislandCore`, `AislandHooks`, and `AislandSetup`.
- `AislandApp` is the native macOS runtime: menu bar app, notch/top-bar overlay, control center, live session monitoring, temporary chat, settings, white-noise controls, and update checks.
- `AislandCore` holds shared models and runtime code: `AgentSession`, `AgentEvent`, `SessionState`, bridge transport, hook payload parsing, installation helpers, registries, usage tracking, and OpenCode plugin support.
- `AislandHooks` is the lightweight CLI invoked by supported agent hooks. It forwards stdin payloads to the app bridge and only emits blocking stdout directives when the app explicitly denies a tool action.
- `AislandSetup` is the helper CLI for Codex and Claude hook install/uninstall/status flows. OpenCode plugin installation is currently handled from the app via `HookInstallationCoordinator` and `OpenCodePluginInstallationManager`.

## Required Workflow

1. Start each round by checking the current repository state with `git status -sb`.
2. Read the relevant files before editing. Do not guess repository structure or behavior.
3. Keep each round focused on a single coherent change.
4. After making changes, run the most relevant verification available for that round.
5. Summarize what changed, including any verification gaps.
6. Commit the round before stopping.

## Commit Policy

- Every round that modifies files must end with a commit.
- Do not batch unrelated changes into one commit.
- Use clear conventional-style commit messages such as `feat:`, `fix:`, `refactor:`, `docs:`, or `chore:`.
- Do not amend existing commits unless explicitly requested.
- Do not create branches unless explicitly requested.
- When the user explicitly requests parallel work or multiple worktrees, create a dedicated branch for each worktree and keep `main` as the integration branch.

## Safety Rules

- Never revert or overwrite user changes unless explicitly requested.
- If unexpected changes appear, inspect them and work around them when possible.
- If a conflict makes the task ambiguous or risky, stop and ask before proceeding.
- Never use destructive Git commands such as `git reset --hard` without explicit approval.

## Engineering Rules

- Prefer small end-to-end slices over large speculative scaffolding.
- Preserve a clean working tree after each round.
- Add documentation when making architectural or workflow decisions.
- Prefer native macOS and Swift-friendly project structure for this repository.
- Preserve the local-first, fail-open runtime model: if the app or bridge is unavailable, supported agents should continue running.

## Product Scope In This Checkout

- Supported agents: `Claude Code`, `Codex`, `OpenCode`, `General Agent`.
- Current hook/install surfaces:
  - `Codex` via `AislandSetup` and `CodexHookInstallationManager`
  - `Claude Code` via `AislandSetup` and `ClaudeHookInstallationManager`
  - `OpenCode` via the bundled plugin resource and `OpenCodePluginInstallationManager`
- Current jump-back surfaces include `Terminal.app`, `Ghostty`, `iTerm2`, `WezTerm`, `Kaku`, `cmux`, `tmux`, `Zellij`, `Warp`, `Codex.app`, the VS Code family (`VS Code`, `VS Code Insiders`, `Cursor`, `Windsurf`, `Trae`), and JetBrains IDEs.
- Current app features extend beyond session monitoring: the repo also contains temporary multi-provider chat, skill discovery/prompt injection, usage tracking, Sparkle-based updates, and white-noise playback.
- Do not broaden the support boundary unless the user explicitly asks for that scope change.

## Canonical Docs In This Checkout

- Use `DESIGN.md` for the current visual system and product styling direction.
- Use `docs/refactor-plan.md` for the current simplification roadmap and file hotspots.
- Use `docs/extension-architecture.md` for Skills and MCP direction.
- Use `docs/llm-chat-sdk-recommendation.md` for the temporary-chat provider strategy.
- Do not assume `CLAUDE.md`, `README.md`, `docs/product.md`, `docs/architecture.md`, or `docs/worktree-workflow.md` exist in this checkout unless the same round adds or restores them.

## App Targets And Naming

- Treat the repository executable product `AislandApp` as the canonical OSS app runtime.
- Treat `swift run AislandApp` and the Xcode SwiftPM app target as the source-of-truth way to run the current branch's app code.
- Treat `~/Applications/Aisland Dev.app` as a local development bundle wrapper around the repo-built `AislandApp`, not as a separate product line.
- When the user asks to launch or restart `Aisland Dev.app`, refresh the bundle from the current repo first with `zsh scripts/launch-dev-app.sh` instead of only running `open -na`.
- `scripts/launch-dev-app.sh` currently builds `AislandApp`, `AislandHooks`, and `AislandSetup`, optionally installs hooks, copies the resource bundle and `Sparkle.framework`, signs the bundle, and launches `Aisland Dev.app`.
- Use `scripts/harness.sh smoke` or `scripts/smoke-dev-app.sh` for deterministic harness runs.
- Treat any in-app label such as `Aisland OSS` as UI copy only, not as evidence of another app target.

## Reference Baselines

- Official product reference: `https://vibeisland.app/`
- Treat the official site and app as behavior benchmarks for notch placement, compact-vs-expanded island behavior, and overall polish, not as the development runtime for this repository.
- Community implementation reference: `https://github.com/farouqaldori/claude-island`
- Useful ideas to learn from `claude-island` include notch geometry handling, explicit screen selection fallback behavior, and local-first bridge patterns.
- Do not treat `claude-island` as a product spec, and do not import analytics, window-manager-specific scope expansion, or Claude-only assumptions unless the user explicitly asks for them.

## Parallel Worktree Rules

- Use the current checkout at `/Users/wander/Documents/code/apps/Aisland` as the default integration worktree unless the user explicitly asks for isolated parallel work.
- When parallel work is active, create one worktree per branch and one branch per worktree. Never attach two worktrees to the same branch.
- Create new worktrees from `origin/main`, not from a locally drifted feature branch.
- Use sibling worktree paths named like `/Users/wander/Documents/code/apps/Aisland-<topic>`.
- Use branch names that match the workstream, such as `feat/<topic>`, `fix/<topic>`, `docs/<topic>`, or `investigate/<topic>`.
- Keep each worktree focused on one coherent slice with a narrow file ownership area when possible.
- Rebase or merge the latest `origin/main` into the feature branch before integrating it back.
- Remove merged worktrees and delete merged branches after the integration round is complete.
- If multiple agents are working in parallel, assign each agent its own worktree instead of sharing one checkout.

## Verification

- Run targeted checks that match the change.
- Use `swift test` as the default verification for Swift code changes unless a narrower test target is more appropriate.
- Use `swift build` or product-specific builds when package structure, resources, or packaging scripts change.
- Use `zsh scripts/lint-strings.sh` when touching localized strings.
- Use `zsh scripts/smoke-dev-app.sh` or `zsh scripts/harness.sh smoke` when overlay or harness behavior needs runtime verification.
- For docs-only changes, manually verify links and file references. `zsh scripts/check-docs.sh` currently expects a larger docs tree than this checkout contains, so treat missing-file failures there as an existing repo gap unless your round restores those files.
- If no automated verification exists yet, state that explicitly in the final summary and still commit the change.

## Important Files

- `Package.swift` - package products, dependencies, and test targets
- `Sources/AislandApp/AislandApp.swift` - app entry point
- `Sources/AislandApp/AppModel.swift` - central app state and bridge/UI coordination
- `Sources/AislandApp/HookInstallationCoordinator.swift` - app-facing install, status, and repair flows
- `Sources/AislandApp/TerminalJumpService.swift` - jump-back dispatch across terminals and editors
- `Sources/AislandApp/TerminalJumpTargetResolver.swift` - precision jump target enrichment
- `Sources/AislandApp/ActiveAgentProcessDiscovery.swift` - live process discovery
- `Sources/AislandApp/TemporaryChatClient.swift` - provider-agnostic temporary chat runtime
- `Sources/AislandApp/TemporaryChatSkills.swift` - skill discovery and prompt-context injection
- `Sources/AislandCore/SessionState.swift` - reducer for session mutations
- `Sources/AislandCore/BridgeServer.swift` - local bridge command handling and event emission
- `Sources/AislandCore/CodexHooks.swift` - Codex hook payload model
- `Sources/AislandCore/ClaudeHooks.swift` - Claude-compatible hook payload model
- `Sources/AislandCore/OpenCodeHooks.swift` - OpenCode hook payload model
- `Sources/AislandCore/OpenCodePluginInstallationManager.swift` - OpenCode plugin install/status logic
- `Sources/AislandHooks/AislandHooksCLI.swift` - hook CLI entry point
- `Sources/AislandSetup/AislandSetupCLI.swift` - setup CLI entry point

## Default Expectation

Unless the user says otherwise, the agent should finish each completed round in this order:

1. implement
2. verify
3. summarize
4. commit
