#!/bin/bash
# Resolve SPM dependencies in the background (network-heavy, slow first time)
cd /Users/wamsley/mom-alarm-clock/ios
LOG=/tmp/mom_resolve.log
: > "$LOG"
exec >"$LOG" 2>&1
echo "[resolve] start $(date)"
xcodebuild -resolvePackageDependencies \
  -project MomAlarmClock.xcodeproj \
  -scheme MomAlarmClock
echo "[resolve] exit=$? $(date)"
