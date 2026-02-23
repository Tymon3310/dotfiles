#!/bin/sh

# Track last processed window
LAST_ADDR=""

handle() {
  case $1 in
    windowtitle*)
      window_id=${1#*>>}
      
      # Fetch window info
      window_info=$(hyprctl clients -j | jq --arg id "0x$window_id" '.[] | select(.address == ($id))')
      [ -z "$window_info" ] && return

      window_title=$(echo "$window_info" | jq -r '.title // empty')
      is_floating=$(echo "$window_info" | jq -r '.floating')
      monitor_id=$(echo "$window_info" | jq -r '.monitor')

      if [[ "$window_title" == "Extension: (Bitwarden Password Manager)"* ]]; then
        if [ "$LAST_ADDR" = "$window_id" ] && [ "$is_floating" = "true" ]; then return; fi

        # --- MONITOR MATH ---
        monitor_info=$(hyprctl monitors -j | jq --arg id "$monitor_id" '.[] | select(.id == ($id | tonumber))')
        mon_x=$(echo "$monitor_info" | jq -r '.x')
        mon_y=$(echo "$monitor_info" | jq -r '.y')

        # Top-Left calculation with 80px padding
        target_x=$((mon_x + 60))
        target_y=$((mon_y + 80))

        if [ "$is_floating" = "false" ]; then
            hyprctl --batch "dispatch togglefloating address:0x$window_id ; \
                             dispatch resizewindowpixel exact 400 600,address:0x$window_id ; \
                             dispatch movewindowpixel exact $target_x $target_y,address:0x$window_id"
            LAST_ADDR="$window_id"
        else
            hyprctl --batch "dispatch resizewindowpixel exact 400 600,address:0x$window_id ; \
                             dispatch movewindowpixel exact $target_x $target_y,address:0x$window_id"
        fi
      fi
      ;;
  esac
}

# Socket detection
HYPR_SOCKET="$XDG_RUNTIME_DIR/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
if [ ! -S "$HYPR_SOCKET" ]; then
    HYPR_SOCKET=$(ls -t $XDG_RUNTIME_DIR/hypr/*/ .socket2.sock 2>/dev/null | head -n 1)
fi

socat -U - UNIX-CONNECT:"$HYPR_SOCKET" | while read -r line; do handle "$line"; done