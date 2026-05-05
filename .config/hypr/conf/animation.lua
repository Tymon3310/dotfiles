-- -----------------------------------------------------
-- Animations
-- -----------------------------------------------------
hl.config({
    animations = {
        enabled = true,
    },
})

hl.curve("overshot", { type = "bezier", points = { { 0.13, 0.99 }, { 0.29, 1.1 } } })
hl.curve("decelerate", { type = "bezier", points = { { 0.05, 0.8 }, { 0.1, 1.0 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "overshot", style = "slide" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "overshot", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "decelerate", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "overshot", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "linear", style = "loop" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "overshot", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "overshot", style = "slide" })
hl.animation({ leaf = "monitorAdded", enabled = true, speed = 5, bezier = "overshot" })
