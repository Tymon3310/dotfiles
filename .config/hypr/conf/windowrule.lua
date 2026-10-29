-- Popups and dialogs. One set of effects, applied through two matchers:
--   * windows Hyprland already floats on its own: Wayland dialogs with a
--     parent (Firefox/Zen download and save prompts, GTK/Qt dialogs, and
--     portal pickers linked to their app) or with a fixed size.
--     X11 is left out: its menus and tooltips are windows too.
--   * portal dialogs, which come from a separate process and sometimes open
--     without a parent, so Hyprland can't tell they're dialogs.
-- Each keeps the size it asks for, capped to 60% x 70% of its monitor, and
-- may not maximize or go fullscreen (the KDE picker remembers being
-- maximized and asks for it again on every open).
-- Keep this first: later rules (PiP, btop, ...) override it.
local popup = {
  float = true,
  center = true,
  size = {
    "window_w > 50 ? min(window_w, monitor_w*0.6) : monitor_w*0.45",
    "window_h > 50 ? min(window_h, monitor_h*0.7) : monitor_h*0.55",
  },
  suppress_event = "maximize fullscreen",
  fullscreen_state = 0,
}

-- Each entry: what to match, plus any effects that differ from `popup`.
-- File pickers are browsers, so they get at least half the monitor (their
-- default 640x480 is cramped) but may grow to the cap if resized.
-- Order matters: a parented file picker matches both, and the later wins.
local popup_matchers = {
  { name = "dialog", match = { float = true, xwayland = false } },
  {
    name = "portal",
    match = { class = "org\\.freedesktop\\.impl\\.portal\\.desktop\\.(kde|gtk|gnome)|xdg-desktop-portal-(kde|gtk|gnome)" },
    size = {
      "min(max(window_w, monitor_w*0.5), monitor_w*0.6)",
      "min(max(window_h, monitor_h*0.6), monitor_h*0.7)",
    },
  },
}

for _, spec in ipairs(popup_matchers) do
  local rule = {}
  for k, v in pairs(popup) do rule[k] = v end
  for k, v in pairs(spec) do rule[k] = v end
  rule.name = "popup_" .. spec.name
  hl.window_rule(rule)
end

hl.window_rule({
  name = "empty_no_blur",
  match = {
    class = "^()$",
    title = "^()$",
  },
  no_blur = true,
})


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
    class = "(.*qalculate.*)",
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
  name = "btop",
  match = {
    class = "(btop)",
  },
  float = true,
  workspace = "special:btop",
  size = "1200 750",
  center = true,
  suppress_event = "maximize",
  fullscreen_state = 0
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
  workspace = "23 silent",
}

hl.window_rule {
  name = "spotify_workspace",
  match = {
    class = "(spotifast)",
  },
  workspace = "23 silent",
}


hl.window_rule {
  name = "bitwarden",
  match = {
    class = "(bitwarden)",
  },
  float = true,
  size = "1200 700",
  center = true,
  no_screen_share = 0,
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
