import app from "ags/gtk4/app"
import { Astal, Gtk, Gdk } from "ags/gtk4"
import Pango from "gi://Pango"
import Gtk4LayerShell from "gi://Gtk4LayerShell?version=1.0"
import { execAsync } from "ags/process"
import { createPoll } from "ags/time"
import { createState, For } from "ags"
import Workspaces from "./Workspaces"
import { Audio, CPU, RAM, AudioDropdown, CPUDropdown, RAMDropdown } from "./SystemStatus"
import Dashboard from "./Dashboard"
import SysTray from "./Tray"
import JBL, { JBLDropdown } from "./JBL"
import SwayNC from "./SwayNC"
import { type DropdownName } from "./dropdownHelpers"

const [winTitle, setWinTitle] = createState("Desktop")
const [winClass, setWinClass] = createState("")

// Gio and GLib types for socket connection
const Gio = imports.gi.Gio
const GLib = imports.gi.GLib

Gio._promisify(Gio.SocketClient.prototype, "connect_async", "connect_finish")
Gio._promisify(Gio.DataInputStream.prototype, "read_line_async", "read_line_finish_utf8")

async function listenToHyprland() {
  const runtimeDir = GLib.get_user_runtime_dir()
  const signature = GLib.getenv("HYPRLAND_INSTANCE_SIGNATURE")
  if (!signature) return
  const socketPath = `${runtimeDir}/hypr/${signature}/.socket2.sock`

  const client = new Gio.SocketClient()
  const address = new Gio.UnixSocketAddress({ path: socketPath })

  try {
    const connection = await client.connect_async(address, null)
    const inputStream = connection.get_input_stream()
    const dataStream = new Gio.DataInputStream({
      base_stream: inputStream,
      close_base_stream: true,
    })

    // Sync window title initially
    try {
      const out = await execAsync("hyprctl activewindow -j").catch(() => "{}")
      const win = JSON.parse(out)
      setWinTitle(win.title || "Desktop")
      setWinClass(win.class || "")
    } catch (e) {}

    while (true) {
      const [line] = await dataStream.read_line_async(GLib.PRIORITY_DEFAULT, null)
      if (line === null) break

      const idx = line.indexOf(">>")
      if (idx !== -1) {
        const name = line.substring(0, idx)
        if (name === "activewindow" || name === "activewindowv2" || name === "windowtitle") {
          try {
            const out = await execAsync("hyprctl activewindow -j").catch(() => "{}")
            const win = JSON.parse(out)
            setWinTitle(win.title || "Desktop")
            setWinClass(win.class || "")
          } catch (e) {}
        }
      }
    }
  } catch (e) {
    // Retry connection after 2 seconds
    setTimeout(() => listenToHyprland(), 2000)
  }
}

// Spawn the socket listener
listenToHyprland()

function getAppIcon(winClass: string): string {
  if (!winClass) return "system-run"
  const Display = Gdk.Display
  const DisplayDefault = Display ? Display.get_default() : null
  if (!DisplayDefault) return "system-run"
  const theme = Gtk.IconTheme.get_for_display(DisplayDefault)
  
  // Try raw class
  if (theme.has_icon(winClass)) return winClass
  
  // Try lowercase class
  const lowerClass = winClass.toLowerCase()
  if (theme.has_icon(lowerClass)) return lowerClass
  
  // Try splitting by space or dashes and taking first word (e.g. "Code - Insiders" -> "code")
  const firstWord = lowerClass.split(/[^a-z0-9-]/)[0]
  if (firstWord && theme.has_icon(firstWord)) return firstWord
  
  // Try mapping common exceptions
  if (lowerClass.includes("code")) return "com.visualstudio.code" // fallback for vs code / insiders
  if (lowerClass.includes("spotify")) return "spotify"
  if (lowerClass.includes("firefox")) return "firefox"
  if (lowerClass.includes("chrome")) return "google-chrome"
  if (lowerClass.includes("terminal")) return "utilities-terminal"
  if (lowerClass.includes("kitty")) return "kitty"
  if (lowerClass.includes("alacritty")) return "alacritty"
  
  return "system-run"
}

function WindowTitle() {
  return (
    <box class="WindowTitle" spacing={8}>
      <image icon_name={winClass.as(c => getAppIcon(c))} visible={winClass.as(c => !!c)} pixel_size={16} />
      <label label={winTitle} max_width_chars={60} ellipsize={Pango.EllipsizeMode.END} />
    </box>
  )
}

