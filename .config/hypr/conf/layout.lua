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

HYPR_SPLIT_WORKSPACES = {
    per_monitor = 20,
    monitor_order = {
        "DP-1",
        "DP-2",
    },
}

local split_workspaces = HYPR_SPLIT_WORKSPACES


for monitor_index, monitor_name in ipairs(split_workspaces.monitor_order) do
    local base_workspace = (monitor_index - 1) * split_workspaces.per_monitor

    for local_workspace = 1, split_workspaces.per_monitor do
        hl.workspace_rule({
            workspace = tostring(base_workspace + local_workspace),
            monitor = monitor_name,
            persistent = true,
        })
    end
end

local per_monitor = split_workspaces.per_monitor
local num_monitors = #split_workspaces.monitor_order

-- Pre-indexed monitor slots: name -> 1-based index
local monitor_slots = {}
for index, monitor_name in ipairs(split_workspaces.monitor_order) do
    monitor_slots[monitor_name] = index
end

-- Pre-allocated dispatchers for all workspaces (zero runtime allocations)
local focus_dispatchers = {}
local move_dispatchers = {}
local move_follow_dispatchers = {}

for id = 1, num_monitors * per_monitor do
    focus_dispatchers[id] = hl.dsp.focus({ workspace = id })
    move_dispatchers[id] = hl.dsp.window.move({ workspace = id, follow = false })
    move_follow_dispatchers[id] = hl.dsp.window.move({ workspace = id, follow = true })
end

local function get_current_slot()
    local mon = hl.get_active_monitor()
    if mon and mon.name and monitor_slots[mon.name] then
        return monitor_slots[mon.name]
    end
    local cur = hl.get_monitor_at_cursor()
    if cur and cur.name and monitor_slots[cur.name] then
        return monitor_slots[cur.name]
    end
    local win = hl.get_active_window()
    if win and win.monitor and win.monitor.name and monitor_slots[win.monitor.name] then
        return monitor_slots[win.monitor.name]
    end
    return 1
end

local function get_monitor_slot(monitor)
    if not monitor then
        return get_current_slot()
    end
    return monitor_slots[monitor.name] or (monitor.id + 1)
end

local function get_workspace_id(local_workspace, monitor)
    local slot = monitor and get_monitor_slot(monitor) or get_current_slot()
    return ((slot - 1) * per_monitor) + local_workspace
end

local function focus_local_workspace(local_workspace)
    return function()
        local slot = get_current_slot()
        local ws_id = ((slot - 1) * per_monitor) + local_workspace
        local dsp = focus_dispatchers[ws_id]
        if dsp then
            hl.dispatch(dsp)
        end
    end
end

local function move_to_local_workspace(local_workspace, follow)
    return function()
        local slot = get_current_slot()
        local ws_id = ((slot - 1) * per_monitor) + local_workspace
        local dsp = follow and move_follow_dispatchers[ws_id] or move_dispatchers[ws_id]
        if dsp then
            hl.dispatch(dsp)
        end
    end
end

local function cycle_local_workspace(step)
    return function()
        local slot = get_current_slot()
        local mon = hl.get_active_monitor()
        local active_workspace = hl.get_active_workspace(mon and mon.name or nil)
        local local_workspace = 1

        if active_workspace then
            local monitor_base = (slot - 1) * per_monitor
            local candidate = active_workspace.id - monitor_base

            if candidate >= 1 and candidate <= per_monitor then
                local_workspace = candidate
            end
        end

        local next_workspace = ((local_workspace - 1 + step) % per_monitor) + 1
        local ws_id = ((slot - 1) * per_monitor) + next_workspace
        local dsp = focus_dispatchers[ws_id]
        if dsp then
            hl.dispatch(dsp)
        end
    end
end

-- Workspace recovery
local recovery_delay_ms = 150

local function get_xy(vec)
    if type(vec) ~= "table" then return 0, 0 end
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
    if not workspace or workspace.special or workspace.id < 1 then return false end
    local slot = math.floor((workspace.id - 1) / split_workspaces.per_monitor) + 1
    return not valid_slots[slot]
end

local function move_window_to_workspace(window, workspace_id)
    if not window or not workspace_id then return false end
    hl.dispatch(hl.dsp.window.move({ workspace = workspace_id }))
    return true
end

local function center_window_if_needed(window)
    if not window or not window.monitor or not window.floating then return false end
    local win_x, win_y = get_xy(window.at)
    local win_w, win_h = get_xy(window.size)
    local mon_x, mon_y = window.monitor.x, window.monitor.y
    local mon_w, mon_h = window.monitor.width, window.monitor.height
    local min_x, min_y = mon_x - math.max(win_w, mon_w), mon_y - math.max(win_h, mon_h)
    local max_x, max_y = mon_x + mon_w, mon_y + mon_h
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
    if not window or not active_workspace then return end
    local valid_slots = get_monitor_slots()
    if is_workspace_rogue(window.workspace, valid_slots) or (window.workspace and window.workspace.id ~= active_workspace.id) then
        move_window_to_workspace(window, active_workspace.id)
    end
    center_window_if_needed(window)
end

local function schedule_workspace_recovery()
    hl.timer(function()
        recover_rogue_windows()
    end, { timeout = recovery_delay_ms, type = "oneshot" })
end

local function recover_all_windows()
    local valid_slots = get_monitor_slots()
    local recovered = 0

    for _, window in ipairs(hl.get_windows()) do
        if is_workspace_rogue(window.workspace, valid_slots) then
            move_window_to_workspace(window, hl.get_active_workspace().id)
            recovered = recovered + 1
        elseif window.floating then
            center_window_if_needed(window)
        end
    end

    return recovered
end

local function schedule_window_recovery()
    hl.timer(function()
        recover_all_windows()
    end, { timeout = recovery_delay_ms, type = "oneshot" })
end

local function setup_events()
    hl.on("monitor.removed", schedule_workspace_recovery)
    hl.on("monitor.added", schedule_workspace_recovery)
    hl.on("window.open", schedule_window_recovery)
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
    per_monitor = split_workspaces.per_monitor,
}
