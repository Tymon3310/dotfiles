import { execAsync } from "ags/process"
import { createPoll } from "ags/time"
import { Gtk } from "ags/gtk4"
import HoverPopover from "./HoverPopover"

export default function JBL() {
    const jbl = createPoll({ text: "", tooltip: "" }, 2000, async () => {
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

    return (
        <HoverPopover
            child={
                <box class="status-module jbl">
                    <label label={jbl.as(j => j.text)} class="icon" />
                </box>
            }
            popover={
                <box orientation={Gtk.Orientation.VERTICAL} spacing={10} class="popover-box">
                    <label label="JBL STATUS" class="grid-header" />
                    <box spacing={12} halign={Gtk.Align.CENTER}>
                         <label label={jbl.as(j => j.text)} class="detail-text jbl-big-icon" />
                         <label label={jbl.as(j => j.tooltip)} class="detail-text" />
                    </box>
                </box>
            }
        />
    )
}
