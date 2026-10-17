#!/usr/bin/env bash
# Builds the release assets for a Senda tag:
#   senda-<tag>-linux-amd64           static Linux binary
#   senda-quickshell-<tag>.tar.gz     Quickshell UI, Discord bridge and version file
#   checksums.txt                     sha256 checksums of both files above
#
# Usage: package-release.sh <tag> <output-dir>
#   <tag> must look like vX.Y.Z (for example v0.1.0).
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <tag> <output-dir>" >&2
  exit 1
fi

TAG="$1"
OUTPUT_ARG="$2"

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid tag '$TAG': expected format vX.Y.Z" >&2
  exit 1
fi

# Resolve paths from the script location so it works from any directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$CORE_DIR/.." && pwd)"

mkdir -p "$OUTPUT_ARG"
OUT_DIR="$(cd "$OUTPUT_ARG" && pwd)"

BINARY_NAME="senda-$TAG-linux-amd64"
TARBALL_NAME="senda-quickshell-$TAG.tar.gz"

STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT

# 1. Static binary. The version is injected at link time.
echo "Building $BINARY_NAME..."
(
  cd "$CORE_DIR"
  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags "-X github.com/migueel15/SendaDesktopManager/core/internal/version.Version=$TAG" \
    -o "$OUT_DIR/$BINARY_NAME" \
    ./cmd/senda
)

# 2. Quickshell tarball, assembled in a staging directory so the repo is never
#    archived directly and no other files from the repo root are included.
echo "Packaging $TARBALL_NAME..."
cp -a "$REPO_ROOT/quickshell" "$STAGE_DIR/quickshell"
mkdir "$STAGE_DIR/scripts"
cp "$CORE_DIR/scripts/discord-bridge.py" "$STAGE_DIR/scripts/discord-bridge.py"
printf '%s\n' "$TAG" > "$STAGE_DIR/version"
tar -czf "$OUT_DIR/$TARBALL_NAME" -C "$STAGE_DIR" quickshell scripts version

# 3. Checksums, computed from inside the output directory so names have no path.
echo "Writing checksums.txt..."
(
  cd "$OUT_DIR"
  sha256sum "$BINARY_NAME" "$TARBALL_NAME" > checksums.txt
)

echo "Release assets written to $OUT_DIR"
