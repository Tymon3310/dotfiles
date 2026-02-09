#!/bin/bash

CMD_FILE="/tmp/screenpicker_cmd_show"
OUT_PIPE="/tmp/screenpicker_out"

# Ensure output pipe exists
if [ ! -p "$OUT_PIPE" ]; then
    mkfifo "$OUT_PIPE"
fi

# Send show command
echo "Debug: Touching $CMD_FILE" >&2
touch "$CMD_FILE"

# Read result
echo "Debug: Waiting for response from $OUT_PIPE" >&2
# cat will block until daemon writes to pipe
# daemon writes with timeout, so if it fails, cat might hang until we kill it or daemon writes EOF?
# Usually FIFO blocks open until writer connects.
# Once writer writes and closes, cat exits.
cat "$OUT_PIPE"
echo "Debug: Response received" >&2
