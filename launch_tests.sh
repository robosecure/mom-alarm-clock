#!/bin/bash
/Users/wamsley/mom-alarm-clock/run_tests.sh >/dev/null 2>&1 </dev/null &
disown
echo "launched pid=$!"
