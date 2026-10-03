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

-- Btop Window Management
function find_btop_window()
    for _, window in ipairs(hl.get_windows()) do
        if window.class == "btop" then
            return window
        end
    end
end

function toggle_btop_special()
    local window = find_btop_window()
    if window then
        hl.dispatch(hl.dsp.workspace.toggle_special("btop"))
        hl.dispatch(hl.dsp.window.center({ window = window }))
    else
        hl.exec_cmd("kitty --class btop --config ~/.config/kitty/headless.conf -e btop", { workspace = "special:btop" })
    end
end

-- Bitwarden Window Handler
hl.on("window.title", function(client)
    if client.title and client.title:match("Extension: %(Bitwarden Password Manager%)") then
        if not client.floating then
            hl.dispatch(hl.dsp.window.float({ action = "on", window = client }))
        end
        local monitor = client.monitor or hl.get_active_monitor()
        local mon_x = monitor and monitor.x or 0
        local mon_y = monitor and monitor.y or 0

        hl.dispatch(hl.dsp.window.resize({ x = 400, y = 600, window = client }))
        hl.dispatch(hl.dsp.window.move({ x = mon_x + 60, y = mon_y + 80, window = client }))
    end
end)

