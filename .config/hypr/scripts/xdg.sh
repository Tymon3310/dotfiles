#!/bin/bash
# Import the Wayland session environment, then restart XDG desktop portals.
# Runs sequentially so the portals never start without WAYLAND_DISPLAY.
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
    # Backends first, then the frontend that talks to them.
    systemctl --user restart xdg-desktop-portal-hyprland 2>/dev/null || true
    systemctl --user restart plasma-xdg-desktop-portal-kde 2>/dev/null || true
    systemctl --user restart xdg-desktop-portal 2>/dev/null || true
else
    killall -q xdg-desktop-portal-hyprland xdg-desktop-portal-kde xdg-desktop-portal 2>/dev/null || true
    /usr/lib/xdg-desktop-portal-hyprland &
    [ -x /usr/lib/xdg-desktop-portal-kde ] && /usr/lib/xdg-desktop-portal-kde &
    sleep 0.5
    /usr/lib/xdg-desktop-portal &
fi
