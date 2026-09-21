#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/images"
UDID="${SIM_UDID:-E7B8A71E-A80B-47E2-9347-2B2EF207C03C}"
BUNDLE="app.ferrum.ios"
DERIVED="$ROOT/.screenshot-derived"

mkdir -p "$OUT"

echo "==> Building Ferrum"
xcodebuild \
  -project "$ROOT/Ferrum.xcodeproj" \
  -scheme Ferrum \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build

APP="$DERIVED/Build/Products/Debug-iphonesimulator/Ferrum.app"
if [[ ! -d "$APP" ]]; then
  echo "Ferrum.app not found at $APP" >&2
  exit 1
fi

echo "==> Booting simulator $UDID"
open -a Simulator
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
sleep 2

echo "==> Installing $APP"
xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3 2>/dev/null || true

capture() {
  local tab="$1"
  local name="$2"
  echo "==> Capturing $name ($tab)"
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" -demoScreenshots -demoTab "$tab"
  sleep 4
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png"
}

capture today ferrum-dashboard
capture log ferrum-logger
capture analytics ferrum-analytics

rm -f "$OUT"/ferrum-*.jpg "$OUT"/ferrum-hero.png

echo "==> Done. Screenshots in $OUT"
ls -la "$OUT"
