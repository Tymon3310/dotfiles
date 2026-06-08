-- Configuration
hl.config({
    misc = {
        disable_hyprland_logo = false,
        allow_session_lock_restore = true,
        middle_click_paste = false,
        disable_splash_rendering = false,
        initial_workspace_tracking = 0,
        vrr = 1,
        key_press_enables_dpms = true,
        animate_manual_resizes = true,
    }
})


-- Waybar Management
function restart_waybar()
    os.execute("pkill -9 waybar 2>/dev/null")

    hl.timer(function()
        os.execute("sleep 0.15")
        os.execute("rm -f /tmp/waybar.log")
        os.execute("waybar 2>&1 | grep '%[error%]' > /tmp/waybar.log 2>&1 &")

        hl.timer(function()
            local log_file = io.open("/tmp/waybar.log", "r")
            local error_msg = nil

            if log_file then
                local content = log_file:read("*a")
                log_file:close()
                if content and content ~= "" then
                    for line in content:gmatch("[^\n]+") do
                        if line:match("%[error%]") then
                            error_msg = line:sub(1, 120)
                            break
                        end
                    end
                end
            end

            if error_msg then
                hl.exec_cmd("hyprctl seterror 'rgba(ee6666ff)' \"" .. error_msg .. "\"")
            else
                hl.exec_cmd("hyprctl seterror disable")
            end
        end, { timeout = 2000, type = "oneshot" })
    end, { timeout = 50, type = "oneshot" })
end

-- Btop Window Management
local btop_base_width = 1200
local btop_base_height = 750
local main_monitor_name = "DP-1"

function find_btop_window()
    for _, window in ipairs(hl.get_windows()) do
        if window.class == "btop" then
            return window
        end
    end
end

function get_btop_size()
    local main_monitor = hl.get_monitor(main_monitor_name)
    if not main_monitor or not main_monitor.width or not main_monitor.height then
        return btop_base_width, btop_base_height
    end

    local width_ratio = btop_base_width / 2560
    local height_ratio = btop_base_height / 1440

    return math.floor(main_monitor.width * width_ratio + 0.5), math.floor(main_monitor.height * height_ratio + 0.5)
end

function normalize_btop_window()
    local window = find_btop_window()
    if not window then
        return
    end

    local width, height = get_btop_size()
    hl.dispatch(hl.dsp.window.resize({ x = width, y = height, window = window }))
    hl.dispatch(hl.dsp.window.center({ window = window }))
end

function toggle_btop_special()
    if find_btop_window() then
        hl.dispatch(hl.dsp.workspace.toggle_special("btop"))
        hl.timer(normalize_btop_window, { timeout = 120, type = "oneshot" })
    else
        hl.exec_cmd("kitty --class btop --config ~/.config/kitty/headless.conf -e btop", { workspace = "special:btop" })
        hl.timer(normalize_btop_window, { timeout = 300, type = "oneshot" })
    end
end

-- Bitwarden Window Handler
local bw_last_addr = nil

hl.on("window.title", function(client)
    if client.title:match("Extension: %(Bitwarden Password Manager%)") then
        local window_id = client.address
        local is_floating = client.floating == 1
        local monitor_id = client.monitor
        if bw_last_addr == window_id and is_floating then
            return
        end

        -- Get monitor info
        local monitor = hl.get_monitor(monitor_id)
        if not monitor then return end

        local mon_x = monitor.x
        local mon_y = monitor.y

        local target_x = mon_x + 60
        local target_y = mon_y + 80

        if not is_floating then
            -- Toggle floating
            hl.exec_cmd("hyprctl dispatch 'hl.dsp.window.float({ action = \"on\", window = \"address:" ..
                window_id .. "\" })'")
            bw_last_addr = window_id
        end

        hl.exec_cmd("hyprctl dispatch 'hl.dsp.window.resize({ x = 400, y = 600, window = \"address:" ..
            window_id .. "\" })'")
        hl.exec_cmd("hyprctl dispatch 'hl.dsp.window.move({ x = " ..
            target_x .. ", y = " .. target_y .. ", window = \"address:" .. window_id .. "\" })'")
    end
end)

