hl.config({
    general = { layout = "dwindle" },
    dwindle = { preserve_split = true },
    binds = {
        workspace_back_and_forth = false,
        allow_workspace_cycles = true,
        pass_mouse_when_bound = false,
        hide_special_on_workspace_change = true,
    }
})

local split_workspaces = { per_monitor = 20, monitor_order = { "DP-1", "DP-2" } }
local per_monitor = split_workspaces.per_monitor
local monitor_slots = {}

local function dispatcher_map(factory)
    return setmetatable({}, {
        __index = function(t, id)
            t[id] = factory(id)
            return t[id]
        end
    })
end

local focus_dsp = dispatcher_map(function(id) return hl.dsp.focus({ workspace = id }) end)
local move_dsp = dispatcher_map(function(id) return hl.dsp.window.move({ workspace = id, follow = false }) end)
local move_follow_dsp = dispatcher_map(function(id) return hl.dsp.window.move({ workspace = id, follow = true }) end)

for index, name in ipairs(split_workspaces.monitor_order) do
    monitor_slots[name] = index
    local base = (index - 1) * per_monitor
    for ws = 1, per_monitor do
        local id = base + ws
        hl.workspace_rule({ workspace = tostring(id), monitor = name, persistent = true })
    end
end

local function monitor_slot(mon)
    return mon and mon.name and monitor_slots[mon.name]
end

local function get_current_slot()
    local slot = monitor_slot(hl.get_active_monitor()) or monitor_slot(hl.get_monitor_at_cursor())
    if slot then return slot end
    local win = hl.get_active_window()
    return monitor_slot(win and win.monitor) or 1
end

local function get_monitor_slot(mon)
    return mon and (monitor_slot(mon) or ((mon.id or 0) + 1)) or get_current_slot()
end

local function workspace_id(slot, local_ws)
    return (slot - 1) * per_monitor + local_ws
end

local function focus_local_workspace(ws)
    return function()
        hl.dispatch(focus_dsp[workspace_id(get_current_slot(), ws)])
    end
end

local function move_to_local_workspace(ws, follow)
    local dsp = follow and move_follow_dsp or move_dsp
    return function()
        hl.dispatch(dsp[workspace_id(get_current_slot(), ws)])
    end
end

local function cycle_local_workspace(step)
    return function()
        local slot = get_current_slot()
        local active = hl.get_active_workspace()
        local cur = (active and active.id and (active.id - (slot - 1) * per_monitor)) or 1
        local local_ws = (cur >= 1 and cur <= per_monitor) and cur or 1
        local next_ws = ((local_ws - 1 + step) % per_monitor) + 1
        hl.dispatch(focus_dsp[workspace_id(slot, next_ws)])
    end
end

local function get_monitor_slots()
    local slots = {}
    for _, mon in ipairs(hl.get_monitors()) do
        slots[get_monitor_slot(mon)] = true
    end
    return slots
end

local function is_workspace_rogue(ws, valid_slots)
    return ws and not ws.special and ws.id and ws.id >= 1
        and not valid_slots[math.floor((ws.id - 1) / per_monitor) + 1]
end

local function center_window_if_needed(win)
    if not win or not win.floating or not win.monitor then return end
    local at, sz, m = win.at or {}, win.size or {}, win.monitor
    local wx, wy = at.x or at[1] or 0, at.y or at[2] or 0
    local ww, wh = sz.x or sz[1] or 0, sz.y or sz[2] or 0
    local mx, my, mw, mh = m.x or 0, m.y or 0, m.width or 0, m.height or 0
    if wx < mx - math.max(ww, mw) or wy < my - math.max(wh, mh) or wx > mx + mw or wy > my + mh then
        hl.dispatch(hl.dsp.window.center({ window = win }))
    end
end

-- Windows pulled off a monitor that went away: address -> { from, to }.
-- A monitor that sleeps can drop off the bus (DP-1 does), so when it comes
-- back each window goes home, unless it was moved by hand in the meantime.
local displaced = {}

local function restore_displaced()
    if next(displaced) == nil then return end
    local valid_slots = get_monitor_slots()
    for _, win in ipairs(hl.get_windows()) do
        local entry = displaced[win.address]
        if entry and win.workspace and win.workspace.id == entry.to
            and valid_slots[math.floor((entry.from - 1) / per_monitor) + 1] then
            hl.dispatch(hl.dsp.window.move({ workspace = entry.from, follow = false, window = win }))
            displaced[win.address] = nil
        end
    end
    -- Anything left is gone or was moved by hand; forget it once every
    -- monitor is back.
    if valid_slots[1] and valid_slots[2] then displaced = {} end
end

local function recover_rogue_windows()
    local active_ws = hl.get_active_workspace()
    if not active_ws then return end
    local valid_slots = get_monitor_slots()
    for _, win in ipairs(hl.get_windows()) do
        if is_workspace_rogue(win.workspace, valid_slots) then
            displaced[win.address] = { from = win.workspace.id, to = active_ws.id }
            hl.dispatch(hl.dsp.window.move({ workspace = active_ws.id, window = win }))
        end
    end
end

-- Screens off (DP-1 drops off the bus when it sleeps): leave the windows
-- alone. Hyprland already parks the persistent workspaces on the remaining
-- monitor and moves them back intact, so gathering them would only scramble
-- the tiling. SUPER + CTRL + G still recovers by hand if a monitor stays gone.
local function any_screen_on()
    for _, mon in ipairs(hl.get_monitors()) do
        if mon.dpms_status then return true end
    end
    return false
end

local function recover_active_window()
    local win, active_ws = hl.get_active_window(), hl.get_active_workspace()
    if not win or not active_ws then return end
    if is_workspace_rogue(win.workspace, get_monitor_slots()) or (win.workspace and win.workspace.id ~= active_ws.id) then
        hl.dispatch(hl.dsp.window.move({ workspace = active_ws.id, window = win }))
    end
    center_window_if_needed(win)
end

local function schedule_workspace_recovery()
    hl.timer(function()
        if any_screen_on() then recover_rogue_windows() end
    end, { timeout = 150, type = "oneshot" })
end

local wallpaper_restart_pending = false

local function schedule_workspace_restore()
    -- After Hyprland has moved the persistent workspaces back.
    hl.timer(function()
        restore_displaced()
        recover_rogue_windows()
    end, { timeout = 150, type = "oneshot" })

    -- The wallpaper engine loses the returning output; restart it once the
    -- monitor has settled (one restart even if several come back at once).
    if not wallpaper_restart_pending then
        wallpaper_restart_pending = true
        hl.timer(function()
            wallpaper_restart_pending = false
            hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpaper-restart.sh")
        end, { timeout = 2000, type = "oneshot" })
    end
end

local function setup_events()
    hl.on("monitor.removed", schedule_workspace_recovery)
    hl.on("monitor.added", schedule_workspace_restore)
end

return {
    setup_events = setup_events,
    focus_local_workspace = focus_local_workspace,
    move_to_local_workspace = move_to_local_workspace,
    cycle_local_workspace = cycle_local_workspace,
    recover_active_window = recover_active_window,
    recover_rogue_windows = recover_rogue_windows,
    per_monitor = per_monitor,
}
