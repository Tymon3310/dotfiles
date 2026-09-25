// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T R A Y   W I D G E T                                                  │
// │   status notifier icons                                                  │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

import "../../theme"

// The system tray from the dotfiles bar, redrawn on the parts' Theme. Chromeless
// like everything else here: it draws icons only, the host draws the island.
//
// Left click activates, middle click is the item's secondary action, the wheel
// scrolls it. Right click does not open anything itself: it emits
// `menuRequested` with the menu, the icon's centre in `mapTarget` coordinates
// and the item, for the host to show in a TrayMenuList.
Row {
    id: root

    // Item the reported x is mapped into; usually the window's contentItem.
    property Item mapTarget: null

    // Icon edge, scaled off the capsule like the ring chips.
    property int iconSize: Math.round(Theme.capsuleHeight * 0.55)

    signal menuRequested(var menu, real centerX, var item)

    readonly property bool empty: SystemTray.items.values.length === 0

    spacing: 2
    visible: !root.empty
    height: Theme.capsuleHeight

    Repeater {
        // The live model, not `.values`: items are added and removed one at
        // a time instead of every icon being rebuilt on each change.
        model: SystemTray.items

        Item {
            id: slot

            required property var modelData

            width: root.iconSize + 10
            height: root.height

            // Hover pill, the same as the island's other buttons.
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                radius: height / 2
                color: mouse.containsMouse ? Theme.islandSurface : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            }

            Image {
                anchors.centerIn: parent
                width: root.iconSize
                height: root.iconSize
                source: slot.modelData.icon
                sourceSize.width: root.iconSize * 2
                sourceSize.height: root.iconSize * 2
                fillMode: Image.PreserveAspectFit
                opacity: mouse.containsMouse ? 1 : 0.8
                scale: mouse.pressed ? 0.88 : 1

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack } }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: event => {
                    const item = slot.modelData
                    if (event.button === Qt.MiddleButton) {
                        item.secondaryActivate()
                        return
                    }
                    // Menu-only items (onlyMenu) have nothing to activate.
                    if (event.button === Qt.LeftButton && !item.onlyMenu) {
                        item.activate()
                        return
                    }
                    if (item.hasMenu && item.menu) {
                        const centre = root.mapTarget
                            ? slot.mapToItem(root.mapTarget, slot.width / 2, 0).x
                            : slot.width / 2
                        root.menuRequested(item.menu, centre, item)
                    }
                }

                onWheel: event => slot.modelData.scroll(event.angleDelta.y, false)
            }
        }
    }
}