function MediaIsland({ openDropdown, activeDropdown, setup }: { openDropdown: (name: DropdownName | "none") => void, activeDropdown: () => string, setup?: (self: Gtk.Widget) => void }) {
  let lastFetch = 0
  let cachedMedia = { status: "Stopped", title: "", len: "0:00/0:00", vol: "0%" }
  let offset = 0
  const LIMIT = 20

  const media = createPoll({ status: "Stopped", title: "", len: "0:00/0:00", vol: "0%" }, 250, async () => {
    const now = Date.now()
    let titleChanged = false

    if (now - lastFetch >= 1000) {
      lastFetch = now
      try {
        const [status, title, len, volRaw] = await Promise.all([
          execAsync("playerctl -p spotify status").catch(() => "Stopped"),
          execAsync("playerctl -p spotify metadata title").catch(() => ""),
          execAsync("playerctl -p spotify metadata --format '{{duration(position)}}/{{duration(mpris:length)}}'").catch(() => ""),
          execAsync("playerctl -p spotify volume").catch(() => "0")
        ])
        const vol = Math.round(parseFloat(volRaw) * 100) + "%"
        if (title !== cachedMedia.title) {
          titleChanged = true
        }
        cachedMedia = { status, title, len, vol }
      } catch (e) {
        cachedMedia = { status: "Stopped", title: "", len: "0:00/0:00", vol: "0%" }
      }
    }

    const title = cachedMedia.title
    if (title.length > LIMIT) {
      if (titleChanged) offset = 0
      const padded = title + "   •   "
      const chars = Array.from(padded)
      const shifted = chars.slice(offset).concat(chars.slice(0, offset))
      offset = (offset + 1) % chars.length
      const titleSliced = shifted.slice(0, LIMIT).join("")
      return { ...cachedMedia, title: titleSliced }
    }

    return cachedMedia
  })

  return (
    <button 
      class="MediaIsland"
      onClicked={() => openDropdown(activeDropdown() === "dashboard" ? "none" : "dashboard")}
      $={(self) => {
        if (setup) setup(self)
        const scroll = new Gtk.EventControllerScroll({
          flags: Gtk.EventControllerScrollFlags.VERTICAL,
        })
        scroll.connect("scroll", (_, _dx, dy) => {
          if (dy > 0) execAsync("playerctl -p spotify volume 0.05-").catch(() => {})
          else execAsync("playerctl -p spotify volume 0.05+").catch(() => {})
        })
        self.add_controller(scroll)
      }}
    >
      <label label={media.as(m => {
        if (m.status === "Stopped") return "󰓄 Spotify Idle"
        const icon = m.status === "Playing" ? "󰏤" : "󰐊"
        return `${icon} ${m.title} [${m.len}] ${m.vol} 󱁗`
      })} />
    </button>
  )
}

const datePoll = createPoll("", 60000, "date '+%b %d, %Y'")

function ClockDropdown() {
  return (
    <box orientation={Gtk.Orientation.VERTICAL} class="popover-box">
      <label label={datePoll} class="section-title" />
      <Gtk.Calendar />
    </box>
  )
}

function Clock({ openDropdown, activeDropdown, setup }: { openDropdown: (name: DropdownName | "none") => void, activeDropdown: () => string, setup?: (self: Gtk.Widget) => void }) {
  const time = createPoll("", 1000, "date '+%H:%M:%S'")

  return (
    <button 
      class="Clock"
      onClicked={() => openDropdown(activeDropdown() === "clock" ? "none" : "clock")}
      $={(self) => { if (setup) setup(self) }}
    >
      <label label={time} class="clock-label" />
    </button>
  )
}

function Power() {
  return (
    <button 
      class="status-module power" 
      onClicked={() => execAsync("nwg-bar").catch(() => {})}
    >
      <label label="" /> 
    </button>
  )
}


