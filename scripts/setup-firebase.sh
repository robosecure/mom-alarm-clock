#!/usr/bin/env bash
set -euo pipefail

# ─── Mom Alarm Clock — Firebase + Apple Setup Script ───
# Run this AFTER you have:
#   1. A Google account (free)
#   2. An Apple Developer Program membership ($99/year, takes 24-48h to approve)
#
# This script handles:
#   - Firebase project creation
#   - GoogleService-Info.plist generation
#   - Firebase Auth provider enablement
#   - Firestore/Storage/Functions deployment
#   - Team ID + bundle ID configuration
#
# Usage:
#   chmod +x scripts/setup-firebase.sh
#   ./scripts/setup-firebase.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IOS_DIR="$PROJECT_ROOT/ios"

echo ""
echo "══════════════════════════════════════════════════"
echo "  Mom Alarm Clock — Firebase + Apple Setup"
echo "══════════════════════════════════════════════════"
echo ""

# ─── Step 1: Firebase Login ──────────────────────────

echo "Step 1/8: Firebase Authentication"
echo "─────────────────────────────────"
if firebase projects:list &>/dev/null; then
    echo "Already logged in to Firebase."
else
    echo "Opening browser for Firebase login..."
    firebase login
fi
echo ""

# ─── Step 2: Create or Select Firebase Project ───────

echo "Step 2/8: Firebase Project"
echo "──────────────────────────"
echo "Your existing Firebase projects:"
firebase projects:list 2>/dev/null || true
echo ""

read -p "Enter your Firebase Project ID (or 'new' to create one): " FIREBASE_PROJECT_ID

if [ "$FIREBASE_PROJECT_ID" = "new" ]; then
    read -p "Choose a project ID (e.g., mom-alarm-clock-prod): " FIREBASE_PROJECT_ID
    read -p "Choose a display name (e.g., Mom Alarm Clock): " FIREBASE_DISPLAY_NAME
    firebase projects:create "$FIREBASE_PROJECT_ID" --display-name "$FIREBASE_DISPLAY_NAME"
    echo "Project created: $FIREBASE_PROJECT_ID"
fi

# Set as active project
echo "{\"projects\":{\"default\":\"$FIREBASE_PROJECT_ID\"}}" > "$PROJECT_ROOT/.firebaserc"
echo "Set active project: $FIREBASE_PROJECT_ID"
echo ""

# ─── Step 3: Register iOS App + Download Config ──────

echo "Step 3/8: iOS App Registration"
echo "──────────────────────────────"
BUNDLE_ID="com.momclock.MomAlarmClock"
APP_DISPLAY_NAME="Mom Alarm Clock"

echo "Registering iOS app with bundle ID: $BUNDLE_ID"

# Check if app already exists
EXISTING_APP=$(firebase apps:list --project "$FIREBASE_PROJECT_ID" 2>/dev/null | grep "$BUNDLE_ID" || true)
if [ -n "$EXISTING_APP" ]; then
    echo "iOS app already registered."
    APP_ID=$(echo "$EXISTING_APP" | awk '{print $4}')
else
    firebase apps:create ios "$APP_DISPLAY_NAME" --bundle-id "$BUNDLE_ID" --project "$FIREBASE_PROJECT_ID"
    # Get the app ID
    APP_ID=$(firebase apps:list --project "$FIREBASE_PROJECT_ID" 2>/dev/null | grep "$BUNDLE_ID" | awk '{print $4}')
fi

echo "Downloading GoogleService-Info.plist..."
firebase apps:sdkconfig ios "$APP_ID" --project "$FIREBASE_PROJECT_ID" --out "$IOS_DIR/MomAlarmClock/GoogleService-Info.plist"

if [ -f "$IOS_DIR/MomAlarmClock/GoogleService-Info.plist" ]; then
    echo "GoogleService-Info.plist saved to ios/MomAlarmClock/"
else
    echo "WARNING: Could not download GoogleService-Info.plist automatically."
    echo "Download it manually from: https://console.firebase.google.com/project/$FIREBASE_PROJECT_ID/settings/general"
    echo "Place it at: $IOS_DIR/MomAlarmClock/GoogleService-Info.plist"
fi
echo ""

# ─── Step 4: Enable Auth Providers ───────────────────

