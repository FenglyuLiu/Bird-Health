#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="DeepSeek Harness.app"
APP_DIR="$SCRIPT_DIR/dist/$APP_NAME"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
RUNTIME="$RESOURCES/runtime"

DSH_SOURCE="${DSH_SOURCE:-/Users/liufenglyu/.npm/_npx/1e7f6d9597241db0}"
NODE_VERSION="22.22.0"
NODE_ARCHIVE="$SCRIPT_DIR/.cache/node-v${NODE_VERSION}-darwin-arm64.tar.gz"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-darwin-arm64.tar.gz"

if [[ ! -f "$DSH_SOURCE/package.json" || ! -d "$DSH_SOURCE/node_modules" ]]; then
  echo "DSH source runtime not found: $DSH_SOURCE" >&2
  exit 1
fi

mkdir -p "$SCRIPT_DIR/.cache"
if [[ ! -f "$NODE_ARCHIVE" ]]; then
  echo "Downloading standalone Node.js ${NODE_VERSION}…"
  curl -fL "$NODE_URL" -o "$NODE_ARCHIVE"
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES" "$RUNTIME"

xcrun clang \
  -fobjc-arc \
  -O2 \
  -framework Cocoa \
  -framework WebKit \
  "$SCRIPT_DIR/DeepSeekHarnessApp.m" \
  -o "$MACOS/DeepSeekHarness"

cp "$SCRIPT_DIR/Info.plist" "$CONTENTS/Info.plist"
cp "$SCRIPT_DIR/AppIcon.icns" "$RESOURCES/AppIcon.icns"

# Bundle the official self-contained Node distribution (bin + required share files).
NODE_TMP="$(mktemp -d)"
trap 'rm -rf "$NODE_TMP"' EXIT
tar -xzf "$NODE_ARCHIVE" -C "$NODE_TMP"
mkdir -p "$RUNTIME/node"
mkdir -p "$RUNTIME/node/bin"
cp "$NODE_TMP/node-v${NODE_VERSION}-darwin-arm64/bin/node" "$RUNTIME/node/bin/node"
cp "$NODE_TMP/node-v${NODE_VERSION}-darwin-arm64/LICENSE" "$RUNTIME/node/LICENSE"

# Bundle the complete resolved DSH dependency tree. Symlinks are preserved.
cp "$DSH_SOURCE/package.json" "$RUNTIME/package.json"
cp -R "$DSH_SOURCE/node_modules" "$RUNTIME/node_modules"

chmod +x "$MACOS/DeepSeekHarness" "$RUNTIME/node/bin/node"

# Sign nested native binaries first, then seal the application bundle.
find "$RUNTIME/node_modules" -type f \( -name '*.node' -o -perm -111 \) -print0 | while IFS= read -r -d '' binary; do
  file "$binary" | grep -q 'Mach-O' && codesign --force --sign - "$binary" || true
done
codesign --force --sign - "$RUNTIME/node/bin/node"
# Remove copied provenance metadata before sealing the final bundle.
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"

echo "Built standalone app: $APP_DIR"
du -sh "$APP_DIR"
