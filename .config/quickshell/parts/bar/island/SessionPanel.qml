// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E S S I O N   P A N E L                                              │
// │   session menu · lock, suspend, log out, reboot, shut down               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"

// The session menu. The same actions (`SessionService.actions`) and the same
// two-press guard as the control centre's power row, in a larger,
// keyboard-first layout: arrows move, Enter commits, and the pointer drives
// the same selection.
FocusScope {
    id: root

    implicitWidth: 560
    implicitHeight: 100
    width: root.implicitWidth
    height: root.implicitHeight

    signal closed()

    property int selected: 0
    property string armed: ""
    property bool armedUefi: false

    // Focus on open, or the arrows go to whatever had the keyboard before.
    Component.onCompleted: root.forceActiveFocus()

    readonly property Timer disarm: Timer {
        interval: 3000
        onTriggered: {
            root.armed = ""
            root.armedUefi = false
        }
    }

    function move(delta: int): void {
        const count = SessionService.actions.length
        root.selected = (root.selected + delta + count) % count
        // Moving away from an armed action disarms it: the confirmation is
        // for that button, not for wherever the cursor ends up next.
        root.armed = ""
        root.armedUefi = false
    }

    // Destructive actions arm on the first press and run on the second, from
    // the keyboard as from the pointer. Shift-click on reboot boots directly to UEFI.
    function activate(action: var, shiftPressed: bool): void {
        if (!action)
            return
        const withShift = Boolean(shiftPressed)
        if (!action.destructive || root.armed === action.id) {
            const isUefi = (action.id === "reboot" && (root.armedUefi || withShift))
            root.armed = ""
            root.armedUefi = false
            root.disarm.stop()
            // Close first, then act: `lock` captures the screen before
            // covering it, and anything still open would end up in the picture.
            root.closed()
            SessionService.run(isUefi ? "reboot-uefi" : action.id)
            return
        }
        root.armed = action.id
        root.armedUefi = (action.id === "reboot" && withShift)
        root.disarm.restart()
    }

    Keys.onLeftPressed: root.move(-1)
    Keys.onRightPressed: root.move(1)
    Keys.onReturnPressed: (event) => root.activate(SessionService.actions[root.selected], Boolean(event.modifiers & Qt.ShiftModifier))
    Keys.onEnterPressed: (event) => root.activate(SessionService.actions[root.selected], Boolean(event.modifiers & Qt.ShiftModifier))

    RowLayout {
        anchors.fill: parent
        spacing: 12

        Repeater {
            model: SessionService.actions

            Rectangle {
                id: tile

                required property var modelData
                required property int index

                readonly property bool isSelected: root.selected === tile.index
                readonly property bool isArmed: root.armed === tile.modelData.id

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusLarge

                // Armed is red, selected is the accent. Only the selected
                // tile can be armed, so they never conflict.
                color: {
                    if (tile.isArmed)
                        return Theme.red
                    return tile.isSelected ? Theme.islandSurfaceHover : Theme.islandSurface
                }
                border.color: {
                    if (tile.isArmed)
                        return Theme.red
                    return tile.isSelected ? Theme.accent : Theme.islandBorder
                }
                border.width: tile.isSelected || tile.isArmed ? 2 : 1

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.icon
                        font.family: Theme.fontMono
                        font.pixelSize: 30
                        color: {
                            if (tile.isArmed)
                                return Theme.accentText
                            return tile.isSelected ? Theme.accent : Theme.text
                        }

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.isArmed
                            ? (tile.modelData.id === "reboot" && root.armedUefi ? "UEFI Setup" : "Confirm")
                            : tile.modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: tile.isSelected ? Font.DemiBold : Font.Normal
                        color: tile.isArmed ? Theme.accentText : Theme.textMuted

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    }
                }

                // The pointer drives the same selection as the arrows.
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: root.selected = tile.index
                    onClicked: (mouse) => {
                        root.selected = tile.index
                        root.activate(tile.modelData, Boolean(mouse.modifiers & Qt.ShiftModifier))
                    }
                }
            }
        }
    }
}
