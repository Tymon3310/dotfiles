#!/usr/bin/env sh
# Forward an IPC call to the running Quickshell instance, tolerating both
# spellings of its config path.
#
# ~/.config/quickshell is a symlink into the dotfiles repo, and Quickshell keys
# its instances by the literal config path. A shell started with the default
# (symlinked) path and one started with an explicit -p pointing at the real path
# therefore register as separate instances, while `quickshell ipc` resolves only
# the default spelling. That makes the keybinds silently do nothing whenever the
# running instance was started from the real path. Try both spellings and
# forward the call to whichever instance is actually running.
#
# Usage: qs-ipc.sh <ipc args...>   e.g. qs-ipc.sh call screenshot open

set -eu

default="$HOME/.config/quickshell/shell.qml"
real="$(readlink -f "$default" 2>/dev/null || true)"

for path in "$default" "$real"; do
    [ -n "$path" ] || continue
    if quickshell ipc -p "$path" show >/dev/null 2>&1; then
        exec quickshell ipc -p "$path" "$@"
    fi
done

echo "qs-ipc: no running quickshell instance found" >&2
exit 1
