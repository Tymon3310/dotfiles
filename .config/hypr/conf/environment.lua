local pref = require("conf.pref")

hl.env("EDITOR", pref.EDITOR)

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.env("XDG_MENU_PREFIX", "arch-")

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

hl.env("GTK_USE_PORTAL", "1")

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
