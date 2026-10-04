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
        local _, __, ___ = focus_dsp[id], move_dsp[id], move_follow_dsp[id]
    end
end

local function monitor_slot(mon)
    return mon and mon.name and monitor_slots[mon.name]
end

local function get_current_slot()
    local win = hl.get_active_window()
    return monitor_slot(hl.get_active_monitor())
        or monitor_slot(hl.get_monitor_at_cursor())
        or monitor_slot(win and win.monitor)
        or 1
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
        local mon = hl.get_active_monitor()
        local active = hl.get_active_workspace(mon and mon.name)
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
        hl.dispatch(hl.dsp.window.center(win.address))
    end
end

local function recover_windows(center)
    local active_ws = hl.get_active_workspace()
    if not active_ws then return end
    local valid_slots = get_monitor_slots()
    for _, win in ipairs(hl.get_windows()) do
        if is_workspace_rogue(win.workspace, valid_slots) then
            hl.dispatch(hl.dsp.window.move({ workspace = active_ws.id, window = win }))
        elseif center and win.floating then
            center_window_if_needed(win)
        end
    end
end

local function recover_rogue_windows() return recover_windows(false) end
local function recover_all_windows() return recover_windows(true) end

local function recover_active_window()
    local win, active_ws = hl.get_active_window(), hl.get_active_workspace()
    if not win or not active_ws then return end
    if is_workspace_rogue(win.workspace, get_monitor_slots()) or (win.workspace and win.workspace.id ~= active_ws.id) then
        hl.dispatch(hl.dsp.window.move({ workspace = active_ws.id, window = win }))
    end
    center_window_if_needed(win)
end

local function schedule_workspace_recovery()
    hl.timer(recover_rogue_windows, { timeout = 150, type = "oneshot" })
end

local function setup_events()
    hl.on("monitor.removed", schedule_workspace_recovery)
    hl.on("monitor.added", schedule_workspace_recovery)
end

return {
    setup_events = setup_events,
    focus_local_workspace = focus_local_workspace,
    move_to_local_workspace = move_to_local_workspace,
    cycle_local_workspace = cycle_local_workspace,
    recover_active_window = recover_active_window,
    recover_rogue_windows = recover_rogue_windows,
    recover_all_windows = recover_all_windows,
    split_workspaces = split_workspaces,
    per_monitor = per_monitor,
}
