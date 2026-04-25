# LLM Chat SDK Recommendation

Aisland is expanding from a single-purpose agent-session monitor into a two-core-feature app:

1. monitor local coding-agent sessions and surface attention/completion states;
2. open the island for short-lived LLM conversations without leaving the current workflow.

## Current implementation slice

- `Control + Option + Space` opens the island directly into temporary chat.
- Settings now has an **AI Chat** pane for provider, model, base URL, and API key.
- API keys are stored in macOS Keychain.
- The temporary client currently supports OpenAI-compatible chat completions, Anthropic Messages, Gemini `generateContent`, and OpenRouter via direct `URLSession` calls.

This keeps the app usable while leaving the final SDK choice reversible.

## GitHub SDK survey

Collected on 2026-04-25 with the GitHub repository API.

| Candidate | Stars | License | Updated | Notes |
| --- | ---: | --- | --- | --- |
| [MacPaw/OpenAI](https://github.com/MacPaw/OpenAI) | 2,894 | MIT | 2026-04-25 | Highest-star Swift OpenAI client found; good default if we choose OpenAI-first. |
| [adamrushy/OpenAISwift](https://github.com/adamrushy/OpenAISwift) | 1,708 | MIT | 2026-04-24 | Mature OpenAI wrapper, but narrower than a multi-provider chat strategy. |
| [OpenDive/OpenAIKit](https://github.com/OpenDive/OpenAIKit) | 273 | MIT | 2026-04-21 | Smaller OpenAI-only package. |
| [SwiftBeta/SwiftOpenAI](https://github.com/SwiftBeta/SwiftOpenAI) | 247 | MIT | 2026-03-26 | Smaller OpenAI-only package. |
| [PreternaturalAI/AI](https://github.com/PreternaturalAI/AI) | 225 | MIT | 2026-04-15 | Multi-provider generative-AI framework; promising for app-level abstraction. |
| [teunlao/swift-ai-sdk](https://github.com/teunlao/swift-ai-sdk) | 125 | Apache-2.0 | 2026-04-22 | Unified Swift SDK inspired by Vercel AI SDK; best match for provider-agnostic chat if we accept lower stars. |
| [GeorgeLyon/SwiftClaude](https://github.com/GeorgeLyon/SwiftClaude) | 73 | MIT | 2026-04-24 | Anthropic-focused SDK; useful only if Claude becomes the primary provider. |
| [fumito-ito/AnthropicSwiftSDK](https://github.com/fumito-ito/AnthropicSwiftSDK) | 18 | Apache-2.0 | 2026-02-12 | Anthropic-only and low adoption. |

## Recommendation

Default recommendation: **teunlao/swift-ai-sdk** if Aisland wants the temporary-chat feature to support mainstream providers with one abstraction. It is lower-star than OpenAI-only packages, so we should keep the current in-house `TemporaryChatClient` as a fallback until the SDK proves stable in tests.

Conservative alternative: **MacPaw/OpenAI** if we want the highest-adoption Swift package and are comfortable making OpenAI-compatible providers the first-class path, then add native Claude/Gemini adapters later.

Avoid for now: adding separate provider-specific SDKs for every vendor. That would raise dependency surface area before the chat UX and settings model stabilize.

## Proposed next integration step

After choosing the SDK, replace `TemporaryChatClient` behind the existing `LLMChatConfiguration` and `TemporaryChatMessage` boundary. The island UI and settings pane should not need a large rewrite.
