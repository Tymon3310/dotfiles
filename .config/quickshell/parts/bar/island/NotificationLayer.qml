
import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"

//
// While the pointer is over the stack nothing on it times out
// (NotificationService.held). With more than one shown, each body is held to
// fewer lines so the stack stays a sensible height.
//
Item {
    id: root

    readonly property var entries: NotificationService.shown
    readonly property int queued: NotificationService.waiting.length
    readonly property bool stacked: root.entries.length > 1

    readonly property int gap: 9

    // Keys already drawn once. The list is a plain array, so every change
    // rebuilds all its rows; only a newcomer should slide in.
    property var seen: ({})
    readonly property int footerHeight: root.queued > 0 ? 20 : 0

    // The widest entry decides the width; the island is one shape.
    readonly property real wantWidth: {
        let widest = 430
        for (let i = 0; i < column.children.length; i++) {
            const child = column.children[i]
            if (child.wantWidth !== undefined)
                widest = Math.max(widest, child.wantWidth)
        }
        return widest
    }
    readonly property real wantHeight: column.implicitHeight + root.footerHeight

    implicitWidth: root.wantWidth
    implicitHeight: root.wantHeight

    HoverHandler {
        onHoveredChanged: NotificationService.held = hovered
    }

    Component.onDestruction: NotificationService.held = false

    Column {
        id: column

        width: parent.width
        spacing: 0

        Repeater {
            model: root.entries

            Column {
                id: slot

                required property var modelData
                required property int index

                readonly property real wantWidth: entry.wantWidth

                width: column.width
                spacing: 0

                Item {
                    width: parent.width
                    height: slot.index > 0 ? root.gap * 2 + 1 : 0
                    visible: slot.index > 0

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: 1
                        color: Theme.hairline
                    }
                }

                NotificationEntry {
                    id: entry

                    width: parent.width
                    notification: slot.modelData
                    maxBodyLines: root.stacked ? 4 : 8
                    opacity: slot.index === 0 ? 1 : 0.82

                    transform: Translate { id: arrive; y: 0 }
                    Component.onCompleted: {
                        if (root.seen[slot.modelData.key])
                            return
                        root.seen[slot.modelData.key] = true
                        arrival.start()
                    }

                    ParallelAnimation {
                        id: arrival
                        NumberAnimation {
                            target: arrive; property: "y"
                            from: -14; to: 0
                            duration: Theme.durationSpring; easing.type: Theme.easingSpring
                            easing.overshoot: Theme.springOvershoot * 2
                        }
                        NumberAnimation {
                            target: entry; property: "scale"
                            from: 0.96; to: 1
                            duration: Theme.durationSpring; easing.type: Theme.easingSpring
                            easing.overshoot: Theme.springOvershoot
                        }
                        NumberAnimation {
                            target: entry; property: "opacity"
                            from: 0; to: slot.index === 0 ? 1 : 0.82
                            duration: Theme.durationMedium; easing.type: Theme.easing
                        }
                    }
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
