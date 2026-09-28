// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P O W E R   R O W                                                      │
// │   bottom-left reboot / power off capsule buttons                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "."

// Restart and shut down; no suspend, since there is no session yet.
//
// The first click arms a button and the second confirms, as in the shell;
// it disarms after 3 s. Shift-click on Restart reboots to UEFI setup.
Row {
    id: root

    property bool canReboot: false
    property bool canPowerOff: false

    property string armed: ""
    property bool armedUefi: false

    signal rebootRequested(bool toUefi)
    signal powerOffRequested()

    spacing: 8

    readonly property Timer disarm: Timer {
        interval: 3000
        onTriggered: {
            root.armed = ""
            root.armedUefi = false
        }
    }

    component Chip: Capsule {
        id: chip

        required property string action
        required property string glyph
        required property string caption

        readonly property bool isArmed: root.armed === chip.action

        signal confirmed(bool toUefi)

        width: chip.isArmed ? name.implicitWidth + Theme.capsuleHeight + 16
                            : Theme.capsuleHeight
        hovered: area.containsMouse

        Behavior on width {
            NumberAnimation {
                duration: Theme.durationFast
                easing.type: Easing.OutCubic
            }
        }

        // Tint when armed: red for shutdown, warm amber for reboot
        color: chip.isArmed
            ? (chip.action === "shutdown"
                ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.45)
                : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45))
            : (chip.hovered ? Theme.islandSurfaceHover : Theme.island)

        border.color: chip.isArmed
            ? (chip.action === "shutdown" ? Theme.danger : Theme.accent)
            : Theme.islandBorder

        Row {
            anchors.centerIn: parent
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.glyph
                font.family: Theme.fontMono
                font.pixelSize: 15
                color: Theme.text
                opacity: chip.isArmed || area.containsMouse ? 1 : 0.75

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            }

            Text {
                id: name

                anchors.verticalCenter: parent.verticalCenter
                visible: chip.isArmed
                text: chip.action === "reboot" && root.armedUefi ? qsTr("UEFI Setup") : chip.caption
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
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onClicked: (event) => {
                event.accepted = true
                const shiftPressed = Boolean(event.modifiers & Qt.ShiftModifier)
                if (chip.isArmed) {
                    const toUefi = (chip.action === "reboot" && (root.armedUefi || shiftPressed))
                    root.armed = ""
                    root.armedUefi = false
                    root.disarm.stop()
                    chip.confirmed(toUefi)
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
        caption: qsTr("Restart")
        visible: root.canReboot
        onConfirmed: (toUefi) => root.rebootRequested(toUefi)
    }

    Chip {
        action: "shutdown"
        glyph: "󰐥"
        caption: qsTr("Shut down")
        visible: root.canPowerOff
        onConfirmed: () => root.powerOffRequested()
    }
}
