import QtQuick
import QtQuick.Layouts
import Quickshell

import "../theme"
import "../services"

// A side screen's part on the lock: the weather, large, with the hours
// ahead, then the agents and what arrived while away. Only names and
// states: nothing anyone wrote shows here.
Item {
    id: root

    property real reveal: 1
    // When the screen locked: notifications since then count as missed.
    property real since: Date.now()

    readonly property int unit: Math.round(root.height / 100)

    function part(index: int): real {
        return Math.max(0, Math.min(1, (root.reveal - index * 0.1) / 0.6))
    }

    readonly property var missed: {
        NotificationService.revision
        const counts = {}
        const order = []
        for (const key of NotificationService.order) {
            const entry = NotificationService.entries[key]
            if (!entry || entry.time < root.since)
                continue
            if (!(entry.appName in counts)) {
                counts[entry.appName] = 0
                order.push(entry.appName)
            }
            counts[entry.appName] += 1
        }
        return order.map(app => ({ app: app, count: counts[app] }))
    }

    readonly property var agents: AgentService.agents.filter(agent => agent.state !== "idle")

    function agentColor(state: string): color {
        if (state === "waiting" || state === "error")
            return Theme.accent
        if (state === "working")
            return Theme.green
        return Theme.textMuted
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.leftMargin: Math.round(root.width * 0.09)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(root.width * 0.46)
        spacing: root.unit * 4

        // Weather.
        ColumnLayout {
            visible: WeatherService.available
            spacing: root.unit
            opacity: root.part(0)
            transform: Translate { y: 16 * (1 - root.part(0)) }

            RowLayout {
                spacing: root.unit * 2

                Text {
                    text: WeatherService.glyph
                    font.family: Theme.fontMono
                    font.pixelSize: root.unit * 12
                    color: Theme.text
                }

                Text {
                    text: `${WeatherService.temperature}°`
                    font.family: "Google Sans Display"
                    font.pixelSize: root.unit * 16
                    color: Theme.text
                }

                ColumnLayout {
                    Layout.leftMargin: root.unit
                    spacing: 2

                    Text {
                        text: WeatherService.description
                        font.family: Theme.fontFamily
                        font.pixelSize: root.unit * 2.4
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: `Feels ${WeatherService.feelsLike}°  ·  ${WeatherService.high}° / ${WeatherService.low}°`
                        font.family: Theme.fontFamily
                        font.pixelSize: root.unit * 1.7
                        color: Theme.text
                        opacity: 0.6
                    }
                }
            }

            // The next few blocks of hours.
            RowLayout {
                spacing: root.unit * 4

                Repeater {
                    model: WeatherService.ahead

                    ColumnLayout {
                        required property var modelData
                        spacing: 2

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: `${String(modelData.hour).padStart(2, "0")}:00`
                            font.family: Theme.fontFamily
                            font.pixelSize: root.unit * 1.5
                            color: Theme.text
                            opacity: 0.55
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.glyph
                            font.family: Theme.fontMono
                            font.pixelSize: root.unit * 2.6
                            color: Theme.text
                            opacity: 0.85
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: `${modelData.temperature}°`
                            font.family: Theme.fontFamily
                            font.pixelSize: root.unit * 1.8
                            font.weight: Font.Medium
                            color: Theme.text
                        }
                    }
                }
            }
        }

        // Agents at work, or waiting for you.
        ColumnLayout {
            visible: root.agents.length > 0
            spacing: root.unit * 1.2
            opacity: root.part(1)
            transform: Translate { y: 16 * (1 - root.part(1)) }

            Text {
                text: "AGENTS"
                font.family: Theme.fontFamily
                font.pixelSize: root.unit * 1.4
                font.weight: Font.DemiBold
                font.letterSpacing: root.unit * 0.3
                color: Theme.text
                opacity: 0.5
            }

            Repeater {
                model: root.agents.slice(0, 4)

                RowLayout {
                    required property var modelData
                    spacing: root.unit * 1.2

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        width: root.unit
                        height: root.unit
                        radius: width / 2
                        color: root.agentColor(modelData.state)
                    }

                    Text {
                        text: modelData.title || modelData.agent || "Agent"
                        font.family: Theme.fontFamily
                        font.pixelSize: root.unit * 2
                        font.weight: Font.Medium
                        color: Theme.text
                        elide: Text.ElideRight
                        Layout.maximumWidth: root.width * 0.26
                    }

                    Text {
                        text: (modelData.label || "").split(" · ").slice(-1)[0] || modelData.state
                        font.family: Theme.fontFamily
                        font.pixelSize: root.unit * 1.7
                        color: root.agentColor(modelData.state)
                    }
                }
            }
        }

        // What arrived while away: app names and counts.
        ColumnLayout {
            visible: root.missed.length > 0
            spacing: root.unit * 1.2
            opacity: root.part(2)
            transform: Translate { y: 16 * (1 - root.part(2)) }

            Text {
                text: "WHILE YOU WERE AWAY"
                font.family: Theme.fontFamily
                font.pixelSize: root.unit * 1.4
                font.weight: Font.DemiBold
                font.letterSpacing: root.unit * 0.3
                color: Theme.text
                opacity: 0.5
            }

            Repeater {
                model: root.missed.slice(0, 5)

                Text {
                    required property var modelData
                    text: `${modelData.app}  ·  ${modelData.count}`
                    font.family: Theme.fontFamily
                    font.pixelSize: root.unit * 2
                    color: Theme.text
                    opacity: 0.85
                }
            }
        }
    }

    // The month, on the right.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    MonthGrid {
        anchors.right: parent.right
        anchors.rightMargin: Math.round(root.width * 0.09)
        anchors.verticalCenter: parent.verticalCenter
        today: clock.date
        cell: Math.round(root.unit * 5.6)
        fontFamily: Theme.fontFamily
        textColor: Theme.text
        accentColor: Theme.accent
        accentTextColor: Theme.accentText
        opacity: root.part(1)
        transform: Translate { y: 16 * (1 - root.part(1)) }
    }
}
