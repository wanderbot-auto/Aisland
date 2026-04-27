#!/bin/zsh
# Updates appcast.xml with a new release entry.
#
# Usage:
#   zsh scripts/update-appcast.sh <version> <build_number> <ed_signature> <length> [pub_date]
#
# Example:
#   zsh scripts/update-appcast.sh 1.0.3 10 "abc123==" 9014852
#
# If pub_date is omitted, the current UTC time is used.

set -euo pipefail

if [[ $# -lt 4 ]]; then
    echo "Usage: $0 <version> <build_number> <ed_signature> <length> [pub_date]" >&2
    exit 1
fi

VERSION="$1"
BUILD_NUMBER="$2"
ED_SIGNATURE="$3"
LENGTH="$4"
PUB_DATE="${5:-$(date -u '+%a, %d %b %Y %H:%M:%S +0000')}"
ARCHIVE_NAME="${AISLAND_RELEASE_ARCHIVE_NAME:-Aisland.zip}"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
appcast="$repo_root/appcast.xml"

if [[ ! -f "$appcast" ]]; then
    echo "Error: appcast.xml not found at $appcast" >&2
    exit 1
fi

resolve_github_repo() {
    if [[ -n "${AISLAND_GITHUB_REPO:-}" ]]; then
        echo "$AISLAND_GITHUB_REPO"
        return
    fi

    local remote_url
    remote_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)"
    case "$remote_url" in
        https://github.com/*) remote_url="${remote_url#https://github.com/}" ;;
        git@github.com:*) remote_url="${remote_url#git@github.com:}" ;;
        ssh://git@github.com/*) remote_url="${remote_url#ssh://git@github.com/}" ;;
        *) echo "wanderbot-auto/Aisland"; return ;;
    esac

    echo "${remote_url%.git}"
}

github_repo="$(resolve_github_repo)"
releases_url="${AISLAND_RELEASES_URL:-https://github.com/${github_repo}/releases}"
download_url="${releases_url}/download/v${VERSION}/${ARCHIVE_NAME}"

# Use Python for reliable XML-adjacent text insertion
python3 - "$appcast" "$VERSION" "$BUILD_NUMBER" "$ED_SIGNATURE" "$LENGTH" "$PUB_DATE" "$download_url" "$releases_url" <<'PYEOF'
import re
import sys

appcast_path = sys.argv[1]
version = sys.argv[2]
build_number = sys.argv[3]
ed_signature = sys.argv[4]
length = sys.argv[5]
pub_date = sys.argv[6]
download_url = sys.argv[7]
releases_url = sys.argv[8]

new_item = f"""        <item>
            <title>Version {version}</title>
            <sparkle:version>{build_number}</sparkle:version>
            <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <pubDate>{pub_date}</pubDate>
            <enclosure
                url="{download_url}"
                type="application/octet-stream"
                sparkle:edSignature="{ed_signature}"
                length="{length}"
            />
        </item>"""

with open(appcast_path, "r") as f:
    content = f.read()

if f"<sparkle:shortVersionString>{version}</sparkle:shortVersionString>" in content:
    print(f"Error: version {version} already exists in appcast.xml", file=sys.stderr)
    sys.exit(1)

content, link_rewrites = re.subn(
    r"<link>https://github\.com/[^<]+/releases</link>",
    f"<link>{releases_url}</link>",
    content,
    count=1,
)

if link_rewrites == 0 and "<title>Aisland Updates</title>" in content:
    content = content.replace(
        "<title>Aisland Updates</title>",
        f"<title>Aisland Updates</title>\n        <link>{releases_url}</link>",
        1,
    )

marker_match = re.search(r"<!-- Items are added by the release workflow.*?-->", content)
if marker_match:
    insert_at = marker_match.end()
    content = content[:insert_at] + "\n" + new_item + content[insert_at:]
elif "<item>" in content:
    content = content.replace("<item>", new_item + "\n        <item>", 1)
elif "</channel>" in content:
    content = content.replace("</channel>", new_item + "\n    </channel>", 1)
else:
    print("Error: could not find a safe insertion point in appcast.xml", file=sys.stderr)
    sys.exit(1)

with open(appcast_path, "w") as f:
    f.write(content)
PYEOF

echo "Updated appcast.xml with version ${VERSION} (build ${BUILD_NUMBER})"
