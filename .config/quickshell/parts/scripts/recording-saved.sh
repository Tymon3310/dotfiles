#!/bin/sh
# gpu-screen-recorder -sc hook: $1 = saved file, $2 = type (regular/replay/screenshot).
file="$1"
state=/tmp/qs-screenrecording-path
[ -n "$file" ] && [ -f "$file" ] || exit 0
# Only drop the recorder state if it still describes this recording.
[ "$(head -n1 "$state" 2>/dev/null)" = "$file" ] && rm -f "$state"
if [ "$(notify-send "Recording saved" "$(basename "$file") · click to open" -a "Screen Recorder" --action=default=Open --wait)" = "default" ]; then
    xdg-open "$file"
fi
