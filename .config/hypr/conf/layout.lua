-- -----------------------------------------------------
-- Layouts
-- -----------------------------------------------------

HYPR_SPLIT_WORKSPACES = {
    per_monitor = 10,
    monitor_order = {
        "DP-1",
        "DP-2",
    },
}

local split_workspaces = HYPR_SPLIT_WORKSPACES

hl.config({
    dwindle = {
        pseudotile = true,
        preserve_split = true,
    },


    binds = {
        workspace_back_and_forth = true,
        allow_workspace_cycles = true,
        pass_mouse_when_bound = false,
    }
})

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