-- -- Fix for apps opening on wrong workspace (especially first instances)
-- -- Moves new windows from unexpected workspaces to the currently focused workspace
-- hl.on("window.open_early", function(client)
--     -- Small delay to let Hyprland finish placing the window
--     hl.timer(function()
--         local active_ws = hl.get_active_workspace()

--         local log_file = io.open("/tmp/hypr_debug.log", "a")
--         if log_file then
--             local client_ws_id = (client and client.workspace) and client.workspace.id or "nil"
--             local active_ws = hl.get_active_workspace()
--             local active_ws_id = active_ws and active_ws.id or "nil"
--             local active_mon = hl.get_active_monitor()
--             local active_mon_name = active_mon and active_mon.name or "nil"
--             local active_mon_focused = active_mon and tostring(active_mon.focused) or "nil"
--             local active_ws_with_mon = hl.get_active_workspace(active_mon)
--             local active_ws_with_mon_id = active_ws_with_mon and active_ws_with_mon.id or "nil"

--             log_file:write(string.format("[%s] open_early timer:\n", os.date("%H:%M:%S")))
--             log_file:write(string.format("  client: class=%s, title=%s, ws=%s\n", client and client.class or "nil",
--                 client and client.title or "nil", tostring(client_ws_id)))
--             log_file:write(string.format("  active_ws: %s\n", tostring(active_ws_id)))
--             log_file:write(string.format("  active_mon: name=%s, focused=%s\n", active_mon_name, active_mon_focused))
--             log_file:write(string.format("  active_ws_with_mon: %s\n", tostring(active_ws_with_mon_id)))

--             -- Log all monitors
--             log_file:write("  monitors:\n")
--             for _, m in ipairs(hl.get_monitors() or {}) do
--                 log_file:write(string.format("    - name=%s, id=%s, focused=%s\n", m.name, m.id, tostring(m.focused)))
--             end

--             -- Log all workspaces
--             log_file:write("  workspaces:\n")
--             for _, w in ipairs(hl.get_workspaces() or {}) do
--                 local w_mon_name = w.monitor and w.monitor.name or "nil"
--                 log_file:write(string.format("    - id=%d, name=%s, monitor=%s, active=%s, visible=%s\n", w.id, w.name,
--                     w_mon_name, tostring(w.active), tostring(w.visible)))
--             end
--             log_file:close()
--         end

--         if not active_ws or not client or not client.workspace then return end

--         -- Check if window is on a different workspace than the active one
--         if client.workspace.id ~= active_ws.id then
--             -- Move it to the currently focused workspace
--             hl.dispatch(hl.dsp.window.move({ workspace = active_ws.id, window = client.address }))
--         end
--     end, { timeout = 50, type = "oneshot" })
-- end)

-- Screenshot Tool Management
function trigger_screenshot(mode, instant)
    mode = mode or "region"
    instant = instant or "0"

    -- Generate a unique timestamp in nanoseconds
    local f_time = io.popen("date +%s%N")
    local timestamp = f_time:read("*a"):gsub("%s+", "")
    f_time:close()

    local tmp_dir = "/tmp"

    -- Get active monitors from hl.get_monitors()
    local screens = {}
    local monitors = hl.get_monitors()
    if monitors then
        for _, m in ipairs(monitors) do
            if m.name and m.disabled == false then
                table.insert(screens, m.name)
            elseif m.name and m.disabled == nil then
                table.insert(screens, m.name)
            end
        end
    end

    -- Fallback to parsing from hyprctl if hl.get_monitors() was empty
    if #screens == 0 then
        local f_mon = io.popen("hyprctl monitors -j")
        local json_str = f_mon:read("*a")
        if f_mon then f_mon:close() end
        if json_str then
            for name in json_str:gmatch('"name":%s*"([^"]+)"') do
                table.insert(screens, name)
            end
        end
    end

    -- Fallback default
    if #screens == 0 then
        screens = {"DP-1", "DP-2"}
    end

    -- Construct the single shell command chain
    local cmd = "pkill -9 -x grim 2>/dev/null; pids=(); "
    for _, s in ipairs(screens) do
        local ppm_path = tmp_dir .. "/quickshell-screenshot-" .. timestamp .. "-" .. s .. ".ppm"
        cmd = cmd .. "timeout 3 grim -t ppm -o " .. s .. " " .. ppm_path .. " & pids+=($!); "
    end

    -- Check if quickshell main shell is running
    local main_running = false
    local f_list = io.popen("quickshell list -a")
    if f_list then
        local list_str = f_list:read("*a") or ""
        f_list:close()
        if list_str:find("/quickshell/shell.qml") then
            main_running = true
        end
    end

    if main_running then
        cmd = cmd .. "quickshell ipc -p ~/.config/quickshell call screenshot trigger " .. timestamp .. " " .. mode .. " " .. instant .. "; "
    else
        cmd = cmd .. "QS_ID=" .. timestamp .. " QS_MODE=" .. mode .. " QS_INSTANT=" .. instant .. " quickshell -p ~/.config/quickshell/screenshot -n & "
    end

    cmd = cmd .. "for pid in \"${pids[@]}\"; do wait \"$pid\" 2>/dev/null; done; "
    cmd = cmd .. "touch " .. tmp_dir .. "/quickshell-screenshot-" .. timestamp .. ".done"

    -- Run in background to avoid blocking Hyprland main loop
    os.execute("(" .. cmd .. ") &")
end
