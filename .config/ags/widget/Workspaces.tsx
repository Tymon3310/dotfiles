import { execAsync } from "ags/process"
import { createPoll } from "ags/time"
import { Gtk, Gdk } from "ags/gtk4"
import { createState, onMount, For } from "ags"

export default function Workspaces({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const [workspaces, setWorkspaces] = createState<any[]>([])
  const [focusedId, setFocusedId] = createState<number>(1)

  const update = async () => {
    try {
      const monName = gdkmonitor.get_connector() || ""
      const [wsOut, monOut] = await Promise.all([
        execAsync("hyprctl workspaces -j").catch(() => "[]"),
        execAsync("hyprctl monitors -j").catch(() => "[]")
      ])
      
      const ws = JSON.parse(wsOut)
      const mons = JSON.parse(monOut)
      const currentMon = mons.find((m: any) => m.name === monName)
      
      let currentFocusedId = focusedId()
      if (currentMon) {
        currentFocusedId = currentMon.activeWorkspace.id
        if (currentFocusedId !== focusedId()) {
          setFocusedId(currentFocusedId)
        }
      }

      // Show only workspaces with windows OR the currently focused one
      const filteredWs = ws
        .filter((w: any) => 
          w.monitor === monName && 
          w.id > 0 && 
          (w.windows > 0 || w.id === currentFocusedId)
        )
        .sort((a: any, b: any) => a.id - b.id)

      // Only update if the workspace IDs have changed to prevent flickering
      const currentIds = workspaces().map(w => w.id).join(",")
      const nextIds = filteredWs.map((w: any) => w.id).join(",")
      
      if (currentIds !== nextIds) {
        setWorkspaces(filteredWs)
      }
    } catch (e) {
      console.error(e)
    }
  }

  onMount(() => {
    update()
    const id = setInterval(update, 200) // Slightly increased for stability
    return () => clearInterval(id)
  })

  return (
    <box 
      class="Workspaces" 
      spacing={4}
      $={(self) => {
        const scroll = new Gtk.EventControllerScroll({
          flags: Gtk.EventControllerScrollFlags.VERTICAL,
        })
        scroll.connect("scroll", (_, _dx, dy) => {
          const dir = dy > 0 ? "e+1" : "e-1"
          execAsync(`hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = '${dir}' }))"`).catch(() => {})
        })
        self.add_controller(scroll)
      }}
    >
      <For each={workspaces}>
        {(ws) => (
          <button 
            class={focusedId.as(id => `workspace-item ${id === ws.id ? "focused" : ""}`)}
            onClicked={() => execAsync(`hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = '${ws.id}' }))"`).catch(() => {})}
          >
            <label label={ws.id.toString()} />
          </button>
        )}
      </For>
    </box>
  )
}
