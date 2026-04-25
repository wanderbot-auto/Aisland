# LLM Chat SDK Decision

Aisland is expanding from a single-purpose agent-session monitor into a two-core-feature app:

1. monitor local coding-agent sessions and surface attention/completion states;
2. open the island for short-lived LLM conversations without leaving the current workflow.

## Decision

Use [teunlao/swift-ai-sdk](https://github.com/teunlao/swift-ai-sdk) as the provider-agnostic SDK layer.

The SDK was selected because its API is built around provider-agnostic `generateText` / `streamText` calls while still exposing provider modules for OpenAI, Anthropic, Google, Groq, Mistral, Perplexity, DeepSeek, xAI, Together AI, and OpenAI-compatible endpoints. This matches Aisland's direction: users should choose a model provider in Settings without the island UI depending on one vendor.

## Current integration

- `Package.swift` now depends on `swift-ai-sdk` `from: "0.17.6"`.
- `TemporaryChatClient` builds the selected provider's SDK model, then calls `generateText(model:messages:)`.
- Settings exposes searchable provider cards plus suggested models for each provider.
- API keys remain stored in macOS Keychain.
- Custom and OpenRouter-style providers use `OpenAICompatibleProvider`.

## Provider scope

Initial provider list:

- OpenAI
- Anthropic Claude
- Google Gemini
- OpenRouter
- Groq
- Mistral AI
- Perplexity
- DeepSeek
- xAI
- Together AI
- Custom OpenAI-compatible endpoint

## Follow-up ideas

- Add streaming token updates into the island chat transcript.
- Add provider-specific validation for base URLs and API keys.
- Add a remote model-list fetcher where providers expose a stable model listing API.
