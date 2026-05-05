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

-- Configuration
hl.config({
    misc = {
        disable_hyprland_logo = false,
        allow_session_lock_restore = true,
        middle_click_paste = false,
        disable_splash_rendering = false,
        -- initial_workspace_tracking = 2
        vrr = 1,
        key_press_enables_dpms = true,
        animate_manual_resizes = true,
    }
})
