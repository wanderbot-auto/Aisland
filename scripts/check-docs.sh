#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

required_files=(
    "AGENTS.md"
    "DESIGN.md"
    "docs/extension-architecture.md"
    "docs/llm-chat-sdk-recommendation.md"
    "docs/refactor-plan.md"
)

for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "missing required file: $file" >&2
        exit 1
    fi
done

has_required_heading() {
    local file="$1"

    if grep -qE '^# ' "$file"; then
        return 0
    fi

    # Some design documents start with front matter and then use lower-level
    # headings for the narrative body.
    if grep -qE '^---$' "$file" && grep -qE '^##+ ' "$file"; then
        return 0
    fi

    return 1
}

while IFS= read -r file; do
    if ! has_required_heading "$file"; then
        echo "missing required heading structure: $file" >&2
        exit 1
    fi
done < <(printf '%s\n' "AGENTS.md" "DESIGN.md" && find docs -name '*.md' -type f | sort)

while IFS= read -r file; do
    if ! grep -Fq "$file" AGENTS.md; then
        echo "AGENTS.md should reference: $file" >&2
        exit 1
    fi
done < <(find docs -name '*.md' -type f | sort)

if ! grep -Fq "DESIGN.md" AGENTS.md; then
    echo "AGENTS.md should reference: DESIGN.md" >&2
    exit 1
fi

echo "docs check passed"
