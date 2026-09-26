// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P O W E R   R O W                                                      │
// │   session actions · destructive ones ask twice                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../../theme"
import "../../../services"
import "../../../components"

// Built from SessionService's list, so an action is a row of data.
// Actions that end the session arm on the first click (red, labelled) and run
// on the second. Lock and suspend run at once. Shift-clicking restart boots to UEFI.
RowLayout {
    id: root

    property string armed: ""
    property bool armedUefi: false

    // The panel closes on any action. Lock in particular captures the screen,
    // which would otherwise include the panel.
    signal ran(string action)

    spacing: 4

    readonly property Timer disarm: Timer {
        interval: 3000
        onTriggered: {
            root.armed = ""
            root.armedUefi = false
        }
    }

    Repeater {
        model: SessionService.actions

        Rectangle {
            id: button

            required property var modelData
            readonly property bool isArmed: root.armed === button.modelData.id

            Layout.preferredWidth: button.isArmed ? label.implicitWidth + 34 : 32
            Layout.preferredHeight: 28
            radius: Theme.radiusSmall

            color: {
                if (button.isArmed)
                    return Theme.red
                return mouse.containsMouse ? Theme.islandSurfaceHover : "transparent"
            }
            border.color: button.isArmed ? Theme.red
                : (mouse.containsMouse ? Theme.islandBorder : "transparent")
            border.width: 1

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: button.modelData.icon
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    color: {
                        if (button.isArmed)
                            return Theme.accentText
                        return mouse.containsMouse ? Theme.accent : Theme.text
                    }
                }

                Text {
                    id: label
                    visible: button.isArmed
                    text: button.modelData.id === "reboot" && root.armedUefi ? "UEFI" : button.modelData.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.accentText
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: (event) => {
                    const shiftPressed = Boolean(event.modifiers & Qt.ShiftModifier)
                    if (!button.modelData.destructive || button.isArmed) {
                        const isUefi = (button.modelData.id === "reboot" && (root.armedUefi || shiftPressed))
                        const actionToRun = isUefi ? "reboot-uefi" : button.modelData.id
                        root.armed = ""
                        root.armedUefi = false
                        root.disarm.stop()
                        SessionService.run(actionToRun)
                        root.ran(actionToRun)
                        return
                    }
                    root.armed = button.modelData.id
                    root.armedUefi = (button.modelData.id === "reboot" && shiftPressed)
                    root.disarm.restart()
                }
            }
        }
    }
}
