# open-vibe-island

> 我不想在自己的电脑上运行一个闭源、付费的软件来监视我所有的生产过程。<br>
> 所以我 build 了这个开源的版本。<br>
>
> To all vibe coders: 我们自己构建自己的产品。

The open-source macOS companion for terminal-native AI coding.

`open-vibe-island` gives coding agents a native home on your Mac: a lightweight island in the notch or top bar where you can see live sessions, approve actions, answer questions, and jump back to the right terminal without breaking flow.

## Why It Exists

AI coding workflows should stay local, inspectable, and under your control.

This project exists for people who want the convenience of an agent companion app without handing their machine over to a closed-source paid product.

## What The Product Does

- shows live agent activity in a small native macOS surface
- brings pending approvals and questions to the front
- helps you return to the right terminal context quickly
- keeps the CLI as the primary workflow instead of replacing it

## What Makes It Different

- open source
- local first
- native macOS
- built for terminal workflows, not around them

## Current Status

`open-vibe-island` is an early preview, but it is already buildable and usable as a real local prototype.

Current focus:

- macOS only
- Codex first
- approval flow
- session visibility
- jump-back behavior

## What Works Today

Today the project can:

- receive Codex hook events locally
- show session and approval state in the app shell
- install and uninstall managed Codex hooks from `~/.codex`
- record terminal hints for best-effort jump back behavior

## Quick Start

Build and run the app locally:

```bash
swift test
swift build
open Package.swift
```

To connect Codex:

```toml
[features]
codex_hooks = true
```

```bash
swift build -c release --product VibeIslandHooks
swift run VibeIslandSetup install --hooks-binary "$(pwd)/.build/release/VibeIslandHooks"
```

Check or remove the setup later:

```bash
swift run VibeIslandSetup status --hooks-binary "$(pwd)/.build/release/VibeIslandHooks"
swift run VibeIslandSetup uninstall
```

## Product Direction

The goal is simple: make AI coding feel more native on macOS.

That means:

- less tab hunting
- less context loss
- less friction around approvals
- a faster path back to the active agent session

## Roadmap

1. Ship a solid single-agent macOS MVP
2. Harden approvals and jump-back behavior
3. Improve multi-session handling
4. Expand to more agent integrations over time

## Contributing

Issues and pull requests are welcome. If you want to help, prefer small focused changes and keep the product experience as the center of gravity.
