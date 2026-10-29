import QtQuick

import "../../theme"
import "../../services"

// The popups, newest on top. Shown in the island, or in the overlay over a
// fullscreen window. Hovering holds every timer (NotificationService.held).
Item {
    id: root

    readonly property int queued: NotificationService.queue.length
    readonly property int footerHeight: root.queued > 0 ? 20 : 0

    readonly property real wantWidth: 400
    readonly property real wantHeight: column.implicitHeight + root.footerHeight

    implicitWidth: root.wantWidth
    implicitHeight: root.wantHeight

    HoverHandler {
        onHoveredChanged: NotificationService.held = hovered
    }

    Component.onDestruction: NotificationService.held = false

    // A Column, not a ListView: it places cards by their real height every
    // time, so a card growing as its picture loads pushes the rest down.
    Column {
        id: column

        width: parent.width
        spacing: 2

        move: Transition {
            NumberAnimation { property: "y"; duration: Theme.durationMedium; easing.type: Theme.easing }
        }

        Repeater {
            model: NotificationService.popups

            NotificationCard {
                id: card

                key: model.key
                width: column.width
                popup: true
                // Fewer lines each when several share the island.
                maxBodyLines: NotificationService.popupCount > 1 ? 3 : 5

                opacity: 0
                scale: 0.96
                Component.onCompleted: arrival.start()

                ParallelAnimation {
                    id: arrival
                    NumberAnimation { target: card; property: "opacity"; to: 1; duration: Theme.durationMedium; easing.type: Theme.easing }
                    NumberAnimation { target: card; property: "scale"; to: 1; duration: Theme.durationSpring; easing.type: Theme.easingSpring; easing.overshoot: Theme.springOvershoot }
                }
            }
        }
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.queued > 0
        text: `+${root.queued} more`
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        font.weight: Font.DemiBold
        color: Theme.textMuted
    }
}
