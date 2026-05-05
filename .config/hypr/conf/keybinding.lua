local SCRIPTS = os.getenv("HOME") .. "/.config/hypr/scripts"
local pref = require("conf.pref")



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
hl.bind("SUPER + PRINT", hl.dsp.exec_cmd(pref.SCREENSHOT))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd(pref.SCREENSHOT))
hl.bind("SUPER + CTRL + Q", hl.dsp.exec_cmd("nwg-bar"))
hl.bind("SUPER + SHIFT + B", restart_waybar)
hl.bind("SUPER + V", hl.dsp.exec_cmd(pref.CLIP))

-- Per monitor Workspaces

local split_workspaces = HYPR_SPLIT_WORKSPACES or {
    per_monitor = 10,
    monitor_order = {},
}
local recovery_delay_ms = 150

local function get_monitor_slot(monitor)
    if not monitor then
        return 1
    end

    for index, monitor_name in ipairs(split_workspaces.monitor_order) do
        if monitor.name == monitor_name then
            return index
        end
    end

    return monitor.id + 1
end

local function get_workspace_id(local_workspace, monitor)
    local monitor_slot = get_monitor_slot(monitor or hl.get_active_monitor())
    return ((monitor_slot - 1) * split_workspaces.per_monitor) + local_workspace
end

local function focus_local_workspace(local_workspace)
    return function()
        hl.dispatch(hl.dsp.focus({ workspace = get_workspace_id(local_workspace) }))
    end
end

local function move_to_local_workspace(local_workspace, follow)
    return function()
        local workspace_id = get_workspace_id(local_workspace)
        local active_window = hl.get_active_window()
        if active_window then
            hl.dispatch(hl.dsp.window.move({ workspace = workspace_id, follow = follow }))
        end
    end
end

local function cycle_local_workspace(step)
    return function()
        local monitor = hl.get_active_monitor()
        local active_workspace = hl.get_active_workspace()
        local local_workspace = 1

        if monitor and active_workspace then
            local monitor_base = (get_monitor_slot(monitor) - 1) * split_workspaces.per_monitor
            local candidate = active_workspace.id - monitor_base

            if candidate >= 1 and candidate <= split_workspaces.per_monitor then
                local_workspace = candidate
            end
        end

        local next_workspace = ((local_workspace - 1 + step) % split_workspaces.per_monitor) + 1
        hl.dispatch(hl.dsp.focus({ workspace = get_workspace_id(next_workspace, monitor) }))
    end
end

local function get_xy(vec)
    if type(vec) ~= "table" then
        return 0, 0
    end

    return vec.x or vec[1] or 0, vec.y or vec[2] or 0
end

local function get_monitor_slots()
    local slots = {}

    for _, monitor in ipairs(hl.get_monitors()) do
        slots[get_monitor_slot(monitor)] = true
    end

    return slots
end

local function is_workspace_rogue(workspace, valid_slots)
    if not workspace or workspace.special or workspace.id < 1 then
        return false
    end

    local slot = math.floor((workspace.id - 1) / split_workspaces.per_monitor) + 1
    return not valid_slots[slot]
end

local function move_window_to_workspace(window, workspace_id)
    if not window or not workspace_id then
        return false
    end

    hl.dispatch(hl.dsp.window.move({ workspace = workspace_id }))
    return true
end

local function center_window_if_needed(window)
    if not window or not window.monitor or not window.floating then
        return false
    end

    local win_x, win_y = get_xy(window.at)
    local win_w, win_h = get_xy(window.size)
    local mon_x, mon_y = window.monitor.x, window.monitor.y
    local mon_w, mon_h = window.monitor.width, window.monitor.height

    local min_x = mon_x - math.max(win_w, mon_w)
    local min_y = mon_y - math.max(win_h, mon_h)
    local max_x = mon_x + mon_w
    local max_y = mon_y + mon_h

    if win_x < min_x or win_y < min_y or win_x > max_x or win_y > max_y then
        hl.dispatch(hl.dsp.window.center(window.address))
        return true
    end

    return false
end

local function recover_rogue_windows()
    local active_workspace = hl.get_active_workspace()
    if not active_workspace then
        return 0
    end

    local valid_slots = get_monitor_slots()
    local recovered = 0

    for _, window in ipairs(hl.get_windows()) do
        if is_workspace_rogue(window.workspace, valid_slots) then
            if move_window_to_workspace(window, active_workspace.id) then
                recovered = recovered + 1
            end
        end
    end

    return recovered
end

local function recover_active_window()
    local window = hl.get_active_window()
    local active_workspace = hl.get_active_workspace()
    if not window or not active_workspace then
        return
    end

    local valid_slots = get_monitor_slots()

    if is_workspace_rogue(window.workspace, valid_slots) then
        move_window_to_workspace(window, active_workspace.id)
    elseif window.workspace and window.workspace.id ~= active_workspace.id then
        move_window_to_workspace(window, active_workspace.id)
    end

    center_window_if_needed(window)
end

local function schedule_workspace_recovery()
    hl.timer(function()
        recover_rogue_windows()
    end, { timeout = recovery_delay_ms, type = "oneshot" })
end

local function schedule_window_recovery()
    hl.timer(function()
        center_window_if_needed(hl.get_active_window())
    end, { timeout = recovery_delay_ms, type = "oneshot" })
end

-- Switch workspaces with mainMod + [1-9,0]
-- Move active window to a workspace with mainMod + SHIFT + [1-9,0]
-- Move active window and follow with mainMod + CTRL + SHIFT + [1-9,0]
for local_workspace = 1, split_workspaces.per_monitor do
    local key = local_workspace % 10
    hl.bind("SUPER + " .. key, focus_local_workspace(local_workspace))
    hl.bind("SUPER + SHIFT + " .. key, move_to_local_workspace(local_workspace, false))
    hl.bind("SUPER + CTRL + SHIFT + " .. key, move_to_local_workspace(local_workspace, true))
end

hl.bind("SUPER + Tab", cycle_local_workspace(1))
hl.bind("SUPER + SHIFT + Tab", cycle_local_workspace(-1))

hl.bind("SUPER + mouse_down", cycle_local_workspace(1))
hl.bind("SUPER + mouse_up", cycle_local_workspace(-1))
hl.bind("SUPER + G", recover_active_window)
hl.bind("SUPER + CTRL + G", recover_rogue_windows)

hl.on("monitor.removed", schedule_workspace_recovery)
hl.on("monitor.added", schedule_workspace_recovery)
hl.on("window.open", schedule_window_recovery)

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
hl.bind("XF86ScreenSaver", hl.dsp.exec_cmd("hyprlock"))
hl.bind("code:238", hl.dsp.exec_cmd("brightnessctl -d smc::kbd_backlight s +10"))
