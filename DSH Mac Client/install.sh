#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$SCRIPT_DIR/dist/DeepSeek Harness.app"
TARGET="/Applications/DeepSeek Harness.app"
STAGING="/Applications/.DeepSeek Harness.app.installing.$$"
BACKUP="/Applications/.DeepSeek Harness.app.backup.$$"

validate_app() {
  local bundle="$1"
  [[ -f "$bundle/Contents/Info.plist" ]]
  [[ -x "$bundle/Contents/MacOS/DeepSeekHarness" ]]
  [[ -x "$bundle/Contents/Resources/runtime/node/bin/node" ]]
  [[ -f "$bundle/Contents/Resources/runtime/node_modules/@deepseek-ai/dsh/lib/bin.js" ]]
  plutil -lint "$bundle/Contents/Info.plist" >/dev/null
  codesign --verify --deep --strict "$bundle"
}

if [[ ! -d "$APP" ]]; then
  "$SCRIPT_DIR/build.sh"
fi

if ! validate_app "$APP"; then
  echo "Refusing to install: source app is incomplete or invalid: $APP" >&2
  exit 1
fi

cleanup() {
  rm -rf "$STAGING"
}
trap cleanup EXIT

rm -rf "$STAGING" "$BACKUP"
# ditto preserves macOS bundle metadata and fails atomically before replacement.
ditto "$APP" "$STAGING"

if ! validate_app "$STAGING"; then
  echo "Refusing to install: staged app failed verification." >&2
  exit 1
fi

if [[ -e "$TARGET" ]]; then
  mv "$TARGET" "$BACKUP"
fi

if mv "$STAGING" "$TARGET"; then
  rm -rf "$BACKUP"
else
  [[ -e "$BACKUP" ]] && mv "$BACKUP" "$TARGET"
  echo "Installation failed; restored the previous application." >&2
  exit 1
fi

validate_app "$TARGET"
touch "$TARGET"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$TARGET" >/dev/null 2>&1 || true
open -R "$TARGET"
echo "Installed and verified: $TARGET"
