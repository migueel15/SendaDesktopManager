#!/usr/bin/env bash
set -euo pipefail

APP_NAME="senda"
ENTRY="./cmd/senda"
DIST_DIR="dist"

mkdir -p "$DIST_DIR"

echo "Building $APP_NAME..."

go build -o "$DIST_DIR/$APP_NAME" "$ENTRY"

echo "Build completed: $DIST_DIR/$APP_NAME"
