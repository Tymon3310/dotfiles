#!/bin/bash

# Define a temporary file for the text output (for notifications)
TEMP_TEXT=$(mktemp)

# Trap to ensure the temporary text file is removed on script exit
trap 'rm -f "$TEMP_TEXT"' EXIT

echo "Select a region to capture for OCR..."

# Capture region with hyprshot and pipe the raw PNG data directly to Tesseract.
# --raw outputs the PNG data to stdout.
# '- -' tells tesseract to read from stdin and write to stdout.
# The OCR output is then piped to a temporary file.
if ! hyprshot -z -m region --raw | tesseract - - -l eng+pol >"$TEMP_TEXT"; then
  echo "Error: hyprshot or tesseract failed to process the image."
  exit 1
fi

# Copy the OCR text from the temporary file to the clipboard.
if ! wl-copy <"$TEMP_TEXT"; then
  echo "Error: Failed to copy text to clipboard."
  exit 1
fi

# Store the OCR text in a variable for the notification message.
OCR_TEXT=$(cat "$TEMP_TEXT")

echo "OCR text copied to clipboard."

# Send a desktop notification with the result.
notify-send "OCR Complete" "The OCR text has been copied to the clipboard. \n\n${OCR_TEXT:0:200}..."
