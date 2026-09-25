pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "."

// OSD Service turns transient system events (Volume, Mute, Caps Lock, Num Lock)
// into unified signals for the island to morph and display.
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
                            "󰌌",
                            evt.state ? "Caps Lock ON" : "Caps Lock OFF",
                            -1
                        )
                    } else if (evt.type === "num") {
                        root.requested(
                            "󰎠",
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
