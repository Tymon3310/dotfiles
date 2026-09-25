// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O D U L E   S E R V I C E                                            │
// │   module catalogue · glyph, figure and tint                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell

import "../theme"

// Trimmed from impasto's ModuleService to the modules extracted into `parts/`:
// the catalogue, and the one table that gives each module's chip its glyph,
// figure and tint (`ChipFace`). No bar layout, activation or open state; the
// host decides what opens where.
Singleton {
    id: root

    //   width    detail size, for a host that sizes the island before the
    //   height   detail exists
    readonly property var catalogue: [
        { id: "media",         name: "Media",         width: 380, height: 150 },
        { id: "battery",       name: "Battery",       width: 320, height: 132 },
        { id: "volume",        name: "Volume",        width: 340, height: 116 },
        { id: "brightness",    name: "Brightness",    width: 340, height: 100 },
        { id: "network",       name: "Network",       width: 356, height: 132 },
        { id: "bluetooth",     name: "Bluetooth",     width: 356, height: 132 },
        { id: "notifications", name: "Notifications", width: 380, height: 340 },
        { id: "weather",       name: "Weather",       width: 380, height: 150 },
        { id: "stats",         name: "System",        width: 380, height: 148 },
        { id: "calendar",      name: "Calendar",      width: 340, height: 330 },
        { id: "clock",         name: "Clock",
          width: SettingsService.clockShowsDate ? 240 : 150, height: Theme.capsuleHeight }
    ]

    function entry(id: string): var {
        return root.catalogue.find(item => item.id === id) ?? root.catalogue[0]
    }

    // Whether this machine has the hardware behind a module.
    function has(id: string): bool {
        switch (id) {
        case "battery":
            return BatteryService.available
        case "brightness":
            return BrightnessService.available
        case "bluetooth":
            return BluetoothService.available
        }
        return true
    }

    // ── CHIP SHAPE ──────────────────────────────────────────────────────────
    //
    // Modules with a ring face. A ring is a gauge, so the bell, with nothing
    // to measure, keeps its symbol; on/off links get an empty ring.
    readonly property var ringed: ["media", "battery", "volume", "brightness",
        "network", "bluetooth", "weather", "stats"]

    // A piece's own shape when it has one, the setting when it does not.
    function shapeOf(id: string, own: var): string {
        const chosen = own ? own : SettingsService.chipShape
        return chosen === "ring" && root.ringed.indexOf(id) >= 0 ? "ring" : "icon"
    }

    // ── GLYPH AND FIGURE ────────────────────────────────────────────────────

    function glyphOf(id: string): string {
        switch (id) {
        case "network":
            return NetworkService.icon
        case "bluetooth":
            return BluetoothService.icon
        case "volume":
            return AudioService.icon
        case "brightness":
            return BrightnessService.icon
        case "battery":
            return BatteryService.icon
        case "weather":
            return WeatherService.glyph || "󰖐"
        case "notifications":
            return NotificationService.doNotDisturb ? "󰂛" : "󰂚"
        case "media":
            if (MediaService.volumeShown)
                return MediaService.volume <= 0 ? "󰝟" : "󰕾"
            return MediaService.playing ? "󰎇" : "󰏤"
        case "stats":
            return "󰍛"
        case "calendar":
            return "󰃭"
        }
        return ""
    }

    // Never empty, so "always show the figure" applies to every module.
    function valueOf(id: string): string {
        switch (id) {
        case "volume":
            return AudioService.muted ? "Muted" : `${AudioService.volume}%`
        case "brightness":
            return `${BrightnessService.percent}%`
        case "battery":
            return `${BatteryService.percent}%`
        case "weather":
            return WeatherService.available ? `${WeatherService.temperature}°` : "--°"
        case "notifications":
            return `${NotificationService.history.length}`
        case "media":
            // Spotify's own level for a moment after it is scrolled.
            if (MediaService.volumeShown)
                return `${Math.round(MediaService.volume * 100)}%`
            return MediaService.available
                ? (MediaService.title || MediaService.identity || "Playing") : "Nothing playing"
        case "stats":
            return `${StatsService.cpu.toFixed(0)}%`
        case "network":
            return NetworkService.connectionName
        case "bluetooth":
            return BluetoothService.summary
        case "calendar":
            return Qt.formatDate(root.today.date, "ddd d")
        }
        return ""
    }

    // For the calendar's figure, which only changes at midnight.
    readonly property SystemClock today: SystemClock {
        precision: SystemClock.Minutes
    }

    // Maximum width for text figures (track title, network or device name)
    // before they are elided.
    function figureLimit(id: string): int {
        switch (id) {
        case "media":
            return 150
        case "network":
        case "bluetooth":
            return 110
        }
        return 0
    }

    // Warnings (low battery, hot CPU) use the fixed indicator hues; everything
    // else is plain text colour.
    function tintOf(id: string): color {
        switch (id) {
        case "battery":
            if (BatteryService.available && !BatteryService.charging && !BatteryService.full) {
                if (BatteryService.percent <= 10)
                    return Theme.indicatorBad
                if (BatteryService.percent <= 20)
                    return Theme.indicatorWarn
            }
            break
        case "stats":
            if (StatsService.cpu >= 90)
                return Theme.indicatorBad
            if (StatsService.cpu >= 70)
                return Theme.indicatorWarn
            break
        }
        return Theme.text
    }
}
