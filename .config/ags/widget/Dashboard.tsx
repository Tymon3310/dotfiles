import { execAsync } from "ags/process"
import { Gtk } from "ags/gtk4"
import { createPoll } from "ags/time"
import { createState } from "ags"

export default function Dashboard() {
  const [prevRx, setPrevRx] = createState(0)
  const [prevTx, setPrevTx] = createState(0)
  const [totalLen, setTotalLen] = createState(1)

  const mediaInfo = createPoll({ title: "", artist: "", status: "Stopped" }, 500, async () => {
    try {
      const [title, artist, status] = await Promise.all([
        execAsync("playerctl -p spotify metadata title").catch(() => ""),
        execAsync("playerctl -p spotify metadata artist").catch(() => ""),
        execAsync("playerctl -p spotify status").catch(() => "Stopped")
      ])
      return { title, artist, status }
    } catch (e) {
      return { title: "", artist: "", status: "Stopped" }
    }
  })
  
  const progress = createPoll(0, 1000, async () => {
     try {
       const p = await execAsync("playerctl -p spotify metadata --format '{{position}}'").catch(() => "0")
       const l = await execAsync("playerctl -p spotify metadata --format '{{mpris:length}}'").catch(() => "1")
       const pVal = parseFloat(p)
       const lVal = parseFloat(l)
       const lenInSec = lVal / 1000000
       setTotalLen(lenInSec) 
       return lenInSec > 0 ? pVal / 1000000 / lenInSec : 0
     } catch (e) {
       return 0
     }
  })

  const system = createPoll({ cpu: "0", cpuTemp: "0", ram: "0", ramUsed: "0GB", cpuWatts: "0" }, 2000, async () => {
    try {
      const cpu = await execAsync("sh -c \"top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}'\"").catch(() => "0")
      const sensors = await execAsync("sh -c \"sensors -j | jq -r '.[\\\"zenpower-pci-00c3\\\"].Tdie.temp1_input, .[\\\"zenpower-pci-00c3\\\"].SVI2_P_Core.power1_input + .[\\\"zenpower-pci-00c3\\\"].SVI2_SoC.power2_input'\"").catch(() => "0\\n0")
      const [temp, watts] = sensors.trim().split("\n")
      const ram = await execAsync("sh -c \"free -m | awk 'NR==2{print $3*100/$2}'\"").catch(() => "0")
      const ramUsed = await execAsync("sh -c \"free -g | awk 'NR==2{print $3\\\"GB / \\\"$2\\\"GB\\\"}'\"").catch(() => "0GB")
      return { cpu, cpuTemp: temp, ram, ramUsed, cpuWatts: watts }
    } catch (e) {
      return { cpu: "0", cpuTemp: "0", ram: "0", ramUsed: "0GB", cpuWatts: "0" }
    }
  })

  const gpu = createPoll({ usage: "0", edge: "0", junction: "0", mem: "0", power: "0" }, 2000, async () => {
    try {
      const usage = await execAsync("cat /sys/class/drm/card1/device/gpu_busy_percent").catch(() => "0")
      const sensors = await execAsync("sh -c \"sensors -j | jq -r '.[\\\"amdgpu-pci-0800\\\"] | \\\"\\(.edge.temp1_input):\\(.junction.temp2_input):\\(.mem.temp3_input):\\(.PPT.power1_average)\\\"'\"").catch(() => "0:0:0:0")
      const [edge, junction, mem, power] = sensors.trim().split(":")
      return { usage: usage.trim(), edge, junction, mem, power }
    } catch (e) {
      return { usage: "0", edge: "0", junction: "0", mem: "0", power: "0" }
    }
  })

  const netSpeed = createPoll("0.0K ↓ 0.0K ↑", 2000, async () => {
    try {
      const out = await execAsync("sh -c \"grep 'eno1' /proc/net/dev | awk '{print $2 \\\" \\\" $10}'\"").catch(() => "0 0")
      const [rx, tx] = out.trim().split(" ").map(n => parseInt(n))
      const rxDelta = (rx - prevRx()) / 1024 / 2
      const txDelta = (tx - prevTx()) / 1024 / 2
      setPrevRx(rx)
      setPrevTx(tx)
      const format = (v: number) => v > 1024 ? `${(v/1024).toFixed(1)}MB/s` : `${v.toFixed(1)}KB/s`
      return `${format(rxDelta)} ↓ ${format(txDelta)} ↑`
    } catch (e) {
      return "0.0K ↓ 0.0K ↑"
    }
  })

  return (
    <box orientation={Gtk.Orientation.VERTICAL} class="Dashboard popover-box" spacing={20}>
      <box class="dashboard-section player-mini" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
        <label label={mediaInfo.as(m => m.title || "Spotify Idle")} class="player-title" max_width_chars={30} ellipsize={3} />
        <label label={mediaInfo.as(m => m.artist)} class="player-artist" />
        
        <slider 
          class="player-slider"
          value={progress}
          $={(self) => {
             // Use change-value to catch user interaction and set position
             self.connect("change-value", (_, __, value) => {
                const pos = value * totalLen()
                execAsync(`playerctl -p spotify position ${pos}`).catch(() => {})
                return false // Let it continue to update internal state
             })
          }}
        />

        <box halign={Gtk.Align.CENTER} spacing={20}>
           <button onClicked={() => execAsync("playerctl -p spotify previous").catch(() => {})} class="player-btn">
              <label label="󰒮" />
           </button>
           <button onClicked={() => execAsync("playerctl -p spotify play-pause").catch(() => {})} class="player-btn highlight">
              <label label={mediaInfo.as(m => m.status === "Playing" ? "󰏤" : "󰐊")} />
           </button>
           <button onClicked={() => execAsync("playerctl -p spotify next").catch(() => {})} class="player-btn">
              <label label="󰒭" />
           </button>
        </box>
      </box>

      <box orientation={Gtk.Orientation.VERTICAL} spacing={12} class="info-grid">
        <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
           <label label="SYSTEM:" class="section-title" halign={Gtk.Align.START} />
           <box spacing={8}>
              <label label="CPU:" class="detail-text" />
              <label label={system.as(s => `${Math.round(parseFloat(s.cpu))}% | ${Math.round(parseFloat(s.cpuTemp))}°C | ${Math.round(parseFloat(s.cpuWatts))}W`)} class="detail-text" />
           </box>
           <box spacing={8}>
              <label label="RAM:" class="detail-text" />
              <label label={system.as(s => `${s.ramUsed} (${Math.round(parseFloat(s.ram))}%)`)} class="detail-text" />
           </box>
        </box>

        <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
           <label label="GPU:" class="section-title" halign={Gtk.Align.START} />
           <box spacing={8}>
              <label label="Usage:" class="detail-text" />
              <label label={gpu.as(g => `${g.usage}% | ${Math.round(parseFloat(g.power))}W`)} class="detail-text" />
           </box>
           <box spacing={8}>
              <label label="Temps:" class="detail-text" />
              <label label={gpu.as(g => `Main ${Math.round(parseFloat(g.edge))}°C | Bridge ${Math.round(parseFloat(g.junction))}°C | NVRAM ${Math.round(parseFloat(g.mem))}°C`)} class="detail-text" />
           </box>
        </box>

        <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
           <label label="NETWORK SPEED:" class="section-title" halign={Gtk.Align.START} />
           <label label={netSpeed} halign={Gtk.Align.START} class="detail-text" />
        </box>
      </box>
    </box>
  )
}
