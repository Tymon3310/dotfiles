-- ----------------------------------------------------- 
-- Animations
-- ----------------------------------------------------- 
hl.animation({
    enabled = true,
    bezier = {
        "overshot, 0.13, 0.99, 0.29, 1.1",
        "decelerate, 0.05, 0.8, 0.1, 1.0",
    },

    animation = {
        "windows, 1, 4, overshot, slide",
        "windowsIn, 1, 4, overshot, popin 80%",
        "windowsOut, 1, 4, decelerate, slide",
        "windowsMove, 1, 4, overshot, slide",
        "border, 1, 3, default",
        "borderangle, 1, 30, linear, loop",
        "fade, 1, 7, default",
        "workspaces, 1, 5, overshot, slide",
        "specialWorkspace, 1, 4, overshot, slide",
        "monitorAdded, 1, 5, overshot",
    },
})
