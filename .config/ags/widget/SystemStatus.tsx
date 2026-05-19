import { execAsync } from "ags/process"
import { createPoll } from "ags/time"
import { Gtk } from "ags/gtk4"
import { createState } from "ags"
import HoverPopover from "./HoverPopover"

export function Audio() {
  const info = createPoll({ vol: "0%", mic: "0%", micMuted: false }, 2000, async () => {
    try {
      const volOut = await execAsync("wpctl get-volume @DEFAULT_AUDIO_SINK@").catch(() => "Volume: 0")
      const micOut = await execAsync("wpctl get-volume @DEFAULT_AUDIO_SOURCE@").catch(() => "Volume: 0")
      
      const vol = Math.round(parseFloat(volOut.replace("Volume: ", "").trim()) * 100) + "%"
      const micVal = parseFloat(micOut.replace("Volume: ", "").trim())
      const mic = Math.round(micVal * 100) + "%"
      const micMuted = micOut.includes("[MUTED]")
      
      return { vol, mic, micMuted }
    } catch (e) {
      return { vol: "0%", mic: "0%", micMuted: false }
    }
  })
  
  return (
    <HoverPopover
      child={
        <box class="status-module audio" spacing={4}>
          <label label=" " class="icon" />
          <label label={info.as(i => i.vol)} />
        </box>
      }
      popover={
        <box orientation={Gtk.Orientation.VERTICAL} spacing={8} class="popover-box">
          <label label="AUDIO & MIC" class="grid-header" />
          <box spacing={12}>
             <label label="󰕾 Speaker:" class="section-title" />
             <label label={info.as(i => i.vol)} class="detail-text" />
          </box>
          <box spacing={12}>
             <label label={info.as(i => i.micMuted ? "󰍭 Mic:" : "󰍬 Mic:")} class="section-title" />
             <label label={info.as(i => i.mic)} class="detail-text" />
          </box>
        </box>
      }
    />
  )
}

export function CPU() {
  const usage = createPoll(0, 2000, async () => {
     const out = await execAsync("sh -c \"top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}'\"").catch(() => "0")
     return parseFloat(out)
  })
  
  const details = createPoll({ cores: "", top: "", freq: "" }, 5000, async () => {
    try {
      const coresOut = await execAsync("./scratch/cpu.py").catch(() => "")
      const topOut = await execAsync("sh -c \"ps -eo comm,pcpu --sort=-pcpu | head -n 6 | tail -n 5 | awk '{print $1\\\":\\\"$2\\\"%\\\"}'\"").catch(() => "")
      const freqOut = await execAsync("sh -c \"grep 'cpu MHz' /proc/cpuinfo | awk '{sum+=$4} END {print sum/NR/1000}'\"").catch(() => "0")
      
      const cores = coresOut.trim().split("\n").map(line => {
        const [id, val] = line.split(":")
        const coreNum = id.replace("cpu", "")
        return `Core ${coreNum.padEnd(2)}: ${parseFloat(val).toFixed(1).padStart(5)}%`
      }).join("\n")
      
      return { cores, top: topOut.trim().replace(/:/g, ": "), freq: `${parseFloat(freqOut).toFixed(2)} GHz` }
    } catch (e) {
      return { cores: "Error", top: "", freq: "" }
    }
  })

  return (
    <HoverPopover
      child={
        <box class={usage.as(u => `status-module cpu ${u > 90 ? "critical" : u > 80 ? "warning" : ""}`)} spacing={4}>
          <label label="" class="icon" />
          <label label={usage.as(u => `${Math.round(u)}%`)} />
        </box>
      }
      popover={
        <box orientation={Gtk.Orientation.VERTICAL} spacing={10} class="popover-box">
          <label label="PROCESSOR" class="grid-header" />
          <box spacing={8}>
             <label label="Avg Frequency:" class="section-title" />
             <label label={details.as(d => d.freq)} class="detail-text" />
          </box>
          <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
             <label label="PER CORE LOAD" class="section-title" halign={Gtk.Align.START} />
             <label label={details.as(d => d.cores)} halign={Gtk.Align.START} class="detail-text" />
          </box>
          <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
             <label label="RESOURCE HOGS" class="section-title" halign={Gtk.Align.START} />
             <label label={details.as(d => d.top)} halign={Gtk.Align.START} class="detail-text" />
          </box>
        </box>
      }
    />
  )
}

export function RAM() {
  const usage = createPoll(0, 5000, async () => {
     const out = await execAsync("sh -c \"free -m | awk 'NR==2{print $3*100/$2}'\"").catch(() => "0")
     return parseFloat(out)
  })
  
  const details = createPoll({ top: "", swap: "", usedGb: "0GB" }, 5000, async () => {
    try {
      const topOut = await execAsync("sh -c \"ps -eo comm,pmem --sort=-pmem | head -n 6 | tail -n 5 | awk '{print $1\\\":\\\"$2\\\"%\\\"}'\"").catch(() => "")
      const swapOut = await execAsync("sh -c \"free -h | awk 'NR==3{print $3\\\" / \\\"$2}'\"").catch(() => "0B / 0B")
      const usedOut = await execAsync("sh -c \"free -g | awk 'NR==2{print $3\\\"GB / \\\"$2\\\"GB\\\"}'\"").catch(() => "0GB")
      return { top: topOut.trim().replace(/:/g, ": "), swap: swapOut, usedGb: usedOut }
    } catch (e) {
      return { top: "", swap: "", usedGb: "0GB" }
    }
  })

  return (
    <HoverPopover
      child={
        <box class={usage.as(u => `status-module ram ${u > 90 ? "critical" : u > 80 ? "warning" : ""}`)} spacing={4}>
          <label label="" class="icon" />
          <label label={usage.as(u => `${Math.round(u)}%`)} />
        </box>
      }
      popover={
        <box orientation={Gtk.Orientation.VERTICAL} spacing={10} class="popover-box">
          <label label="MEMORY" class="grid-header" />
          <box spacing={8}>
             <label label="Used RAM:" class="section-title" />
             <label label={details.as(d => d.usedGb)} class="detail-text" />
          </box>
          <box spacing={8}>
             <label label="Swap Usage:" class="section-title" />
             <label label={details.as(d => d.swap)} class="detail-text" />
          </box>
          <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
             <label label="TOP APPS" class="section-title" halign={Gtk.Align.START} />
             <label label={details.as(d => d.top)} halign={Gtk.Align.START} class="detail-text" />
          </box>
        </box>
      }
    />
  )
}
