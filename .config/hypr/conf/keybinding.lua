local SCRIPTS = os.getenv("HOME") .. "/.config/hypr/scripts"
local pref = require("conf.pref")
local layout = require("conf.layout")

hl.config({
    input = {
        kb_layout = "pl",
        kb_variant = "",
        kb_model = "",
        numlock_by_default = true,
        mouse_refocus = false,
        kb_options = "fkeys:basic_13-24",

        follow_mouse = 1,
        sensitivity = 0,
    }
})


-- Applications
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd(pref.TERM))
hl.bind("SUPER + B", hl.dsp.exec_cmd(pref.BROWSER))
hl.bind("SUPER + E", hl.dsp.exec_cmd(pref.FILE_MANAGER))
hl.bind("SUPER + CTRL + E", hl.dsp.exec_cmd(pref.EMOJI_PICKER))
hl.bind("SUPER + CTRL + C", hl.dsp.exec_cmd(pref.CALCULATOR))
hl.bind("SUPER + CTRL + RETURN", hl.dsp.exec_cmd(pref.LAUNCHER))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(pref.LAUNCHER))

-- Windows
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + Q", hl.dsp.window.kill())
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ "fullscreen", "toggle" }))
hl.bind("SUPER + M", hl.dsp.window.fullscreen({ "maximized", "toggle" }))
hl.bind("SUPER + T", hl.dsp.window.float({ "toggle" }))
hl.bind("SUPER + S", hl.dsp.window.pseudo())
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + up", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + down", hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("SUPER + SHIFT + right", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
hl.bind("SUPER + SHIFT + left", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
hl.bind("SUPER + SHIFT + down", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))
hl.bind("SUPER + SHIFT + up", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
hl.bind("SUPER + K", hl.dsp.layout("swapsplit"))
hl.bind("SUPER + ALT + left", hl.dsp.window.swap({ direction = "left" }))
hl.bind("SUPER + ALT + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind("SUPER + ALT + up", hl.dsp.window.swap({ direction = "up" }))
hl.bind("SUPER + ALT + down", hl.dsp.window.swap({ direction = "down" }))
hl.bind("SUPER + ALT + Tab", hl.dsp.window.cycle_next())
hl.bind("SUPER + ALT + SHIFT + Tab", hl.dsp.window.cycle_next(false))
hl.bind("SUPER + CTRL + Tab", hl.dsp.window.alter_zorder({ mode = "top" }))

-- Actions
hl.bind("SUPER + PRINT", function() trigger_screenshot("region", "0") end)
hl.bind("SUPER + SHIFT + S", function() trigger_screenshot("region", "0") end)
hl.bind("SUPER + CTRL + Q", hl.dsp.exec_cmd("nwg-bar"))
hl.bind("SUPER + SHIFT + B", restart_waybar)
hl.bind("SUPER + V", hl.dsp.exec_cmd(pref.CLIP))

-- Per monitor Workspaces
layout.setup_events()

-- Switch workspaces with mainMod + [1-9,0] for 1-10
-- and mainMod + F[1-10] for 11-20
-- Move active window to a workspace with mainMod + SHIFT + [1-9,0] or SHIFT + F[1-10]
-- Move active window and follow with mainMod + CTRL + SHIFT + [1-9,0] or CTRL + SHIFT + F[1-10]
for local_workspace = 1, layout.per_monitor do
    local key

    if local_workspace <= 10 then
        -- Use number keys 1-9, 0 for workspaces 1-10
        key = tostring(local_workspace % 10)
    else
        -- Use F1-F10 for workspaces 11-20
        key = "F" .. (local_workspace - 10)
    end

    hl.bind("SUPER + " .. key, layout.focus_local_workspace(local_workspace), { repeating = true })
    hl.bind("SUPER + SHIFT + " .. key, layout.move_to_local_workspace(local_workspace, false), { repeating = true })
    hl.bind("SUPER + CTRL + SHIFT + " .. key, layout.move_to_local_workspace(local_workspace, true), { repeating = true })
end

hl.bind("SUPER + Tab", layout.cycle_local_workspace(1), { repeating = true })
hl.bind("SUPER + SHIFT + Tab", layout.cycle_local_workspace(-1), { repeating = true })

hl.bind("SUPER + mouse_down", layout.cycle_local_workspace(1))
hl.bind("SUPER + mouse_up", layout.cycle_local_workspace(-1))
hl.bind("SUPER + G", layout.recover_active_window)
hl.bind("SUPER + CTRL + G", layout.recover_rogue_windows)

hl.define_submap("clean", function()
    hl.bind("SUPER + Escape", hl.dsp.submap("reset"))
end)

hl.bind("SUPER + SHIFT + F", toggle_btop_special)

--Custom media keys
local player = "spotify"
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_SINK@ 5%-"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl -p " .. player .. " play-pause"))
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl -p " .. player .. " pause"))
-- bind = , XF86AudioNext, exec, playerctl -p $player next
-- bind = , XF86AudioPrev, exec, playerctl -p $player previous
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl -p " .. player .. " volume 0.05+"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl -p " .. player .. " volume 0.05-"))
-- bind = , XF86AudioForward, exec, playerctl -p $player next
-- bind = , XF86AudioBackward, exec, playerctl -p $player previous
hl.bind("XF86AudioForward", hl.dsp.exec_cmd("playerctl -i " .. player .. " position 1+"))
hl.bind("XF86AudioRewind", hl.dsp.exec_cmd("playerctl -i " .. player .. " position 1-"))
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl -i " .. player .. " play-pause"))
hl.bind("XF86Forward", hl.dsp.exec_cmd("playerctl -p " .. player .. " position 1+"))
hl.bind("XF86Back", hl.dsp.exec_cmd("playerctl -p " .. player .. " position 1-"))
hl.bind("XF86HomePage", hl.dsp.exec_cmd("playerctl -p " .. player .. " next"))
hl.bind("XF86Search", hl.dsp.exec_cmd("playerctl -p " .. player .. " previous"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("playerctl -p " .. player .. " shuffle toggle"))
hl.bind("XF86MonBrightnessDown",
    hl.dsp.exec_cmd("playerctl -p " ..
        player ..
        " loop $(if [[ \"$(playerctl -p " ..
        player ..
        " loop)\" == \"Track\" ]]; then echo \"Playlist\"; elif [[ \"$(playerctl -p " ..
        player .. " loop)\" == \"Playlist\" ]]; then echo \"None\"; else echo \"Track\"; fi)"))
-- bind = , Cancel, exec, wpctl set-mute @DEFAULT_SOURCE@ toggle
-- bind = , XF86Reload, exec, wpctl set-volume @DEFAULT_SOURCE@ 5%+
-- bind = , XF86Favorites, exec, wpctl set-volume @DEFAULT_SOURCE@ 5%-
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"))
