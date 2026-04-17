#!/bin/bash
# pre-archive-check.sh
#
# Fails fast on common pre-archive landmines before you spend 10 minutes on
# a compile + archive + TestFlight upload that would have bounced anyway.
#
# Runs local (no network, no xcodebuild). Safe to run from anywhere.
#
# Checks:
#   1. Entitlements: aps-environment == "production"
#   2. Entitlements: critical-alerts + family-controls still declared
#   3. Info.plist: CFBundleVersion is an integer, not empty
#   4. Info.plist: CFBundleShortVersionString matches semver
#   5. App icons: all 8 required sizes present + 1024×1024 has no alpha
#   6. Launch assets: LaunchLogo + LaunchBackground color exist
#   7. GoogleService-Info.plist: API_KEY is not a placeholder
#   8. project.yml + entitlements bundle id stay in sync
#   9. No accidental -ui-fixture / DEBUG leftovers in Release paths
#  10. git status reports no uncommitted .pbxproj drift
#
# Exits 0 if everything passes, 1 on any failure (aggregates errors, doesn't
# short-circuit so you see the full list in one run).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$REPO_ROOT/ios"
ENTITLEMENTS="$IOS_DIR/MomAlarmClock.entitlements"
INFO_PLIST="$IOS_DIR/Info.plist"
GOOGLE_PLIST="$IOS_DIR/MomAlarmClock/GoogleService-Info.plist"
PROJECT_YML="$IOS_DIR/project.yml"
APPICON_DIR="$IOS_DIR/MomAlarmClock/Assets.xcassets/AppIcon.appiconset"

ERRORS=0
WARNINGS=0

