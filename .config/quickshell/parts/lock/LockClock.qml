import QtQuick
import Quickshell

import "../theme"
import "../services"

// The lock screen's clock: the date, a very large time, and a line of
// context (weather) under it. Left-aligned; sized from the screen height.
Item {
    id: root

    property int screenHeight: 1080

    // 0 → 1: the date, the time and the weather line rise in one after
    // another. Driven from outside (LockSurface), also in reverse.
    property real reveal: 1

    // When the screen locked: notifications since then count as missed.
    property real since: Date.now()

    readonly property int agentsWaiting: AgentService.agents
        .filter(agent => agent.state === "waiting" || agent.state === "error").length
    readonly property int agentsWorking: AgentService.agents
        .filter(agent => agent.state === "working").length
    readonly property string agentText: root.agentsWaiting > 0
        ? `${root.agentsWaiting} ${root.agentsWaiting === 1 ? "agent needs" : "agents need"} input`
        : root.agentsWorking > 0
            ? `${root.agentsWorking} ${root.agentsWorking === 1 ? "agent" : "agents"} working`
            : ""

    // App names only: nothing of what they said shows on the lock screen.
    readonly property var missed: {
        NotificationService.revision
        const keys = NotificationService.order.filter(key =>
            (NotificationService.entries[key]?.time ?? 0) >= root.since)
        const apps = []
        for (const key of keys) {
            const name = NotificationService.entries[key].appName
            if (apps.indexOf(name) < 0)
                apps.push(name)
        }
        return { count: keys.length, apps: apps }
    }
    readonly property string missedText: root.missed.count > 0
        ? `${root.missed.count} new · ${root.missed.apps.slice(0, 3).join(", ")}`
            + (root.missed.apps.length > 3 ? ` +${root.missed.apps.length - 3}` : "")
        : ""

    function part(index: int): real {
        const t = (root.reveal - index * 0.1) / 0.7
        return Math.max(0, Math.min(1, t))
    }

    readonly property int timeSize: Math.round(root.screenHeight * 0.2)
    readonly property int dateSize: Math.max(15, Math.round(root.screenHeight * 0.016))
    readonly property int infoSize: Math.max(13, Math.round(root.screenHeight * 0.0125))

    readonly property date now: clock.date

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        id: column

        spacing: 0

        Text {
            // Lined up with the digits' left edge, not the glyph box.
            x: Math.round(root.timeSize * 0.035)
            text: Qt.formatDateTime(root.now, "dddd, d MMMM")
            font.family: Theme.fontFamily
            font.pixelSize: root.dateSize
            font.weight: Font.Medium
            font.letterSpacing: 0.3
            color: Theme.text
            opacity: 0.85 * root.part(0)
            transform: Translate { y: 14 * (1 - root.part(0)) }
        }

        Text {
            id: time

            opacity: root.part(1)
            transform: Translate { y: 24 * (1 - root.part(1)) }

            text: Qt.formatDateTime(root.now, SettingsService.clockFormat || "HH:mm")
            font.family: "Google Sans Display"
            font.pixelSize: root.timeSize
            font.weight: Font.Normal
            font.letterSpacing: -root.timeSize * 0.03
            font.features: { "tnum": 1 }
            color: Theme.text
            // The font's line box is much taller than its digits; pull the
            // lines around it in.
            height: Math.round(root.timeSize * 0.92)
            verticalAlignment: Text.AlignVCenter
        }

        Row {
            x: Math.round(root.timeSize * 0.035)
            spacing: 10
            visible: WeatherService.available
            opacity: root.part(2)
            transform: Translate { y: 12 * (1 - root.part(2)) }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: WeatherService.glyph
                font.family: Theme.fontMono
                font.pixelSize: root.infoSize + 2
                color: Theme.text
                opacity: 0.85
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `${WeatherService.temperature}°  ${WeatherService.description}`
                font.family: Theme.fontFamily
                font.pixelSize: root.infoSize
                color: Theme.text
                opacity: 0.7
            }
        }

        // Agents and missed notifications, when there is anything to say.
        Row {
            x: Math.round(root.timeSize * 0.035)
            topPadding: 6
            spacing: 22
            visible: root.agentText !== "" || root.missedText !== ""
            opacity: root.part(3)
            transform: Translate { y: 12 * (1 - root.part(3)) }

            Repeater {
                model: [
                    { glyph: "󰚩", text: root.agentText, alert: root.agentsWaiting > 0 },
                    { glyph: "󰂚", text: root.missedText, alert: false }
                ].filter(item => item.text !== "")

                Row {
                    required property var modelData
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.glyph
                        font.family: Theme.fontMono
                        font.pixelSize: root.infoSize + 2
                        color: modelData.alert ? Theme.accent : Theme.text
                        opacity: modelData.alert ? 1 : 0.85
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text
                        font.family: Theme.fontFamily
                        font.pixelSize: root.infoSize
                        font.weight: modelData.alert ? Font.DemiBold : Font.Normal
                        color: modelData.alert ? Theme.accent : Theme.text
                        opacity: modelData.alert ? 1 : 0.7
                    }
                }
            }
        }
    }
}
