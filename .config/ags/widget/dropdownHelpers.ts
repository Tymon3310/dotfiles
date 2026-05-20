import { Gtk } from "ags/gtk4"

export type DropdownName = "dashboard" | "clock" | "cpu" | "ram" | "jbl" | "audio"

export function attachHoverDropdown(
  self: Gtk.Widget,
  openDropdown: (name: DropdownName | "none") => void,
  name: DropdownName,
) {
  const motion = new Gtk.EventControllerMotion({
    propagation_phase: Gtk.PropagationPhase.CAPTURE,
  })

  motion.connect("enter", () => openDropdown(name))
  motion.connect("leave", () => openDropdown("none"))
  self.add_controller(motion)
}
