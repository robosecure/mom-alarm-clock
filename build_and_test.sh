#!/bin/bash
# Background build script for the MomAlarmClock iOS simulator target.
# Output is tee'd to a log the monitoring agent can poll.
set -u
cd "$(dirname "$0")/ios"

LOG=/tmp/mom_build.log
: > "$LOG"

exec >"$LOG" 2>&1
echo "[build] start $(date)"
xcodebuild clean build \
  -project MomAlarmClock.xcodeproj \
  -scheme MomAlarmClock \
  -destination 'platform=iOS Simulator,id=CE8349D4-210F-419E-A532-2882BB1C2037' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
BUILD_EXIT=$?
echo "[build] exit=$BUILD_EXIT $(date)"
exit $BUILD_EXIT
