// What the resting island shows for a few seconds when an agent session
// finishes, needs input or errors (AgentService.alert): a tinted icon with
// ripples, what happened, and what the session is about. Click focuses that
// session's window.

import QtQuick

import "../../theme"
import "../../services"

Item {
    id: root

    readonly property string kind: AgentService.alert.kind
    readonly property color tint: root.kind === "error" ? Theme.indicatorBad
        : root.kind === "waiting" ? Theme.indicatorWarn : Theme.indicatorGood
    readonly property string glyph: root.kind === "error" ? "󰅚"
        : root.kind === "waiting" ? "󰂚" : "󰄬"

    // Restarts the entry animation for every new alert.
    property int shownAt: 0
    Connections {
        target: AgentService
        function onAlertChanged(): void {
            root.shownAt += 1
            pop.restart()
        }
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.capsuleHeight

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: 9

        Item {
            id: badge

            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20

            // Rings spreading out from the icon while the alert is up.
            Repeater {
                model: 2

                Rectangle {
                    id: ring

                    required property int index

                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    radius: 10
                    color: "transparent"
                    border.width: 1.5
                    border.color: root.tint
                    opacity: 0

                    SequentialAnimation {
                        running: root.visible
                        loops: Animation.Infinite

                        PauseAnimation { duration: ring.index * 550 }
                        ParallelAnimation {
                            NumberAnimation { target: ring; property: "scale"; from: 1; to: 2.1; duration: 1100; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring; property: "opacity"; from: 0.7; to: 0; duration: 1100; easing.type: Easing.OutCubic }
                        }
                        PauseAnimation { duration: (1 - ring.index) * 550 }
                    }
                }
            }

            Rectangle {
                id: dot

                anchors.centerIn: parent
                width: 20
                height: 20
                radius: 10
                color: root.tint

                Text {
                    anchors.centerIn: parent
                    text: root.glyph
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                    color: "#000000"
                }
            }

            // A small pop as the alert arrives.
            SequentialAnimation {
                id: pop
                NumberAnimation { target: dot; property: "scale"; from: 0.4; to: 1.15; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { target: dot; property: "scale"; to: 1; duration: 160; easing.type: Easing.InOutQuad }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: AgentService.alert.title
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall + 1
            font.weight: Font.DemiBold
            color: Theme.text
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: AgentService.alert.detail !== ""
            width: Math.min(implicitWidth, 260)
            text: AgentService.alert.detail
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }
    }
}
