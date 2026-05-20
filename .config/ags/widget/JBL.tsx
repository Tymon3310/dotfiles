import { execAsync } from "ags/process"
import { createPoll } from "ags/time"
import { Gtk } from "ags/gtk4"
import { attachHoverDropdown, type DropdownName } from "./dropdownHelpers"

// JBL module-level poll
const jblInfo = createPoll({ text: "", tooltip: "" }, 2000, async () => {
    try {
        const out = await execAsync("/home/tymon/JBL_Baterry_Monitor/tools/waybar_jbl.py --mode icons").catch(() => "{}")
        const data = JSON.parse(out)
        return { 
            text: data.text || "󰥰", 
            tooltip: data.tooltip || "JBL Offline" 
        }
    } catch (e) {
        return { text: "󰥰", tooltip: "JBL Offline" }
    }
})

export default function JBL({ openDropdown, setup }: { openDropdown: (name: DropdownName | "none") => void, setup?: (self: Gtk.Widget) => void }) {
    return (
        <box 
            class="status-module jbl"
            $={(self) => {
                if (setup) setup(self)
                attachHoverDropdown(self, openDropdown, "jbl")
            }}
        >
            <label label={jblInfo.as(j => j.text)} class="icon" />
        </box>
    )
}

export function JBLDropdown() {
    return (
        <box orientation={Gtk.Orientation.VERTICAL} spacing={10} class="popover-box">
            <label label="JBL STATUS" class="grid-header" />
            <box spacing={12} halign={Gtk.Align.CENTER}>
                 <label label={jblInfo.as(j => j.text)} class="detail-text jbl-big-icon" />
                 <label label={jblInfo.as(j => j.tooltip)} class="detail-text" />
            </box>
        </box>
    )
}
