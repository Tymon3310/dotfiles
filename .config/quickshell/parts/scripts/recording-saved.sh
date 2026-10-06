#!/bin/sh
# gpu-screen-recorder -sc hook: $1 = saved file, $2 = type (regular/replay/screenshot).
file="$1"
[ -n "$file" ] && [ -f "$file" ] || exit 0
rm -f /tmp/qs-screenrecording-path
if [ "$(notify-send "Recording saved" "$(basename "$file") · click to open" -a "Screen Recorder" --action=default=Open --wait)" = "default" ]; then
    xdg-open "$file"
fi
