import QtQuick

import "../theme"

// Transient events: volume, mute, caps lock, num lock.
// Displays icon, animated level bar (if progress >= 0), and label.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property real progress: -1

    readonly property bool hasLevel: root.progress >= 0

    implicitWidth: contentRow.implicitWidth
    implicitHeight: Theme.capsuleHeight

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 12

        // Icon
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.family: Theme.fontMono
            font.pixelSize: 15
            color: Theme.accent
        }

        // Progress bar (only if progress >= 0)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasLevel
            width: 120
            height: 4
            radius: height / 2
            color: Theme.islandSurfaceHover

            Rectangle {
                width: Math.max(parent.height, parent.width * Math.min(1, Math.max(0, root.progress)))
                height: parent.height
                radius: height / 2
                color: Theme.accent

                Behavior on width {
                    NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
                }
            }
        }

        // Label
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.text
        }
    }
}
