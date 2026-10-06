#!/bin/bash
# Restart XDG desktop portals cleanly via systemd with imported Wayland environment.
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user restart xdg-desktop-portal-hyprland 2>/dev/null || true
    systemctl --user restart xdg-desktop-portal 2>/dev/null || true
else
    killall -q xdg-desktop-portal-hyprland xdg-desktop-portal 2>/dev/null || true
    /usr/lib/xdg-desktop-portal-hyprland &
    sleep 0.5
    /usr/lib/xdg-desktop-portal &
fi
