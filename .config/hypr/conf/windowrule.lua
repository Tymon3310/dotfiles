-- Generic & Multiple properties
-- =====================================================

hl.window_rule({
  name = "empty_no_blur",
  match = {
    class = "^()$",
    title = "^()$",
  },
  no_blur = true,
})

hl.window_rule {
  name = "modal_float",
  match = {
    modal = 1,
  },
  float = true,
}

-- Floating windows
-- =====================================================

hl.window_rule {
  name = "pip",
  match = {
    title = "^(Picture-in-Picture)",
  },
  float = true,
  pin = true,
  move = "((monitor_w*0.695)) ((monitor_h*0.04))",
}

hl.window_rule {
  name = "floating_generic",
  match = {
    title = "^(floating)$",
  },
  float = true,
  size = "1200 750",
}

hl.window_rule({
  name = "blueman_float",
  match = {
    class = "(.*blueman-manager.*)",
  },
  float = true,
})

hl.window_rule({
  name = "nm_editor_float",
  match = {
    class = "(.*nm-connection-editor.*)",
  },
  float = true,
})

hl.window_rule({
  name = "qalculate_float",
  match = {
    class = "(.*qalculate-gtk.*)",
  },
  float = true,
})

hl.window_rule {
  name = "pavucontrol_main",
  match = {
    class = "(.*org.pulseaudio.pavucontrol.*)",
  },
  float = true,
  size = "700 600",
  center = true,
  pin = true,
}

hl.window_rule {
  name = "pavucontrol_qt",
  match = {
    class = "(.*pavucontrol-qt.*)",
  },
  float = true,
  size = "700 600",
  center = true,
  pin = true,
}

hl.window_rule {
  name = "pwvucontrol",
  match = {
    class = "(.*com.saivert.pwvucontrol.*)",
  },
  float = true,
  size = "700 600",
  center = true,
  pin = true,
}

-- Dialog & Picker windows
-- =====================================================

hl.window_rule {
  name = "share_picker",
  match = {
    class = "hyprland-share-picker",
  },
  float = true,
  pin = true,
  size = "600 400",
  center = true,
}

hl.window_rule {
  name = "kde_file_picker",
  match = {
    class = "^(org.freedesktop.impl.portal.desktop.kde)$",
    title = "^(Enter name of file to save to|Save As|Open File|Select Folder).*$",
  },
  float = true,
  size = "1200 750",
  center = true,
}

hl.window_rule {
  name = "kde_choose_app_fix",
  match = {
    class = "^(org.freedesktop.impl.portal.desktop.kde)$",
    title = "^(Choose Application)$",
  },
  float = true,
  size = "600 450",
  center = true,
}

hl.window_rule {
  name = "zen_download_fix",
  match = {
    class = "^(zen-twilight)$",
    title = "^(Opening|Save As).*$",
  },
  float = true,
  size = "540 317",
  center = true,
  fullscreen = false,
  suppress_event = "fullscreen maximize activate",
}


-- Workspace specific
-- =====================================================

hl.window_rule {
  name = "btop",
  match = {
    class = "(btop)",
  },
  float = true,
  workspace = "special:btop",
  size = "1200 750",
}

hl.window_rule {
  name = "discord_workspace",
  match = {
    class = "(discord)",
  },
  workspace = "3 silent",
}

hl.window_rule {
  name = "streamcontroller_workspace",
  match = {
    class = "(com.core447.StreamController)",
  },
  workspace = "10 silent",
}

hl.window_rule {
  name = "opendeck_workspace",
  match = {
    class = "(opendeck)",
  },
  workspace = "10 silent",
}

hl.window_rule {
  name = "spotify_workspace",
  match = {
    class = "(spotify)",
  },
  workspace = "13 silent",
}

-- No screen share
-- =====================================================

hl.window_rule {
  name = "bitwarden",
  match = {
    class = "(Bitwarden)",
  },
  float = true,
  size = "1200 700",
  center = true,
  no_screen_share = 1,
}

hl.window_rule {
  name = "private_browsing",
  match = {
    title = "(.*Private Browsing)",
  },
  no_screen_share = 1,
}

hl.window_rule {
  name = "adult_content",
  match = {
    title = "(.*porn.*)",
  },
  no_screen_share = 1,
}

hl.window_rule {
  name = "tor_browser",
  match = {
    class = "(.*Tor Browser)",
  },
  no_screen_share = 1,
}

-- Layer rules
-- =====================================================

hl.layer_rule {
  name = "vicinae_dim",
  match = {
    namespace = "vicinae",
  },
  dim_around = true,
}

hl.layer_rule {
  name = "notify",
  match = {
    namespace = "swaync-notification-window",
  },
  animation = "slide right",
}


-- Fixes
-- =====================================================

hl.window_rule {
  name = "jetbrains_tooltips",
  match = {
    class = "(jetbrains-.*)",
    title = "^()$",
  },
  no_focus = true,
}

hl.window_rule {
  name = "jetbrains_popups",
  match = {
    class = "(jetbrains-.*)",
    title = "(win.*)",
  },
  no_focus = true,
}
