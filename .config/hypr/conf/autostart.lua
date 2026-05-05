local SCRIPTS = os.getenv("HOME") .. "/.config/hypr/scripts"

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl reload --no-warnings")
    hl.exec_cmd(SCRIPTS .. "/xdg.sh")

    hl.exec_cmd("xrandr --output DP-1 --primary")

    -- hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    -- hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("/usr/lib/pam_kwallet_init")
    -- hl.exec_cmd("dbus-update-activation-environment --all && gnome-keyring-daemon --start --components=secrets")

    hl.exec_cmd("swaync")
    hl.exec_cmd("swayosd-server")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd(SCRIPTS .. "/gtk.sh")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --watch cliphist store")
    -- hl.exec_cmd("waybar")
    restart_waybar()
    hl.exec_cmd("XDG_MENU_PREFIX=arch- kbuildsycoca6")
    hl.exec_cmd("playerctld daemon")
    hl.exec_cmd("/usr/lib/kdeconnectd &")
    hl.exec_cmd("vicinae server")
    hl.exec_cmd("wl-clip-persist --clipboard regular")
    hl.exec_cmd("hyprsunset")

    -- Start btop in background on special workspace
    hl.exec_cmd("kitty --class btop --config ~/.config/kitty/headless.conf -e btop", { workspace = "special:btop" })
    hl.timer(normalize_btop_window, { timeout = 300, type = "oneshot" })
end)
