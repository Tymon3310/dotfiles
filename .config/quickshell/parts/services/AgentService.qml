pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    property string agent: ""
    property string state: "idle"
    property string label: ""
    property string title: ""
    property string address: ""

    function focusWindow(): void {
        if (root.address !== "") {
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + root.address])
        }
    }

    readonly property Process monitorProcess: Process {
        command: ["python3", "-u", Quickshell.shellPath("parts/scripts/agent_monitor.py")]
        running: true

        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    root.active = !!data.active
                    root.agent = data.agent || ""
                    root.state = data.state || "idle"
                    root.label = data.label || ""
                    root.title = data.title || ""
                    root.address = data.address || ""
                } catch (_) {}
            }
        }
    }
}