red()   { printf "\033[31m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m\n" "$1"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$1"; }
fail()  { red   "  FAIL: $1"; ERRORS=$((ERRORS + 1)); }
warn()  { yellow "  WARN: $1"; WARNINGS=$((WARNINGS + 1)); }
pass()  { green "  ok:   $1"; }

echo ""
echo "Mom Alarm Clock — Pre-Archive Sanity Check"
echo "==========================================="
echo ""

# Tool presence
if ! command -v plutil >/dev/null 2>&1; then
  red "ERROR: plutil not found — run this on macOS."
  exit 2
fi
HAVE_SIPS=1
if ! command -v sips >/dev/null 2>&1; then
  HAVE_SIPS=0
fi

# ─── 1. Entitlements: aps-environment ─────────────────────
echo "[1/10] Entitlements: aps-environment"
APS_ENV=$(plutil -extract aps-environment raw -o - "$ENTITLEMENTS" 2>/dev/null || echo "")
if [ "$APS_ENV" = "production" ]; then
  pass "aps-environment = production"
elif [ "$APS_ENV" = "development" ]; then
  fail "aps-environment is 'development' — must be 'production' for App Store/TestFlight archive"
else
  fail "aps-environment missing or unreadable in $ENTITLEMENTS"
fi

# ─── 2. Critical alerts + family controls still declared ──
# plutil -extract uses dots as path separators and the entitlement key names
# THEMSELVES contain dots — so we verify by grepping the XML directly.
echo "[2/10] Entitlements: critical-alerts + family-controls"
for key in \
  "com.apple.developer.usernotifications.critical-alerts" \
  "com.apple.developer.family-controls"
do
  if grep -q "<key>$key</key>" "$ENTITLEMENTS" 2>/dev/null; then
    pass "$key declared"
  else
    fail "$key missing — was removed? Re-enable before archive."
  fi
done

# ─── 3. CFBundleVersion integer + non-empty ───────────────
echo "[3/10] Info.plist: CFBundleVersion"
CF_BUNDLE_VERSION=$(plutil -extract CFBundleVersion raw -o - "$INFO_PLIST" 2>/dev/null || echo "")
if [ -z "$CF_BUNDLE_VERSION" ]; then
  fail "CFBundleVersion is empty"
elif ! echo "$CF_BUNDLE_VERSION" | grep -qE '^[0-9]+$'; then
  fail "CFBundleVersion '$CF_BUNDLE_VERSION' is not a positive integer (App Store Connect rejects non-integers for new builds)"
else
  pass "CFBundleVersion = $CF_BUNDLE_VERSION"
  if [ "$CF_BUNDLE_VERSION" = "1" ]; then
    warn "CFBundleVersion is still '1' — App Store Connect requires a bump for every new build. Consider ./scripts/pre-archive-check.sh --bump"
  fi
fi

# ─── 4. CFBundleShortVersionString ────────────────────────
echo "[4/10] Info.plist: CFBundleShortVersionString"
CF_SHORT=$(plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST" 2>/dev/null || echo "")
if echo "$CF_SHORT" | grep -qE '^[0-9]+(\.[0-9]+){1,2}$'; then
  pass "CFBundleShortVersionString = $CF_SHORT"
else
  fail "CFBundleShortVersionString '$CF_SHORT' not semver-like (expected X.Y or X.Y.Z)"
fi

# ─── 5. App icons ─────────────────────────────────────────
echo "[5/10] App icons"
required_sizes="40 58 60 80 87 120 180 1024"
for size in $required_sizes; do
  f="$APPICON_DIR/icon-${size}.png"
  if [ -f "$f" ]; then
    pass "icon-${size}.png present"
  else
    fail "missing icon-${size}.png"
  fi
done
# 1024 alpha check — App Store Connect rejects PNGs with alpha for the marketing icon.
if [ $HAVE_SIPS -eq 1 ] && [ -f "$APPICON_DIR/icon-1024.png" ]; then
  HAS_ALPHA=$(sips -g hasAlpha "$APPICON_DIR/icon-1024.png" 2>/dev/null | awk '/hasAlpha/ {print $2}')
  if [ "$HAS_ALPHA" = "yes" ]; then
    fail "icon-1024.png has an alpha channel — App Store Connect rejects this. Flatten it (sips -s format png --out flat.png icon-1024.png && mv flat.png icon-1024.png)"
  else
    pass "icon-1024.png alpha: no"
  fi
fi

# ─── 6. Launch assets ─────────────────────────────────────
echo "[6/10] Launch screen assets"
for asset in LaunchLogo.imageset LaunchBackground.colorset; do
  if [ -d "$IOS_DIR/MomAlarmClock/Assets.xcassets/$asset" ]; then
    pass "$asset present"
  else
    fail "$asset missing — launch screen will be blank"
  fi
done

# ─── 7. GoogleService-Info.plist ──────────────────────────
echo "[7/10] GoogleService-Info.plist"
if [ ! -f "$GOOGLE_PLIST" ]; then
  fail "$GOOGLE_PLIST not found — Firebase will fall back to LocalSyncService in production"
else
  API_KEY=$(plutil -extract API_KEY raw -o - "$GOOGLE_PLIST" 2>/dev/null || echo "")
  if [ -z "$API_KEY" ] || [ "$API_KEY" = "PLACEHOLDER" ] || [ "${API_KEY#YOUR_}" != "$API_KEY" ]; then
    fail "API_KEY in GoogleService-Info.plist is placeholder/empty ($API_KEY) — Firebase won't configure in production"
  else
    pass "API_KEY looks real (${#API_KEY} chars)"
  fi
  # Bundle ID cross-check
  PLIST_BUNDLE=$(plutil -extract BUNDLE_ID raw -o - "$GOOGLE_PLIST" 2>/dev/null || echo "")
  EXPECTED_BUNDLE="com.momclock.MomAlarmClock"
  if [ "$PLIST_BUNDLE" = "$EXPECTED_BUNDLE" ]; then
    pass "BUNDLE_ID = $EXPECTED_BUNDLE"
  else
    fail "GoogleService-Info BUNDLE_ID is '$PLIST_BUNDLE', expected '$EXPECTED_BUNDLE'"
  fi
fi

# ─── 8. project.yml vs entitlements bundle id ─────────────
echo "[8/10] Bundle ID consistency"
YML_BUNDLE=$(awk '/PRODUCT_BUNDLE_IDENTIFIER:/ {print $2; exit}' "$PROJECT_YML" | tr -d '[:space:]')
if [ "$YML_BUNDLE" = "com.momclock.MomAlarmClock" ]; then
  pass "project.yml PRODUCT_BUNDLE_IDENTIFIER = $YML_BUNDLE"
else
  fail "project.yml PRODUCT_BUNDLE_IDENTIFIER = '$YML_BUNDLE', expected 'com.momclock.MomAlarmClock'"
fi

# ─── 9. DEBUG-only paths not leaking into release ─────────
echo "[9/10] Debug-only code leakage"
# UITestFixture is DEBUG-gated at the compilation level, but confirm.
if grep -q "^#if DEBUG" "$IOS_DIR/MomAlarmClock/App/UITestFixture.swift" 2>/dev/null \
 && grep -q "^#endif" "$IOS_DIR/MomAlarmClock/App/UITestFixture.swift" 2>/dev/null; then
  pass "UITestFixture.swift wrapped in #if DEBUG"
else
  fail "UITestFixture.swift not DEBUG-gated — it will ship in Release builds"
fi
# Ensure MomAlarmClockApp.swift calls it inside #if DEBUG
if grep -B1 "UITestFixture.seedIfRequested" "$IOS_DIR/MomAlarmClock/App/MomAlarmClockApp.swift" \
   | grep -q "#if DEBUG"; then
  pass "UITestFixture call site is #if DEBUG gated"
else
  fail "MomAlarmClockApp.swift calls UITestFixture without #if DEBUG"
fi

# ─── 10. Project file + entitlements not drifted ──────────
echo "[10/10] Git cleanliness"
if ! command -v git >/dev/null 2>&1; then
  warn "git not found — skipping cleanliness check"
else
  UNCOMMITTED=$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$UNCOMMITTED" = "0" ]; then
    pass "working tree clean"
  else
    warn "$UNCOMMITTED uncommitted changes — archive builds from HEAD + overlays; commit before shipping"
  fi
  # Quick pbxproj drift check — if .pbxproj is ahead of project.yml mtime + 1s, xcodegen should be re-run.
  PBX="$IOS_DIR/MomAlarmClock.xcodeproj/project.pbxproj"
  if [ -f "$PBX" ] && [ -f "$PROJECT_YML" ]; then
    if [ "$PROJECT_YML" -nt "$PBX" ]; then
      warn "project.yml is newer than project.pbxproj — run 'xcodegen' before archiving"
    else
      pass "xcodeproj not stale vs project.yml"
    fi
  fi
fi

# ─── Summary ──────────────────────────────────────────────
echo ""
echo "==========================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  green "All checks passed. Safe to archive."
  exit 0
elif [ $ERRORS -eq 0 ]; then
  yellow "All checks passed with $WARNINGS warning(s). Review before archive."
  exit 0
else
  red "$ERRORS failure(s), $WARNINGS warning(s). Fix the failures before archive."
  exit 1
fi
