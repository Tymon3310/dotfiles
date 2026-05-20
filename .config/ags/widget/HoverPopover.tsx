import { Gtk } from "ags/gtk4"

export default function HoverPopover({ child, popover }: { child: any, popover: any }) {
    const pop = new Gtk.Popover({
        child: popover,
        position: Gtk.PositionType.BOTTOM,
        has_arrow: false,
        autohide: false
    })

    return (
        <box 
            $={(self) => {
                pop.set_parent(self)
                
                const motion = new Gtk.EventControllerMotion({
                    propagation_phase: Gtk.PropagationPhase.CAPTURE
                })
                
                motion.connect("enter", () => {
                    pop.popup()
                })
                
                motion.connect("leave", () => {
                    pop.popdown()
                })
                
                self.add_controller(motion)
            }}
        >
            {child}
        </box>
    )
}
