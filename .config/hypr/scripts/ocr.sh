#!/bin/bash

# Define a temporary file for the image (used by convert and tesseract)
# Using mktemp is more robust as it handles unique file creation safely
TEMP_IMG=$(mktemp --suffix=.png)

# Trap to ensure temporary file is always removed on script exit, error, or interrupt
trap 'rm -f "$TEMP_IMG"' EXIT

echo "Select a region to capture (hyprshot copies to clipboard)..."

# Capture region with hyprshot. It will automatically copy the screenshot to the clipboard.
# --silent prevents desktop notifications which are often unwanted in scripts.
if ! hyprshot -z -m region --silent; then
  echo "Error: hyprshot failed to capture image."
  exit 1
fi

# Give hyprshot a moment to put the image on the clipboard
sleep 0.1

echo "Retrieving image from clipboard..."

# Paste the image from the clipboard directly into ImageMagick's 'magick' command.
# 'wl-paste --type image/png' reads the PNG from the clipboard.
# 'magick png:-' reads the PNG from stdin.
# 'png:-' outputs a standard PNG to stdout.
# The output is then redirected to our temporary file.
if ! wl-paste --type image/png | magick png:- png:"$TEMP_IMG"; then
  echo "Error: Failed to paste image from clipboard or ImageMagick failed to process it."
  echo "Ensure 'wl-clipboard' and 'imagemagick' (or 'magick') are installed."
  exit 1
fi

# Verify the temporary file is a valid PNG
if [ ! -s "$TEMP_IMG" ]; then
  echo "Error: Captured image file is empty after pasting."
  exit 1
fi
if ! file "$TEMP_IMG" | grep -q "PNG image data"; then
  echo "Error: Clipboard content was not a valid PNG image."
  exit 1
fi

echo "Processing image with Tesseract..."

# Run tesseract on the temporary file and output text to clipboard
# Ensure tesseract and its language packs are installed (tesseract-data-eng, tesseract-data-pol)
if ! tesseract "$TEMP_IMG" - -l eng+pol | wl-copy; then
  echo "Error: Tesseract failed to process the image or wl-copy failed."
  echo "Ensure 'tesseract', 'tesseract-data-eng', 'tesseract-data-pol', and 'wl-clipboard' are installed."
  # If Tesseract fails, the temp file will be cleaned by the trap
  exit 1
fi

echo "OCR text copied to clipboard."

notify-send "OCR Complete" "The OCR text has been copied to the clipboard. \n The text is: $(wl-paste)"
