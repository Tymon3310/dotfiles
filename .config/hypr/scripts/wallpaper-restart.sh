#!/usr/bin/env bash
# Restart linux-wallpaperengine with the exact command line it is running.
#
# It does not survive a monitor dropping off the bus (DP-1 does when it
# sleeps): the surface on that output is destroyed and never recreated, and
# the other output can freeze. Hyprland runs this when a monitor comes back.
# The Linux Wallpaper Engine app finds its engines by command line, so it
# still controls the restarted one.

set -u

pids=$(pgrep -x linux-wallpaper)
[ -n "$pids" ] || exit 0

for pid in $pids; do
    [ -r "/proc/$pid/cmdline" ] || continue
    mapfile -d '' args < "/proc/$pid/cmdline"
    cwd=$(readlink "/proc/$pid/cwd") || continue
    [ "${#args[@]}" -gt 0 ] || continue

    kill "$pid" 2>/dev/null
    # Give it a moment to let go of audio and its surfaces.
    for _ in $(seq 20); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done
    kill -9 "$pid" 2>/dev/null

    (cd "$cwd" && setsid -f "${args[@]}" >/dev/null 2>&1 </dev/null)
done
