#!/usr/bin/env bash
set -euo pipefail

APP_NAME="senda"
ENTRY="./cmd/senda"
DIST_DIR="dist"
VERSION="${VERSION:-dev}"
VERSION_PKG="github.com/migueel15/SendaDesktopManager/core/internal/version"

mkdir -p "$DIST_DIR"

echo "Building $APP_NAME ($VERSION)..."

go build -ldflags "-X ${VERSION_PKG}.Version=${VERSION}" -o "$DIST_DIR/$APP_NAME" "$ENTRY"

echo "Build completed: $DIST_DIR/$APP_NAME"
