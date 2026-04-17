#!/bin/bash
/Users/wamsley/mom-alarm-clock/resolve_packages.sh >/dev/null 2>&1 </dev/null &
disown
echo "launched pid=$!"
