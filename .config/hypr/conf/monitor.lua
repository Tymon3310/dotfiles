

hl.monitor ({
    output = "DP-1",
    mode = "2560x1440@164.96Hz",
    position = "auto-left",
    scale = 1,
    bitdepth = 10,
    supports_wide_color = 1,
    supports_hdr = 1
})
hl.monitor ({
    output = "DP-2",
    mode = "1920x1080@144.00Hz",
    position = "auto-right",
    scale = 1,
    bitdepth = 10,
    supports_wide_color = 1,
    supports_hdr = 0
})
hl.monitor ({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
    supports_wide_color = 0,
    supports_hdr = 0
})