echo "Step 4/8: Firebase Auth Providers"
echo "─────────────────────────────────"
echo ""
echo "The Firebase CLI cannot enable auth providers directly."
echo "You MUST do this manually in the Firebase Console:"
echo ""
echo "  1. Open: https://console.firebase.google.com/project/$FIREBASE_PROJECT_ID/authentication/providers"
echo "  2. Click 'Add new provider'"
echo "  3. Enable 'Email/Password' (toggle ON, save)"
echo "  4. Click 'Add new provider' again"
echo "  5. Enable 'Anonymous' (toggle ON, save)"
echo ""
read -p "Press Enter once you've enabled both providers... "
echo ""

# ─── Step 5: Deploy Firestore Rules + Indexes ────────

echo "Step 5/8: Deploying Firestore Rules & Indexes"
echo "──────────────────────────────────────────────"
cd "$PROJECT_ROOT"

echo "Deploying Firestore rules..."
firebase deploy --only firestore:rules --project "$FIREBASE_PROJECT_ID"

echo "Deploying Firestore indexes..."
firebase deploy --only firestore:indexes --project "$FIREBASE_PROJECT_ID"
echo ""

# ─── Step 6: Deploy Storage Rules ────────────────────

echo "Step 6/8: Deploying Storage Rules"
echo "─────────────────────────────────"
firebase deploy --only storage --project "$FIREBASE_PROJECT_ID"
echo ""

# ─── Step 7: Deploy Cloud Functions ──────────────────

echo "Step 7/8: Deploying Cloud Functions"
echo "───────────────────────────────────"
echo "Installing function dependencies..."
cd "$PROJECT_ROOT/functions"
npm install
cd "$PROJECT_ROOT"

echo "Deploying 7 Cloud Functions..."
firebase deploy --only functions --project "$FIREBASE_PROJECT_ID"

echo "Verifying deployment..."
firebase functions:list --project "$FIREBASE_PROJECT_ID" 2>/dev/null || echo "(list may require a moment to propagate)"
echo ""

# ─── Step 8: Apple Developer Team ID ─────────────────

echo "Step 8/8: Apple Developer Team ID"
echo "──────────────────────────────────"
echo ""
echo "Find your Team ID at: https://developer.apple.com/account#MembershipDetailsCard"
echo "It's the 10-character alphanumeric string next to 'Team ID'."
echo ""
read -p "Enter your Apple Developer Team ID (e.g., A1B2C3D4E5): " TEAM_ID

if [ ${#TEAM_ID} -eq 10 ]; then
    sed -i '' "s/TEAM_ID_HERE/$TEAM_ID/" "$IOS_DIR/project.yml"
    echo "Set DEVELOPMENT_TEAM to $TEAM_ID in project.yml"
else
    echo "WARNING: Team ID should be 10 characters. Got '${TEAM_ID}'."
    echo "You can set it manually later: edit ios/project.yml, replace TEAM_ID_HERE with your Team ID."
fi
echo ""

# ─── Regenerate Xcode Project ────────────────────────

echo "Regenerating Xcode project..."
cd "$IOS_DIR"
xcodegen generate
echo ""

# ─── Summary ─────────────────────────────────────────

echo "══════════════════════════════════════════════════"
echo "  Setup Complete!"
echo "══════════════════════════════════════════════════"
echo ""
echo "  Firebase Project: $FIREBASE_PROJECT_ID"
echo "  GoogleService-Info.plist: $([ -f "$IOS_DIR/MomAlarmClock/GoogleService-Info.plist" ] && echo 'YES' || echo 'MISSING')"
echo "  Team ID: ${TEAM_ID:-NOT SET}"
echo ""
echo "  Remaining manual steps:"
echo "  ─────────────────────────"
echo "  1. APNS key: Create at https://developer.apple.com/account/resources/authkeys/add"
echo "     - Check 'Apple Push Notifications service (APNs)'"
echo "     - Download the .p8 file"
echo "     - Upload to Firebase Console > Project Settings > Cloud Messaging > APNs Authentication Key"
echo "     - Enter Key ID and Team ID when prompted"
echo ""
echo "  2. Build and archive:"
echo "     cd ios"
echo "     xcodebuild -project MomAlarmClock.xcodeproj -scheme MomAlarmClock -configuration Release archive -archivePath build/MomAlarmClock.xcarchive"
echo ""
echo "  3. Upload to TestFlight:"
echo "     xcodebuild -exportArchive -archivePath build/MomAlarmClock.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build/export"
echo ""
