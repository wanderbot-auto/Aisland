# Aisland Extension Architecture

## Decision

Aisland supports agent extensions as two complementary layers:

- **Skills** provide local, read-only Markdown guidance for workflows, project rules, examples, and prompt templates.
- **MCP** will provide executable connectors to external tools, data sources, and system services.

They are intentionally separate. Skills answer "how should the model do this?" while MCP answers "what external data or action can Aisland safely provide?"

## Current Slice: Skills v1

The first implemented slice is local Skills discovery and prompt injection for temporary chat:

- Aisland discovers `SKILL.md` files under `.codex/skills` and `.agents/skills`.
- Source priority is repository, then project, then user.
- Duplicate skill IDs keep the highest-priority definition.
- Matching Skills are selected from the current chat turn and injected as a system message.
- The app emits a lightweight `skills` tool-result summary so the UI can show which Skills affected the turn.
- Skills are read-only text. Aisland does not execute scripts referenced by a Skill.

This keeps Skills compatible with OpenAI-compatible and local models that do not support tool calling.

## Next Slices

- **SearchService fallback:** continue expanding Aisland's built-in web-search router so providers without native browsing can receive pre-search context.
- **MCP host:** add configured MCP servers as an approval-gated tool layer, starting with read-only tools such as search, URL fetch, GitHub, Figma, and filesystem read.
- **Skills + MCP linking:** allow a Skill to recommend related MCP servers while keeping execution behind Aisland approval policy.

## Safety Defaults

- Skills are local-only and read-only.
- Skills are instructions, not executable plugins.
- MCP write tools should require explicit approval.
- Web search must keep model API keys separate from search-provider API keys and show source citations when search is used.
