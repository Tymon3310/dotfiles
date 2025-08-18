#!/bin/bash
hyprctl seterror disable
# Kill any existing waybar processes
killall waybar 2>/dev/null

# Try to start waybar and capture any errors
ERROR_LOG=$(waybar 2>&1)
EXIT_CODE=$?

# If waybar failed to start, notify the user with the error
if [ $EXIT_CODE -ne 0 ]; then
    # Check if the output (stored in ERROR_LOG) actually contains an "[error]" marker
    if echo "$ERROR_LOG" | grep -q "\\[error\\]"; then
        # Genuine error based on Waybar's output
        # Filter ERROR_LOG to only include lines with "[error]"
        DISPLAY_ERROR=$(echo "$ERROR_LOG" | grep "\\[error\\]")

        echo "Waybar failed to start with error: $DISPLAY_ERROR" >&2

        # Send notification with the (potentially trimmed) error
        # notify-send --urgency=critical "Waybar Error" "$DISPLAY_ERROR"

        # Log the full, original error to journalctl
        echo "Waybar failed to start (output contained '[error]'): $ERROR_LOG" >&2

        # Set Hyprland error display with the (potentially trimmed) error
        hyprctl seterror 'rgba(ee6666ff)' "Waybar Error: $DISPLAY_ERROR"

        exit 1 # Critical error, exit script with error status
    else
        # Waybar exited non-zero, but no "[error]" in its output.
        # Treat as operational per user's problem description.
        echo "Waybar exited with status $EXIT_CODE. Output did not contain '[error]'. Assuming operational." >&2
        echo "Full Waybar output for diagnostics: $ERROR_LOG" >&2
        hyprctl seterror disable # Clear any previous Hyprland error state
        # Script will continue and exit 0 normally
    fi
else
    # Waybar exited with 0 (success)
    # Clear any previous errors when Waybar starts successfully
    hyprctl seterror disable
fi``

exit 0
