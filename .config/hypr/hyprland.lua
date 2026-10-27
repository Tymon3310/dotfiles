require("conf.monitor")
require("conf.environment")

require("conf.misc")

require("conf.keybinding")

require("conf.autostart")

require("conf.decoration")
require("conf.layout")
require("conf.windowrule")

require("conf.animation")

local custom_file = io.open(os.getenv("HOME") .. "/.config/hypr/conf/custom.lua", "r")
if custom_file then
    io.close(custom_file)
    require("conf.custom")
end

hl.bind("CTRL + SHIFT + 2", hl.dsp.global("com.t3tools.T3Code:capture-window"))
