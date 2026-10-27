hl.config({
    misc = {
        disable_hyprland_logo = false,
        allow_session_lock_restore = true,
        -- Keep drawing the desktop under the lock surface, so Quickshell's
        -- unlock can fade onto the live screen instead of cutting to it.
        -- The lock surface is opaque while locked, so nothing shows through.
        session_lock_xray = true,
        middle_click_paste = false,
        disable_splash_rendering = false,
        initial_workspace_tracking = 0,
        key_press_enables_dpms = true,
        animate_manual_resizes = true,
    }
})

local pref = require("conf.pref")

local function toggle_btop_special()
    local window = hl.get_windows({ class = "btop" })[1]
    if not window then
        hl.exec_cmd(pref.BTOP, { workspace = "special:btop" })
        return
    end
    local showing = hl.get_active_special_workspace()
    hl.dispatch(hl.dsp.workspace.toggle_special("btop"))
    -- Only when opening it; recentering on hide is wasted work.
    if not (showing and showing.name == "special:btop") then
        hl.dispatch(hl.dsp.window.center({ window = window }))
    end
end

-- The Bitwarden browser popup gets its final title only after it opens, so a
-- window rule can't catch it. Place it once; later title changes leave it be.
local BITWARDEN_POPUP = "Extension: (Bitwarden Password Manager)"
local placed = {}

hl.on("window.title", function(client)
    if placed[client.stable_id] or not (client.title and client.title:find(BITWARDEN_POPUP, 1, true)) then
        return
    end
    placed[client.stable_id] = true

    if not client.floating then
        hl.dispatch(hl.dsp.window.float({ action = "on", window = client }))
    end
    local monitor = client.monitor or hl.get_active_monitor()
    local mon_x = monitor and monitor.x or 0
    local mon_y = monitor and monitor.y or 0

    hl.dispatch(hl.dsp.window.resize({ x = 400, y = 600, window = client }))
    hl.dispatch(hl.dsp.window.move({ x = mon_x + 60, y = mon_y + 80, window = client }))
end)

hl.on("window.destroy", function(client)
    if client and client.stable_id then placed[client.stable_id] = nil end
end)

return {
    toggle_btop_special = toggle_btop_special,
}
