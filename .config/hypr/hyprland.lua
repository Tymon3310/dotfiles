-- Core system setup
require("conf.monitor")
require("conf.environment")

-- Configuration and helpers
require("conf.misc")

-- Input and key handling
require("conf.keybinding")

-- Startup services and autostart apps
require("conf.autostart")

-- Window appearance and behavior
require("conf.decoration")
require("conf.layout")
require("conf.windowrule")

-- Visual effects and animation
require("conf.animation")

-- Custom user overrides (only if exists)
local custom_file = io.open(os.getenv("HOME") .. "/.config/hypr/conf/custom.lua", "r")
if custom_file then
    io.close(custom_file)
    require("conf.custom")
end
