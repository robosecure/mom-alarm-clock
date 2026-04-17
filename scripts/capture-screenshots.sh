#!/bin/bash
# capture-screenshots.sh
#
# Automates App Store screenshot capture by launching the app with each
# -ui-fixture argument (see ios/MomAlarmClock/App/UITestFixture.swift),
# giving the UI time to settle, and writing screenshots to screenshots/.
#
# Requires:
#   - The app installed on the target simulator(s).
#   - UITestFixture.swift compiled in (DEBUG builds only).
#
# Usage:
#   ./scripts/capture-screenshots.sh                     # both device sizes
#   ./scripts/capture-screenshots.sh 6.7                 # only 6.7" shots
#   DEVICE_67=<UDID> DEVICE_61=<UDID> ./scripts/capture-screenshots.sh
#
# Override device UDIDs via env vars if you want different simulators.

set -eu

BUNDLE_ID="com.momclock.MomAlarmClock"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$REPO_ROOT/screenshots"
PROJECT="$REPO_ROOT/ios/MomAlarmClock.xcodeproj"
SCHEME="MomAlarmClock"

# Default device UDIDs — override via env if needed.
# Find yours with: xcrun simctl list devices available
DEVICE_67="${DEVICE_67:-}"
DEVICE_61="${DEVICE_61:-}"

# Auto-pick if not set. Prefer iPhone 17 Pro Max / iPhone 17 Pro (present on this machine).
if [ -z "$DEVICE_67" ]; then
  DEVICE_67=$(xcrun simctl list devices available | \
    awk '/iPhone 17 Pro Max|iPhone 16 Pro Max/ {match($0, /\(([-A-F0-9]+)\)/, a); if (a[1]) { print a[1]; exit }}')
fi
if [ -z "$DEVICE_61" ]; then
  DEVICE_61=$(xcrun simctl list devices available | \
    awk '/iPhone 17 Pro \(|iPhone 16 Pro \(/ {match($0, /\(([-A-F0-9]+)\)/, a); if (a[1]) { print a[1]; exit }}')
fi

if [ -z "$DEVICE_67" ] && [ -z "$DEVICE_61" ]; then
  echo "ERROR: Could not find any iPhone Pro / Pro Max simulator. Set DEVICE_67 / DEVICE_61 env vars." >&2
  exit 1
fi

# Fixture list: (fixture name, output file suffix, human label, settle seconds)
# Order matches SCREENSHOT_PLAN.md priority.
FIXTURES=(
  "dashboard|01_guardian_dashboard|Guardian Dashboard (hero)|2"
  "activeAlarm|02_child_alarm_firing|Child Alarm Firing|2"
  "activeQuiz|03_quiz_verification|Quiz Verification|2"
  "trustResult|04_trust_mode_result|Trust Mode Result|2"
  "voiceAlarm|05_voice_alarm|Voice Alarm Recording|2"
  "dashboard|06_privacy_data|Privacy & Data|2"
  "alarmSettings|07_alarm_settings|Alarm Settings (Advanced)|2"
  "pendingReview|08_pending_review|Pending Review (Strict)|2"
)

ensure_booted() {
  local udid="$1"
  local state
  state=$(xcrun simctl list devices | awk -v u="$udid" '$0 ~ u {match($0, /\((Booted|Shutdown)\)/, a); print a[1]; exit}')
  if [ "$state" != "Booted" ]; then
    echo "  -> booting $udid ..."
    xcrun simctl boot "$udid" 2>/dev/null || true
    # open Simulator.app so the screen is actually rendering
    open -a Simulator --args -CurrentDeviceUDID "$udid" || true
    # poll for Booted
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      sleep 1
      state=$(xcrun simctl list devices | awk -v u="$udid" '$0 ~ u {match($0, /\((Booted|Shutdown)\)/, a); print a[1]; exit}')
      [ "$state" = "Booted" ] && break
    done
  fi
}

ensure_installed() {
  local udid="$1"
  local app_path
  # Look for the built .app in DerivedData first.
  app_path=$(find "$HOME/Library/Developer/Xcode/DerivedData" \
    -type d -name "MomAlarmClock.app" -path "*Debug-iphonesimulator*" 2>/dev/null | head -1)
  if [ -z "$app_path" ]; then
    echo "  -> building app for simulator..."
    (cd "$REPO_ROOT/ios" && xcodebuild \
      -project MomAlarmClock.xcodeproj \
      -scheme MomAlarmClock \
      -configuration Debug \
      -destination "platform=iOS Simulator,id=$udid" \
      -derivedDataPath build \
      CODE_SIGNING_ALLOWED=NO \
      build >/tmp/mom_screenshot_build.log 2>&1) || {
        echo "BUILD FAILED — see /tmp/mom_screenshot_build.log" >&2
        exit 1
      }
    app_path=$(find "$REPO_ROOT/ios/build" -type d -name "MomAlarmClock.app" \
      -path "*Debug-iphonesimulator*" 2>/dev/null | head -1)
  fi
  if [ -z "$app_path" ]; then
    echo "ERROR: Could not locate built MomAlarmClock.app" >&2
    exit 1
  fi
  xcrun simctl install "$udid" "$app_path" >/dev/null
  echo "  -> installed app from $app_path"
}

capture_for_device() {
  local udid="$1"
  local size_label="$2"      # e.g. 67, 61
  local size_suffix="$3"     # filename suffix, e.g. _6.7 or _6.1

  echo ""
  echo "=========================================="
  echo " Device: $size_label ($udid)"
  echo "=========================================="

  ensure_booted "$udid"
  ensure_installed "$udid"

  mkdir -p "$OUT_DIR/$size_label"

  for entry in "${FIXTURES[@]}"; do
    IFS='|' read -r fixture suffix label settle <<<"$entry"
    out="$OUT_DIR/$size_label/${suffix}${size_suffix}.png"

    echo ""
    echo " -> $label (fixture: $fixture) -> $out"

    # Uninstall/reinstall wipes Documents so LocalStore is fresh each fixture.
    xcrun simctl uninstall "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    ensure_installed "$udid" >/dev/null

    xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$udid" "$BUNDLE_ID" -ui-fixture "$fixture" >/dev/null

    # Let SwiftUI settle. activeAlarm/activeQuiz need a beat for animations.
    sleep "$settle"

    xcrun simctl io "$udid" screenshot --type=png "$out"
    echo "    saved: $(du -h "$out" | awk '{print $1}')"
  done
}

echo "Mom Alarm Clock — App Store Screenshot Capture"
echo "Output: $OUT_DIR"
mkdir -p "$OUT_DIR"

FILTER="${1:-}"   # optional "6.7" or "6.1"

if [ -n "$DEVICE_67" ] && { [ -z "$FILTER" ] || [ "$FILTER" = "6.7" ]; }; then
  capture_for_device "$DEVICE_67" "6.7" "_6.7"
fi
if [ -n "$DEVICE_61" ] && { [ -z "$FILTER" ] || [ "$FILTER" = "6.1" ]; }; then
  capture_for_device "$DEVICE_61" "6.1" "_6.1"
fi

echo ""
echo "Done. Review at: $OUT_DIR"
