#!/usr/bin/env bash
# Writes the latest.json manifest of a release: its tag and, newest first, the
# commit subjects of the recent releases of the same channel. Senda reads it
# from the release download URLs, which avoid the GitHub API rate limit.
#
# Usage: release-manifest.sh <tag> <previous-manifest-url> <output-file>
#   Run from a full clone (fetch-depth 0) with HEAD at the released commit.
#   When the previous manifest is missing, the commits since the previous
#   vX.Y.Z tag (or only HEAD) are listed.
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <tag> <previous-manifest-url> <output-file>" >&2
  exit 1
fi

TAG="$1"
PREVIOUS_URL="$2"
OUTPUT="$3"
KEEP=50

previous=$(curl --proto '=https' --tlsv1.2 -fsSL "$PREVIOUS_URL" 2>/dev/null || true)
if ! jq -e '.releases | type == "array"' >/dev/null 2>&1 <<<"$previous"; then
  previous='{"releases":[]}'
fi

previous_sha=$(jq -r '.releases[0].sha // empty' <<<"$previous")
if [[ -n "$previous_sha" ]] && git cat-file -e "${previous_sha}^{commit}" 2>/dev/null; then
  range="${previous_sha}..HEAD"
elif previous_tag=$(git describe --tags --abbrev=0 --match 'v[0-9]*' HEAD^ 2>/dev/null); then
  range="${previous_tag}..HEAD"
else
  range="-1"
fi

git log --format=%s $range \
  | jq -R . | jq -s . \
  | jq --arg tag "$TAG" --arg sha "$(git rev-parse HEAD)" --argjson previous "$previous" --argjson keep "$KEEP" \
    '{tag: $tag, releases: ([{tag: $tag, sha: $sha, commits: .}] + $previous.releases)[:$keep]}' \
  > "$OUTPUT"
