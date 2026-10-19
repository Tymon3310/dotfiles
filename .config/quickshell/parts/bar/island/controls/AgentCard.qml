// Every open coding agent session (AgentService.agents, most urgent first,
// idle ones last and dimmed), in a list that scrolls: what each session is
// about (its window title), its state and project, and a click to focus its
// window.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "../../../theme"
import "../../../services"
import "../../../components"

Card {
    id: root

    padding: 12

    readonly property int total: AgentService.agents.length
    readonly property int busy: AgentService.agents.filter(agent => agent.state !== "idle").length

    function iconFor(state: string): string {
        return state === "error" ? "󰅚" : state === "waiting" ? "󰂚" : state === "done" ? "󰄬"
            : state === "idle" ? "󰒲" : "󱚥"
    }

    function colorFor(state: string): color {
        return state === "error" ? Theme.indicatorBad : state === "waiting" ? Theme.indicatorWarn
            : state === "done" ? Theme.indicatorGood
            : state === "idle" ? Theme.textMuted : Theme.accent
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "󱚥"
                font.family: Theme.fontMono
                font.pixelSize: 12
                color: AgentService.active ? Theme.accent : Theme.textMuted
            }

            Text {
                Layout.fillWidth: true
                text: "AGENTS"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6
                color: Theme.textMuted
            }

            Text {
                visible: root.total > 0
                text: root.busy > 0 && root.busy < root.total
                    ? `${root.busy} active · ${root.total}` : `${root.total}`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.features: { "tnum": 1 }
                color: Theme.textMuted
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: AgentService.agents

            ScrollBar.vertical: ScrollBar {
                policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                active: list.moving || list.flicking || hoverHandler.hovered
            }

            HoverHandler { id: hoverHandler }

            delegate: Rectangle {
                id: row

                required property var modelData

                readonly property string stateWord: {
                    const parts = (row.modelData.label || "").split(" · ")
                    return parts.length > 1 ? parts[parts.length - 1] : row.modelData.state
                }
                readonly property string name: row.modelData.agent
                    || (row.modelData.label || "").split(" · ")[0]
                readonly property string task: row.modelData.task || ""
                readonly property color tint: root.colorFor(row.modelData.state)

                // Room on the right for the scrollbar when there is one.
                width: list.width - (list.contentHeight > list.height ? 8 : 0)
                height: 40
                radius: Theme.radiusSmall
                opacity: row.modelData.state === "idle" && !rowMouse.containsMouse ? 0.65 : 1
                // Tinted rows stay in their tint on hover, plain ones in white,
                // so the fade never passes through a lighter colour.
                readonly property bool tinted: row.modelData.state === "waiting" || row.modelData.state === "error"
                color: row.tinted
                    ? Theme.tintWash(row.tint, rowMouse.containsMouse ? 0.16 : 0.08)
                    : rowMouse.containsMouse ? Theme.rowHover : Theme.rowRaised

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 7
                    anchors.rightMargin: 10
                    spacing: 10

                    // The state icon; it breathes while the agent works.
                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 13
                        color: Qt.rgba(row.tint.r, row.tint.g, row.tint.b, 0.16)

                        Text {
                            id: stateIcon
                            anchors.centerIn: parent
                            text: root.iconFor(row.modelData.state)
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                            color: row.tint

                            SequentialAnimation on opacity {
                                running: row.modelData.state === "working"
                                loops: Animation.Infinite
                                onRunningChanged: if (!running) stateIcon.opacity = 1
                                NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        // What the session is about, or the agent's name.
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: row.task || row.name
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }

                            Text {
                                text: rowMouse.containsMouse && row.modelData.address !== ""
                                    ? "Focus ›" : row.stateWord
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                font.weight: Font.Medium
                                color: rowMouse.containsMouse && row.modelData.address !== ""
                                    ? Theme.accent : row.tint
                            }
                        }

                        // Agent and project.
                        Text {
                            Layout.fillWidth: true
                            text: [row.task ? row.name : "",
                                    row.modelData.title !== row.task ? row.modelData.title : ""]
                                .filter(part => part).join(" · ") || "—"
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: row.modelData.address !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: AgentService.focusAddress(row.modelData.address)
                }
            }

            // Nothing running.
            Text {
                anchors.centerIn: parent
                visible: root.total === 0
                text: "No agents running"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }
        }
    }
}
