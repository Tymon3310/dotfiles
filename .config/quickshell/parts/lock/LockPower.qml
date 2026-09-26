import QtQuick

import "../theme"
import "../services"

// Clean power actions on the lock screen (Restart, Shut down).
// Shift-clicking restart boots to UEFI setup.
Row {
    id: root

    property string armed: ""
    property bool armedUefi: false
    spacing: 8

    readonly property Timer disarm: Timer {
        interval: 3000
        onTriggered: {
            root.armed = ""
            root.armedUefi = false
        }
    }

    component Chip: Rectangle {
        id: chip

        property string action: ""
        property string glyph: ""
        property string caption: ""

        readonly property bool isArmed: root.armed === chip.action

        width: chip.isArmed ? name.implicitWidth + Theme.capsuleHeight + 14
                            : Theme.capsuleHeight
        height: Theme.capsuleHeight
        radius: height / 2

        color: {
            if (chip.isArmed)
                return Theme.red
            return area.containsMouse ? Theme.islandSurfaceHover : Theme.island
        }
        border.width: 1
        border.color: chip.isArmed ? Theme.red : Theme.islandBorder

        Behavior on width { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

        Row {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.glyph
                font.family: Theme.fontMono
                font.pixelSize: 15
                color: Theme.text
                opacity: chip.isArmed || area.containsMouse ? 1 : 0.75
            }

            Text {
                id: name
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.isArmed
                text: chip.action === "reboot" && root.armedUefi ? "UEFI" : chip.caption
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.text
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: (event) => {
                const shiftPressed = Boolean(event.modifiers & Qt.ShiftModifier)
                if (chip.isArmed) {
                    const isUefi = (chip.action === "reboot" && (root.armedUefi || shiftPressed))
                    root.armed = ""
                    root.armedUefi = false
                    root.disarm.stop()
                    SessionService.run(isUefi ? "reboot-uefi" : chip.action)
                    return
                }
                root.armed = chip.action
                root.armedUefi = (chip.action === "reboot" && shiftPressed)
                root.disarm.restart()
            }
        }
    }

    Chip {
        action: "reboot"
        glyph: "󰜉"
        caption: "Restart"
    }

    Chip {
        action: "shutdown"
        glyph: "󰐥"
        caption: "Shut down"
    }
}
