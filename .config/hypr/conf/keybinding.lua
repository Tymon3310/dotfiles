-- -----------------------------------------------------
-- Key bindings
-- -----------------------------------------------------

local mainMod = "SUPER"
local SCRIPTS = os.getenv("HOME") .. "/.config/hypr/scripts"
local pref = require("pref")

-- Applications
hl.bind(mainMod " + RETURN", hl.dsp.exec_cmd(pref.TERM))
hl.bind(mainMod " + B", hl.dsp.exec_cmd(pref.BROWSER))
hl.bind(mainMod " + E", hl.dsp.exec_cmd(pref.FILE_MANAGER))
hl.bind(mainMod " + CTRL + E", hl.dsp.exec_cmd(pref.EMOJI_PICKER))
hl.bind(mainMod " + CTRL + C", hl.dsp.exec_cmd(pref.CALCULATOR))
hl.bind(mainMod " + CTRL + RETURN", hl.dsp.exec_cmd(pref.LAUNCHER))
hl.bind(mainMod " + SPACE", hl.dsp.exec_cmd(pref.LAUNCHER))

-- Windows
hl.bind(mainMod " + Q", hl.dsp.window.close)
hl.bind(mainMod " + SHIFT + Q", hl.dsp.window.kill)
hl.bind(mainMod " + F", hl.dsp.window.fullscreen({ "fullscreen", "toggle" }))
hl.bind(mainMod " + M", hl.dsp.window.fullscreen({ "maximized", "toggle" }))
hl.bind(mainMod " + T", hl.dsp.window.float({ "toggle" }))
hl.bind(mainMod " + S", hl.dsp.window.pseudo())
hl.bind(mainMod "+ J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod " + left", hl.dsp.focus({ "left" }))
hl.bind(mainMod " + right", hl.dsp.focus({ "right" }))
hl.bind(mainMod " + up", hl.dsp.focus({ "up" }))
hl.bind(mainMod " + down", hl.dsp.focus({ "down" }))
hl.bind(mainMod " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod " + SHIFT + right", hl.dsp.window.resize(100, 0))
hl.bind(mainMod " + SHIFT + left", hl.dsp.window.resize(-100, 0))
hl.bind(mainMod " + SHIFT + down", hl.dsp.window.resize(0, 100))
hl.bind(mainMod " + SHIFT + up", hl.dsp.window.resize(0, -100))
hl.bind(mainMod " + K", hl.dsp.window.swap())
hl.bind(mainMod " + ALT + left", hl.dsp.window.swap("left"))
hl.bind(mainMod " + ALT + right", hl.dsp.window.swap("right"))
hl.bind(mainMod " + ALT + up", hl.dsp.window.swap("up"))
hl.bind(mainMod " + ALT + down", hl.dsp.window.swap("down"))
hl.bind(mainMod " + ALT + Tab", hl.dsp.window.cycle_next())
hl.bind(mainMod " + ALT + SHIFT + Tab", hl.dsp.window.cycle_next(false))
hl.bind(mainMod " + CTRL + Tab", hl.dsp.window.alter_zorder("top"))

-- Actions
hl.bind(mainMod " + PRINT", hl.dsp.exec_cmd(pref.SCREENSHOT))
hl.bind(mainMod " + SHIFT + S", hl.dsp.exec_cmd(pref.SCREENSHOT))
-- hl.bind("mainMod + CTRL + S", hl.dsp.exec_cmd, SCRIPTS .. "/ocr.sh")
-- hl.bind("mainMod + ALT + S", hl.dsp.exec_cmd, SCRIPTS .. "/hyprshot -z -m region --raw | satty --filename -")
hl.bind(mainMod " + CTRL + Q", hl.dsp.exec_cmd("nwg-bar"))
hl.bind(mainMod " + SHIFT + B", hl.dsp.exec_cmd(SCRIPTS .. "/waybar.sh"))
hl.bind(mainMod " + V", hl.dsp.exec_cmd(pref.CLIP))

-- Workspaces

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
        hl.dsp.focus({ workspace = get_workspace_id(local_workspace) })
    end
end

local function move_to_local_workspace(local_workspace)
    return function()
        hl.dsp.window.move({ workspace = get_workspace_id(local_workspace) })
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
        hl.dsp.focus({ workspace = get_workspace_id(next_workspace, monitor) })
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

    hl.dsp.window.move({ workspace = workspace_id, window = window.address })
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
        hl.dsp.window.center(window.address)
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
for local_workspace = 1, split_workspaces.per_monitor do
    local key = local_workspace % 10
    hl.bind(mainMod " + " .. key, focus_local_workspace(local_workspace))
    hl.bind(mainMod " + SHIFT + " .. key, move_to_local_workspace(local_workspace))
end

hl.bind(mainMod " + Tab", cycle_local_workspace(1))
hl.bind(mainMod " + SHIFT + Tab", cycle_local_workspace(-1))

hl.bind(mainMod " + mouse_down", cycle_local_workspace(1))
hl.bind(mainMod " + mouse_up", cycle_local_workspace(-1))
hl.bind(mainMod " + G", recover_active_window)
hl.bind(mainMod " + CTRL + G", recover_rogue_windows)

hl.on("monitor.removed", schedule_workspace_recovery)
hl.on("monitor.added", schedule_workspace_recovery)
hl.on("window.open", schedule_window_recovery)

-- Passthrough SUPER KEY to Virtual Machine
hl.bind(mainMod "+ P", hl.dsp.submap("clean"))
hl.define_submap("clean", function()
    hl.bind(mainMod "+ esc", hl.dsp.submap("reset"))
end)

-- btop on special workspace
hl.bind(mainMod " + SHIFT + F",
    hl.dsp.exec_cmd(
        "pgrep btop && hyprctl dispatch togglespecialworkspace btop || kitty --class btop --config ~/.config/kitty/headless.conf -e btop && hyprctl dispatch centerwindow"))

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
hl.bind("XF86Lock", hl.dsp.exec_cmd("hyprlock"))
hl.bind("code:238", hl.dsp.exec_cmd("brightnessctl -d smc::kbd_backlight s +10"))
