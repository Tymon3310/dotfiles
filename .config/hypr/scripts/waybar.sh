#!/bin/bash

# Kill existing instances and wait for them to exit
killall waybar 2>/dev/null
while pgrep -x waybar >/dev/null; do sleep 1; done

# Start waybar in background, redirect logs to a file or journal
waybar > /tmp/waybar.log 2>&1 &
WAYBAR_PID=$!

# Wait a second to see if it crashes immediately
sleep 1

if ! ps -p $WAYBAR_PID > /dev/null; then
    # Double check if waybar is running (in case of PID change)
    if pgrep -x waybar >/dev/null; then
        hyprctl seterror disable
        exit 0
    fi
    # It crashed
    echo "Waybar failed to start!"
    cat /tmp/waybar.log
    hyprctl seterror 'rgba(ee6666ff)' "Waybar Crashed"
    exit 1
else
    hyprctl seterror disable
fi
