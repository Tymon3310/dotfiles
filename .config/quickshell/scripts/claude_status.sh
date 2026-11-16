#!/bin/sh
# Claude Code hook: records each session's state for the island's agent
# indicator (read by agent_monitor.py). One file per session, so several
# sessions show up at once.
#
# Usage (from ~/.claude/settings.json hooks): claude_status.sh <state>
#   working | waiting | done | end      hook JSON arrives on stdin
#
# Must stay fast and never fail: it runs on every tool call.

state="$1"
dir="${XDG_RUNTIME_DIR:-/tmp}/agent-status/claude"
input=$(cat)

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0
file="$dir/$sid.json"

if [ "$state" = "end" ]; then
    rm -f "$file"
    exit 0
fi

# Notification fires for permission prompts and for the "waiting for your
# input" reminder after a finished turn. Only the first means it needs you.
if [ "$state" = "waiting" ]; then
    kind=$(printf '%s' "$input" | jq -r '.notification_type // empty' 2>/dev/null)
    msg=$(printf '%s' "$input" | jq -r '.message // empty' 2>/dev/null)
    case "$kind" in
        idle*) exit 0 ;;
    esac
    case "$msg" in
        *"waiting for your input"*) exit 0 ;;
    esac
fi

# Ancestor PIDs, so the monitor can match the terminal window that hosts it.
pids=""
p=$PPID
i=0
while [ "$p" -gt 1 ] 2>/dev/null && [ $i -lt 12 ]; do
    pids="$pids${pids:+,}$p"
    p=$(sed 's/.*) //' "/proc/$p/stat" 2>/dev/null | cut -d' ' -f2)
    [ -n "$p" ] || break
    i=$((i + 1))
done

mkdir -p "$dir"
printf '%s' "$input" | jq -c \
    --arg state "$state" \
    --argjson time "$(date +%s%3N)" \
    --argjson pids "[$pids]" \
    '{state: $state, time: $time, pids: $pids,
      cwd: (.cwd // ""), session: .session_id}' \
    > "$file.tmp" 2>/dev/null && mv -f "$file.tmp" "$file"
exit 0
