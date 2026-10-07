local SCRIPTS = os.getenv("HOME") .. "/.config/hypr/scripts"

hl.on("hyprland.start", function()
    -- Imports the session environment before restarting portals (in order).
    hl.exec_cmd(SCRIPTS .. "/xdg.sh")

    hl.exec_cmd("xrandr --output DP-1 --primary")

    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("/usr/lib/pam_kwallet_init")

    hl.exec_cmd("linux-wallpaper-engine-ux")
    hl.exec_cmd(SCRIPTS .. "/gtk.sh")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("quickshell")
    hl.exec_cmd("XDG_MENU_PREFIX=arch- kbuildsycoca6 --noincremental")
    hl.exec_cmd("playerctld daemon")
    hl.exec_cmd("/usr/lib/kdeconnectd")
    hl.exec_cmd("vicinae server")
    hl.exec_cmd("wl-clip-persist --clipboard regular")
    hl.exec_cmd("hyprsunset")

    -- Start btop in background on special workspace
    hl.exec_cmd("kitty --class btop --config ~/.config/kitty/headless.conf -e btop",
        { workspace = "special:btop silent" })
end)
