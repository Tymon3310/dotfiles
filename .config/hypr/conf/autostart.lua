-- -----------------------------------------------------
-- Autostart
-- -----------------------------------------------------
local SCRIPTS = os.getenv("HOME") .. "/.config/hypr/scripts"

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl reload -n")
    hl.exec_cmd(SCRIPTS .. "/xdg.sh")

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
    hl.exec_cmd(SCRIPTS .. "/waybar.sh")
    hl.exec_cmd("XDG_MENU_PREFIX=arch- kbuildsycoca6")
    hl.exec_cmd("playerctld daemon")
    hl.exec_cmd("/usr/lib/kdeconnectd &")
    hl.exec_cmd("vicinae server")
    hl.exec_cmd("wl-clip-persist --clipboard regular")
    hl.exec_cmd("hyprsunset")
    hl.exec_cmd(SCRIPTS .. "/bw_fix.sh")
    hl.exec_cmd("jbl-quantum-tray")
end)
