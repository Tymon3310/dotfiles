#!/usr/bin/env bash
# Restart the wallpaper after a monitor comes back.
#
# linux-wallpaperengine does not survive a monitor dropping off the bus (DP-1
# does when it sleeps): the surface on that output is destroyed and never
# recreated, and the other output can freeze. Hyprland runs this when a
# monitor comes back.
#
# The engine must be restarted through the Linux Wallpaper Engine app: when
# an engine it started exits, the app drops that wallpaper from its saved
# list (active-wallpapers.json), so nothing comes back on the next login.
# Instead, kill the app first with SIGKILL (no chance to save), then the
# engine, then start the app again. On startup it sees saved wallpapers with
# no engine running and relaunches them on the current outputs.

set -u

app_pids() {
    # The main process only; Electron's helpers carry --type=.
    pgrep -f '^electron[0-9]* /usr/lib/linux-wallpaper-engine-ux/app\.asar$'
}

app=$(app_pids)
[ -n "$app" ] || exit 0

kill -9 $app 2>/dev/null
for _ in $(seq 20); do
    [ -z "$(app_pids)" ] && break
    sleep 0.1
done

# comm is truncated to 15 characters: "linux-wallpaper".
pkill -x linux-wallpaper
for _ in $(seq 20); do
    pgrep -x linux-wallpaper >/dev/null || break
    sleep 0.1
done
pkill -9 -x linux-wallpaper

setsid -f linux-wallpaper-engine-ux >/dev/null 2>&1 </dev/null
