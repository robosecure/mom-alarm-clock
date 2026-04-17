#!/bin/bash
set -u
cd /Users/wamsley/mom-alarm-clock/ios
LOG=/tmp/mom_test.log
: > "$LOG"
exec >"$LOG" 2>&1
echo "[test] start $(date)"
xcodebuild test \
  -project MomAlarmClock.xcodeproj \
  -scheme MomAlarmClock \
  -destination 'platform=iOS Simulator,id=CE8349D4-210F-419E-A532-2882BB1C2037' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
echo "[test] exit=$? $(date)"
