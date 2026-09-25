pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Headset Service tracks wireless headset state (mute status, battery milestones, connection)
// exported by jbl-quantum-tray daemon into /run/user/<uid>/jbl_quantum.
Singleton {
    id: root

    property bool available: false
    property bool connected: false
    property string model: ""
    property int battery: -1
    property bool charging: false
    property bool micMuted: false

    signal headsetMuteChanged(bool muted)
    signal headsetBatteryMilestone(int battery, bool charging, int milestone)
    signal headsetChargingChanged(bool charging, int battery)
    signal headsetConnectionChanged(bool connected)

    readonly property Timer restartTimer: Timer {
        interval: 1500
        repeat: false
        onTriggered: monitorProcess.running = true
    }

    Process {
        id: monitorProcess
        command: ["python3", "-u", Quickshell.shellPath("scripts/headset_monitor.py")]
        running: true

        onExited: exitCode => {
            console.log("headset_monitor.py exited with code", exitCode)
            root.restartTimer.start()
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text && text.trim().length > 0)
                    console.log("headset_monitor.py stderr:", text.trim())
            }
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (!data || data.trim() === "")
                    return
                try {
                    const evt = JSON.parse(data.trim())
                    if (evt.type === "init") {
                        root.available = true
                        root.connected = evt.connected ?? false
                        root.model = evt.model ?? ""
                        root.micMuted = evt.mic_muted ?? false
                        root.battery = evt.battery ?? -1
                        root.charging = evt.charging ?? false
                    } else if (evt.type === "mic_mute") {
                        root.micMuted = evt.muted
                        root.headsetMuteChanged(evt.muted)
                    } else if (evt.type === "battery_milestone") {
                        root.battery = evt.battery
                        root.charging = evt.charging
                        root.headsetBatteryMilestone(evt.battery, evt.charging, evt.milestone)
                    } else if (evt.type === "charging") {
                        root.charging = evt.charging
                        if (evt.battery !== null)
                            root.battery = evt.battery
                        root.headsetChargingChanged(evt.charging, root.battery)
                    } else if (evt.type === "connection") {
                        root.connected = evt.connected
                        if (evt.battery !== null)
                            root.battery = evt.battery
                        root.headsetConnectionChanged(evt.connected)
                    }
                } catch (e) {
                    console.log("headset_monitor parse error:", e)
                }
            }
        }
    }
}
