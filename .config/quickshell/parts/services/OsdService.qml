pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "."

Singleton {
    id: root

    // Producer API: OsdService.requested(icon, label, progress), called from
    // OsdService's own wiring, HeadsetService events, and NotificationService.
    signal requested(string icon, string label, real progress)

    property bool active: false
    property string icon: ""
    property string label: ""
    property real progress: -1

    // Set while the island is expanded: requests are dropped instead of
    // queuing a stale OSD that would flash on close.
    property bool suspended: false

    readonly property Timer expiryTimer: Timer {
        interval: 1800
        onTriggered: root.active = false
    }

    function show(icon: string, label: string, progress: real): void {
        if (!root.armed || root.suspended)
            return
        root.icon = icon
        root.label = label
        root.progress = progress
        root.active = true
        root.expiryTimer.restart()
    }

    function dismiss(): void {
        root.active = false
        root.expiryTimer.stop()
    }

    onRequested: {
        root.show(icon, label, progress)
    }

    property bool armed: false

    // Grace window after the default PipeWire node is replaced (USB
    // disconnect/reconnect reroutes the default sink/source, which always
    // fires value signals carrying the new node's levels - not user input).
    property double suppressVolumeUntil: 0
    property double suppressMicUntil: 0
    readonly property int flapGraceMs: 1500

    readonly property Timer armTimer: Timer {
        interval: 600
        running: true
        onTriggered: root.armed = true
    }

    readonly property Timer volumeTimer: Timer {
        interval: 16
        onTriggered: {
            // Reroutes (USB disconnect/reconnect) fire value signals with
            // the new node's levels; those are not user input, skip them.
            if (!AudioService.ready || Date.now() < root.suppressVolumeUntil)
                return
            root.requested(
                AudioService.icon,
                AudioService.muted ? "Muted" : `${AudioService.volume}%`,
                AudioService.muted ? 0 : (AudioService.volume / 100.0)
            )
        }
    }

    readonly property Connections audio: Connections {
        target: AudioService
        enabled: root.armed
        function onVolumeChanged(): void { root.volumeTimer.restart() }
        function onMutedChanged(): void { root.volumeTimer.restart() }
        function onSourceMutedChanged(): void {
            if (!AudioService.sourceReady || Date.now() < root.suppressMicUntil)
                return
            root.requested(
                AudioService.sourceMuted ? "\udb80\udf6d" : "\udb80\udf6c",
                AudioService.sourceMuted ? "Mic Muted" : "Mic Active",
                -1
            )
        }
    }

    // A replaced default node always fires value signals with the new
    // node's levels: arm the grace window so those are not shown as OSDs.
    readonly property Connections audioIdentity: Connections {
        target: AudioService
        function onSinkChanged(): void {
            root.suppressVolumeUntil = Date.now() + root.flapGraceMs
        }
        function onSourceChanged(): void {
            root.suppressMicUntil = Date.now() + root.flapGraceMs
        }
    }

    readonly property Timer mediaVolumeTimer: Timer {
        interval: 16
        onTriggered: {
            if (!MediaService.available) return
            const level = MediaService.volume
            const icon = (level <= 0 || MediaService.muted) ? "󰝟" : (level < 0.33 ? "󰕿" : (level < 0.66 ? "󰖀" : "󰕾"))
            const playerName = MediaService.active ? (MediaService.active.identity || "Spotify") : "Spotify"
            root.requested(
                icon,
                `${playerName} ${Math.round(level * 100)}%`,
                level
            )
        }
    }

    readonly property Connections media: Connections {
        target: MediaService
        enabled: root.armed
        function onVolumeChanged(): void {
            if (MediaService.available)
                root.mediaVolumeTimer.restart()
        }
    }

    readonly property Connections headset: Connections {
        target: HeadsetService
        enabled: root.armed

        function onHeadsetMuteChanged(muted: bool): void {
            root.requested(
                muted ? "\udb80\udf6d" : "\udb80\udf6c",
                muted ? "Headset Mic Muted" : "Headset Mic Active",
                -1
            )
        }

        function onHeadsetBatteryMilestone(battery: int, charging: bool, milestone: int): void {
            let icon = "\udb80\udecb"
            if (charging) {
                icon = "\udb80\udc84"
            } else if (battery <= 15) {
                icon = "\udb80\udc83"
            } else if (battery <= 30) {
                icon = "\udb80\udc7c"
            } else if (battery <= 50) {
                icon = "\udb80\udc7e"
            } else if (battery <= 75) {
                icon = "\udb80\udc81"
            }

            const label = charging
                ? `Headset Charging: ${battery}%`
                : (battery <= 15 ? `Headset Low: ${battery}%` : `Headset Battery: ${battery}%`)

            root.requested(
                icon,
                label,
                battery / 100.0
            )
        }

        function onHeadsetChargingChanged(charging: bool, battery: int): void {
            const batt = Math.max(0, battery)
            root.requested(
                charging ? "\udb80\udc84" : "\udb80\udecb",
                charging ? `Headset Charging: ${batt}%` : `Headset Unplugged: ${batt}%`,
                batt / 100.0
            )
        }

        function onHeadsetConnectionChanged(connected: bool): void {
            if (connected) {
                const battStr = HeadsetService.battery >= 0 ? `: ${HeadsetService.battery}%` : ""
                root.requested(
                    "\udb80\udecb",
                    `Headset Connected${battStr}`,
                    HeadsetService.battery >= 0 ? HeadsetService.battery / 100.0 : -1
                )
            } else {
                root.requested(
                    "\udb81\udfce",
                    "Headset Disconnected",
                    -1
                )
            }
        }
    }

    property int restartAttempts: 0

    readonly property Timer restartTimer: Timer {
        interval: Math.min(30000, 1000 * Math.pow(2, Math.min(root.restartAttempts, 5)))
        repeat: false
        onTriggered: lockMonitorProcess.running = true
    }

    // Process monitoring keyboard Caps Lock and Num Lock states
    // (scripts/osd.py locks: one JSON event per line).
    Process {
        id: lockMonitorProcess
        command: ["python3", "-u", Quickshell.shellPath("scripts/osd.py"), "locks"]
        running: true

        onExited: exitCode => {
            console.warn("osd.py locks exited with code", exitCode)
            root.restartAttempts++
            root.restartTimer.start()
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim().length > 0)
                    console.warn("osd.py locks stderr:", text.trim())
            }
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                root.restartAttempts = 0
                if (!root.armed)
                    return
                try {
                    const evt = JSON.parse(data.trim())
                    if (evt.type === "caps") {
                        root.requested(
                            "\udb80\udf0c",
                            evt.state ? "Caps Lock ON" : "Caps Lock OFF",
                            -1
                        )
                    } else if (evt.type === "num") {
                        root.requested(
                            "\udb80\udfa0",
                            evt.state ? "Num Lock ON" : "Num Lock OFF",
                            -1
                        )
                    }
                } catch (e) {
                }
            }
        }
    }
}
