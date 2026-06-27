#!/bin/bash
# Build, install, launch Multiplication Adventure on an iPad simulator, and screenshot.
# Run this AFTER a reboot if `simctl` was hanging (stale CoreSimulator).
set -e
cd "$(dirname "$0")/.."

SIM_NAME="${1:-iPad Pro 11-inch (M4)}"
BUNDLE_ID="com.levelup.adventure"
SHOT="${2:-/tmp/adventure.png}"

echo "→ Regenerating project"; xcodegen generate >/dev/null

UDID=$(xcrun simctl list devices available | grep -F "$SIM_NAME" | head -1 | grep -oE '[0-9A-F-]{36}')
[ -z "$UDID" ] && { echo "No sim matching '$SIM_NAME'"; xcrun simctl list devices available | grep -i ipad; exit 1; }
echo "→ Sim: $SIM_NAME ($UDID)"

echo "→ Building"
xcodebuild -project LevelUpMath.xcodeproj -scheme LevelUpMath -sdk iphonesimulator \
  -destination "id=$UDID" -derivedDataPath build build >/dev/null

APP=$(find build -name "LevelUpMath.app" -path "*Debug-iphonesimulator*" | head -1)
xcrun simctl boot "$UDID" 2>/dev/null || true
sleep 3
xcrun simctl install "$UDID" "$APP"
# Optional first arg passthrough: -autostartSession / -autostartParent
xcrun simctl launch "$UDID" "$BUNDLE_ID" "${@:3}"
sleep 4
xcrun simctl io "$UDID" screenshot "$SHOT"
echo "→ Screenshot: $SHOT"
