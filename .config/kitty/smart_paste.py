# Ctrl+Shift+V that also pastes images.
#
# kitty's own paste only handles text, so an image on the clipboard pastes
# nothing. When the clipboard holds an image and no text, and Claude Code or
# OpenCode is in the foreground, this sends Ctrl+V instead: their own paste key,
# which reads images from the clipboard. Anything else goes through kitty's
# normal paste.
#
# Mapped in kitty.conf: map ctrl+shift+v kitten smart_paste.py

import os
import subprocess

from kittens.tui.handler import result_handler


def main(args: list[str]) -> None:
    pass


def clipboard_types() -> list[str]:
    try:
        out = subprocess.run(
            ["wl-paste", "--list-types"], capture_output=True, text=True, timeout=1
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    return out.stdout.split() if out.returncode == 0 else []


# Programs whose Ctrl+V pastes clipboard images.
IMAGE_PASTE_APPS = {"claude", "opencode"}


def runs_image_paste_app(window) -> bool:
    try:
        processes = window.child.foreground_processes
    except Exception:
        return False
    for process in processes:
        # Launchers can be wrappers (node, sh), so look at the first two words.
        for word in (process.get("cmdline") or [])[:2]:
            if os.path.basename(word) in IMAGE_PASTE_APPS:
                return True
    return False


@result_handler(no_ui=True)
def handle_result(args: list[str], answer: str, target_window_id: int, boss) -> None:
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return
    types = clipboard_types()
    has_image = any(t.startswith("image/") for t in types)
    has_text = any(t.startswith("text/plain") or t in ("UTF8_STRING", "STRING", "TEXT") for t in types)
    if has_image and not has_text and runs_image_paste_app(window):
        window.send_key("ctrl+v")
    else:
        boss.paste_from_clipboard()
