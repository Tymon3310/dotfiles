import QtQuick
import Quickshell.Widgets

import "../theme"

// A notification's picture with the app icon as a badge, the app icon alone,
// or a bell. `entry` is a NotificationService entry.
Item {
    id: root

    property var entry: null

    readonly property string pictureUrl: root.entry?.picture ?? ""
    readonly property string iconUrl: root.entry?.icon ?? ""
    readonly property bool critical: root.entry?.critical ?? false

    readonly property bool hasPicture: picture.status === Image.Ready
    readonly property bool hasIcon: icon.status === Image.Ready

    readonly property real aspect: picture.implicitHeight > 0
        ? picture.implicitWidth / picture.implicitHeight : 1

    ClippingRectangle {
        anchors.fill: parent
        radius: Math.min(width, height) * Theme.pictureCorner
        color: root.critical ? Theme.red
            : (root.hasPicture ? "transparent" : Theme.islandSurfaceHover)

        Image {
            id: picture

            anchors.fill: parent
            source: root.pictureUrl
            visible: root.hasPicture
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 256
        }

        Image {
            anchors.centerIn: parent
            width: parent.width * 0.66
            height: width
            source: root.hasPicture ? "" : root.iconUrl
            visible: !root.hasPicture && root.hasIcon
            sourceSize.width: 96
            sourceSize.height: 96
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        Text {
            anchors.centerIn: parent
            visible: !root.hasPicture && !root.hasIcon
            text: root.critical ? "󰀪" : "󰂚"
            font.family: Theme.fontMono
            font.pixelSize: Math.round(root.height * 0.45)
            color: root.critical ? Theme.accentText : Theme.accent
        }
    }

    // Loaded either way, so `hasIcon` is known for the badge and the fallback.
    Image {
        id: icon

        source: root.iconUrl
        visible: false
        sourceSize.width: 96
        sourceSize.height: 96
        asynchronous: true
    }

    Rectangle {
        visible: root.hasPicture && root.hasIcon
        width: Math.round(Math.min(root.width, root.height) * 0.44)
        height: width
        radius: width * 0.3
        x: parent.width - width + 3
        y: parent.height - height + 3
        color: Theme.island

        Image {
            anchors.fill: parent
            anchors.margins: 2
            source: parent.visible ? root.iconUrl : ""
            sourceSize.width: 48
            sourceSize.height: 48
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
    }
}
