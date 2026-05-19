import { execAsync } from "ags/process"
import { createPoll } from "ags/time"
import { Gtk } from "ags/gtk4"

export default function Media() {
  const media = createPoll("No Media", 2000, async () => {
    try {
      const out = await execAsync("playerctl metadata --format '{{artist}} - {{title}}'")
      return out.trim() || "No Media"
    } catch (e) {
      return "No Media"
    }
  })
  
  return (
    <box class="Media">
      <button onClicked={() => execAsync("playerctl play-pause").catch(() => {})}>
        <label label={media} class="media-label" />
      </button>
    </box>
  )
}
