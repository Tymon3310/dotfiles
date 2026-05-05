-- Core system setup
require("conf.monitor")
require("conf.environment")

-- Configuration and helpers (load before input/keybinding)
require("conf.misc")

-- Input and key handling
require("conf.keyboard")
require("conf.keybinding")

-- Startup services and autostart apps
require("conf.autostart")

-- Window appearance and behavior
require("conf.decoration")
require("conf.layout")
require("conf.windowrule")

-- Visual effects and animation
require("conf.animation")

-- Custom user overrides
require("conf.custom")
