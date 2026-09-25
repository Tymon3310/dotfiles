pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "."

// OSD Service turns transient system events (Volume, Mute, Caps Lock, Num Lock, Headset Mic & Battery)
// into unified signals for the morphing island to display.
Singleton {
    id: root

    signal requested(string icon, string label, real progress)

    property bool armed: false

    readonly property Timer armTimer: Timer {
        interval: 600
        running: true
        onTriggered: root.armed = true
    }

    // Debounce timer for audio volume changes
    readonly property Timer volumeTimer: Timer {
        interval: 16
        onTriggered: {
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
            root.requested(
                AudioService.sourceMuted ? "\udb80\udf6d" : "\udb80\udf6c",
                AudioService.sourceMuted ? "Mic Muted" : "Mic Active",
                -1
            )
        }
    }

    // Headset status (JBL Quantum / wireless headset mute & battery milestones)
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

    readonly property Timer restartTimer: Timer {
        interval: 1000
        repeat: false
        onTriggered: lockMonitorProcess.running = true
    }

    // Process monitoring keyboard Caps Lock and Num Lock states
    Process {
        id: lockMonitorProcess
        command: ["python3", "-u", Quickshell.shellPath("scripts/lock_monitor.py")]
        running: true

        onExited: exitCode => {
            console.log("lockMonitorProcess exited with code", exitCode)
            root.restartTimer.start()
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim().length > 0)
                    console.log("lockMonitorProcess stderr:", text.trim())
            }
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
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
                    // Ignore malformed lines
                }
            }
        }
    }
}
