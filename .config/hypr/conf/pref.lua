-- Quickshell IPC goes through a helper so the call still reaches the running
-- instance when the shell was started from the real dotfiles path instead of
-- the default ~/.config/quickshell symlink (they register as different
-- instances). See the helper for details.
local QS_IPC = os.getenv("HOME") .. "/.config/quickshell/scripts/qs-ipc.sh"

return {
    TERM = "kitty",
    HEADLESS = "kitty -c ~/.config/kitty/headless.conf --class headless -e",
    BTOP = "kitty --class btop --config ~/.config/kitty/headless.conf -e btop",
    EDITOR = "nvim",
    BROWSER = "zen-twilight",
    FILE_MANAGER = "dolphin",
    SCREENSHOT = QS_IPC .. " call screenshot open",
    RECORD = QS_IPC .. " call screenshot record",
    LOCK = QS_IPC .. " call lock trigger",
    CALCULATOR = "qalculate-qt",
    EMOJI_PICKER = "vicinae vicinae://launch/core/search-emojis",
    CLIP = "vicinae vicinae://launch/clipboard/history",
    LAUNCHER = "vicinae toggle"
}
