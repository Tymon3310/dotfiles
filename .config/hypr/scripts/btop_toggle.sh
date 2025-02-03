#!/bin/bash

# Unique identifier for btop window
BTOP_CLASS="btop"
MAIN_MONITOR="DP-1"

# Kill any existing btop processes if multiple exist
while pgrep -x "btop" >/dev/null; do
    pkill -x "btop"
    sleep 0.1
done

# Check for existing window
window_exists() {
    hyprctl clients -j | grep -qE '"class": "btop".*"mapped": true'
}

if window_exists; then
    # Hide existing window
    hyprctl dispatch movetoworkspacesilent "special:btop,class:^($BTOP_CLASS)$"
    hyprctl dispatch togglespecialworkspace btop
else
    # Launch new instance with strict environment
    kitty --class "$BTOP_CLASS" -e btop &
    
    # Wait for window creation
    while :; do
        window_exists && break
        sleep 0.1
    done

    # Force atomic placement
    hyprctl dispatch focusmonitor "$MAIN_MONITOR"
    hyprctl dispatch moveworkspacetomonitor "special:btop" "$MAIN_MONITOR"
    hyprctl dispatch movetoworkspacesilent "special:btop,class:^($BTOP_CLASS)$"
    hyprctl dispatch centerwindow
    hyprctl dispatch pin
fi

# Final position enforcement
sleep 0.2
hyprctl dispatch movewindowpixel exact 0 0,class:^($BTOP_CLASS)$
hyprctl dispatch centerwindow
