hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 12,
        border_size = 1,
        col = {
            active_border = 0x0070D84f,
            -- inactive_border = 0xffffffff,
        },
        layout = "dwindle",
        resize_on_border = true,
    },

    decoration = {
        rounding = 10,
        rounding_power = 4.0,
        active_opacity = 1.0,
        inactive_opacity = 0.8,
        fullscreen_opacity = 1.0,

        blur = {
            enabled = true,
            size = 5,
            passes = 4,
            new_optimizations = true,
            ignore_opacity = true,
            xray = false,
            special = true,
            popups = false,
        },

        shadow = {
            enabled = true,
            range = 30,
            render_power = 3,
            color = 0x66000000,
        },
    }
})
