import app from "ags/gtk4/app"
import { Astal, Gtk, Gdk } from "ags/gtk4"
import Pango from "gi://Pango"
import { execAsync } from "ags/process"
import { createPoll } from "ags/time"
import Workspaces from "./Workspaces"
import { Audio, CPU, RAM } from "./SystemStatus"
import Dashboard from "./Dashboard"
import SysTray from "./Tray"
import JBL from "./JBL"
import SwayNC from "./SwayNC"

function WindowTitle() {
  const title = createPoll("Desktop", 2000, async () => {
    try {
      const out = await execAsync("hyprctl activewindow -j").catch(() => "{}")
      const win = JSON.parse(out)
      return win.title || "Desktop"
    } catch (e) {
      return "Desktop"
    }
  })

  return (
    <box class="WindowTitle">
      <label label={title} max_width_chars={60} ellipsize={Pango.EllipsizeMode.END} />
    </box>
  )
}

function MediaIsland() {
  const media = createPoll({ status: "Stopped", title: "" }, 1000, async () => {
    try {
      const [status, title] = await Promise.all([
        execAsync("playerctl -p spotify status").catch(() => "Stopped"),
        execAsync("playerctl -p spotify metadata title").catch(() => ""),
      ])
      return { status, title }
    } catch (e) {
      return { status: "Stopped", title: "" }
    }
  })

  return (
    <menubutton class="MediaIsland">
      <label label={media.as(m => m.title ? `󰐊 ${m.title}` : "󰐊 Spotify")} />
      <popover>
        <Dashboard />
      </popover>
    </menubutton>
  )
}

function Clock() {
  const time = createPoll("", 1000, "date '+%H:%M:%S'")
  const date = createPoll("", 60000, "date '+%b %d, %Y'")

  return (
    <menubutton class="Clock">
      <label label={time} class="clock-label" />
      <popover>
        <box orientation={Gtk.Orientation.VERTICAL} class="popover-box">
          <label label={date} class="section-title" />
          <Gtk.Calendar />
        </box>
      </popover>
    </menubutton>
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
    >
      <centerbox 
        class="centerbox"
        start_widget={
          <box halign={Gtk.Align.START} spacing={12}>
            <Workspaces gdkmonitor={gdkmonitor} />
            <WindowTitle />
          </box>
        }
        center_widget={
          <box halign={Gtk.Align.CENTER}>
            <MediaIsland />
          </box>
        }
        end_widget={
          <box halign={Gtk.Align.END} spacing={2}>
            <SysTray />
            <box class="separator small" />
            <CPU />
            <RAM />
            <JBL />
            <Audio />
            <SwayNC />
            <box class="separator" />
            <Clock />
            <Power />
          </box>
        }
      />
    </window>
  )
}