export default function Bar(gdkmonitor: Gdk.Monitor) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

  const [activeDropdown, setActiveDropdown] = createState("none")
  const [currentChild, setCurrentChild] = createState("")

  const [dropdownVisible, setDropdownVisible] = createState(false)
  const [dropdownOffset, setDropdownOffset] = createState(0)

  let barContainerRef: Gtk.Widget | null = null
  const dropdownTriggers: Partial<Record<DropdownName, Gtk.Widget>> = {}
  let dropdownStackRef: Gtk.Stack | null = null

  function registerDropdownTrigger(name: DropdownName, widget: Gtk.Widget) {
    dropdownTriggers[name] = widget
  }

  let autoCloseTimeout: any = null
  function handleMouseEnter() {
    if (autoCloseTimeout) {
      clearTimeout(autoCloseTimeout)
      autoCloseTimeout = null
    }
  }

  function handleMouseLeave() {
    if (autoCloseTimeout) {
      clearTimeout(autoCloseTimeout)
    }
    if (activeDropdown() !== "none") {
      autoCloseTimeout = setTimeout(() => {
        openDropdown("none")
        autoCloseTimeout = null
      }, 1000)
    }
  }

  let closeTimeout: any = null
  function openDropdown(name: DropdownName | "none") {
    if (closeTimeout) {
      clearTimeout(closeTimeout)
      closeTimeout = null
    }

    if (name === "none") {
      setActiveDropdown("none")
      closeTimeout = setTimeout(() => {
        if (activeDropdown() === "none") {
          setCurrentChild("")
          setDropdownVisible(false)
        }
        closeTimeout = null
      }, 150)
    } else {
      setDropdownVisible(true)
      setCurrentChild(name)
      setActiveDropdown(name)

      // Calculate dynamic offset in next tick so the stack has rebuilt its children
      setTimeout(() => {
        const triggerWidget = dropdownTriggers[name]
        if (triggerWidget && barContainerRef) {
          const [success, x, y] = triggerWidget.translate_coordinates(barContainerRef, 0, 0)
          if (success) {
            const clickWidth = triggerWidget.get_width()
            
            // Measure stack width (which does not include margin_start) and add padding + borders (36px total)
            let dropWidth = 240
            if (dropdownStackRef) {
              const [, naturalSize] = dropdownStackRef.get_preferred_size()
              dropWidth = naturalSize.width + 36
            }
            
            let offset = x + (clickWidth / 2) - (dropWidth / 2)
            
            // Constrain offset to screen boundaries (matching the bar's 16px horizontal margin, with a 2px inward shift on the right to align with the rounded corner)
            const monitorWidth = gdkmonitor.get_geometry().width
            offset = Math.max(16, Math.min(offset, monitorWidth - dropWidth - 25))
            setDropdownOffset(offset)

            // Force the GTK Window to recalculate size and shrink immediately
            if (dropdownWin) {
              dropdownWin.set_size_request(-1, -1)
              dropdownWin.set_default_size(1, 1)
              dropdownWin.queue_resize()
            }
          }
        }
      }, 0)
    }
  }

  const dropdownWin = (
    <window
      visible={dropdownVisible.as(v => v)}
      name={`bar-dropdown-${gdkmonitor.get_connector() || "0"}`}
      class="Bar"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.NONE}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | LEFT | RIGHT}
      application={app}
      $={(self) => {
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, -8)
        currentChild.subscribe(() => {
          self.set_size_request(-1, -1)
          self.set_default_size(1, 1)
          self.queue_resize()
        })
        const hover = new Gtk.EventControllerMotion()
        hover.connect("enter", () => handleMouseEnter())
        hover.connect("leave", () => handleMouseLeave())
        self.add_controller(hover)
      }}
    >
      <revealer 
        transitionDuration={150}
        transition_type={Gtk.RevealerTransitionType.SLIDE_DOWN} 
        reveal_child={activeDropdown.as(val => val !== "none")}
      >
        <box 
          class="dropdown-area" 
          halign={Gtk.Align.START}
          margin_start={dropdownOffset}
        >
          <stack
            vhomogeneous={false}
            hhomogeneous={false}
            $={(self) => {
              dropdownStackRef = self
              self.add_named(<box />, "")
              self.add_named(<Dashboard />, "dashboard")
              self.add_named(<ClockDropdown />, "clock")
              self.add_named(<CPUDropdown />, "cpu")
              self.add_named(<RAMDropdown />, "ram")
              self.add_named(<JBLDropdown />, "jbl")
              self.add_named(<AudioDropdown />, "audio")

              
              currentChild.subscribe(() => {
                self.visible_child_name = currentChild()
              })
            }}
          />
        </box>
      </revealer>
    </window>
  )

  app.add_window(dropdownWin)

  return (
    <window
      visible
      name={`bar-${gdkmonitor.get_connector() || "0"}`}
      class="Bar"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      layer={Astal.Layer.TOP}
      anchor={TOP | LEFT | RIGHT}
      application={app}
      $={(self) => {
        Gtk4LayerShell.set_exclusive_zone(self, 40)
      }}
    >
      <box 
        orientation={Gtk.Orientation.VERTICAL} 
        class="BarContainer"
        $={(self) => {
          barContainerRef = self
          const hover = new Gtk.EventControllerMotion()
          hover.connect("enter", () => handleMouseEnter())
          hover.connect("leave", () => handleMouseLeave())
          self.add_controller(hover)
        }}
      >
        <centerbox 
          class="BarHeader centerbox"
          start_widget={
            <box halign={Gtk.Align.START} spacing={12}>
              <Workspaces gdkmonitor={gdkmonitor} />
              <WindowTitle />
            </box>
          }
          center_widget={
            <box halign={Gtk.Align.CENTER}>
              <MediaIsland openDropdown={openDropdown} activeDropdown={activeDropdown} setup={(self) => { registerDropdownTrigger("dashboard", self) }} />
            </box>
          }
          end_widget={
            <box halign={Gtk.Align.END} spacing={2}>
              <SysTray />
              <box class="separator small" />
              <CPU openDropdown={openDropdown} setup={(self) => { registerDropdownTrigger("cpu", self) }} />
              <RAM openDropdown={openDropdown} setup={(self) => { registerDropdownTrigger("ram", self) }} />
              <JBL openDropdown={openDropdown} setup={(self) => { registerDropdownTrigger("jbl", self) }} />
              <Audio openDropdown={openDropdown} setup={(self) => { registerDropdownTrigger("audio", self) }} />
              <SwayNC />
              <box class="separator" />
              <Clock openDropdown={openDropdown} activeDropdown={activeDropdown} setup={(self) => { registerDropdownTrigger("clock", self) }} />
              <Power />
            </box>
          }
        />
      </box>
    </window>
  )
}
