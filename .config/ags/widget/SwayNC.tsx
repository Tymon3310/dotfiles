import { execAsync } from "ags/process"
import { createPoll } from "ags/time"
import { Gtk } from "ags/gtk4"

export default function SwayNC() {
    const notify = createPoll("", 2000, async () => {
        try {
            const out = await execAsync("swaync-client -c").catch(() => "0")
            const count = parseInt(out.trim())
            return count > 0 ? ` ${count}` : ""
        } catch (e) {
            return ""
        }
    })

    return (
        <button 
            class="status-module swaync" 
            onClicked={() => execAsync("swaync-client -t -sw").catch(() => {})}
        >
            <label label={notify} />
        </button>
    )
}
