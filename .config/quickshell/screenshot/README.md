# Screenshot Tool

A unified screenshot tool for Quickshell/Hyprland that combines multiple capture modes.

## Modes

1. **Region** - Select a rectangular region to capture
2. **Window** - Click on a window to capture it
3. **Screen** - Capture the entire screen instantly
4. **OCR** - Select a region and extract text using Tesseract OCR (copied to clipboard)
5. **Lens** - Select a region and search it using Google Lens

## Dependencies

- `grim` - Screenshot utility for Wayland
- `magick` (ImageMagick) - Image processing
- `wl-copy` (wl-clipboard) - Clipboard support
- `tesseract` - OCR engine (for OCR mode)
- `curl` & `jq` - For Lens mode image upload
- `xdg-open` - For opening browser (Lens mode)
- `notify-send` - For notifications (libnotify)

## Usage

Run with Quickshell:
```bash
quickshell -p /path/to/screenshot
```

## Settings

- **Save to disk**: Toggle to save screenshots to disk or just copy to clipboard
- Screenshots are saved to `$SCREENSHOT_DIR`, `$XDG_SCREENSHOTS_DIR`, `$XDG_PICTURES_DIR`, or `~/Pictures`

## Keybindings

- `Escape` - Cancel and exit

## Building the shader

If you modify `dimming.frag`, rebuild the shader binary:
```bash
qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o dimming.frag.qsb dimming.frag
```
