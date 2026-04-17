#!/bin/bash
# Detaches the build into a fully independent process.
/Users/wamsley/mom-alarm-clock/build_and_test.sh >/dev/null 2>&1 </dev/null &
disown
echo "launched pid=$!"
