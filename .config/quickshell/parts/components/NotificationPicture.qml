
import QtQuick
import Quickshell.Widgets

import "../theme"
import "../services"

Item {
    id: root

    property var notification: null
    property bool critical: false
    property bool keep: false

    readonly property string pictureUrl: root.notification ? (root.notification.picture ?? "") : ""
    readonly property string iconUrl: root.notification ? (root.notification.icon ?? "") : ""

    readonly property bool hasPicture: picture.status === Image.Ready
    readonly property bool hasIcon: icon.status === Image.Ready

    readonly property real aspect: picture.implicitHeight > 0
        ? picture.implicitWidth / picture.implicitHeight : 1
    readonly property bool landscape: root.hasPicture && root.aspect > 1.2

    ClippingRectangle {
        id: frame

        anchors.fill: parent
        radius: root.landscape ? Theme.radiusSmall : width * Theme.pictureCorner
        color: root.critical ? Theme.red
            : (root.hasPicture ? "transparent" : Theme.islandSurfaceHover)

        Image {
            id: picture

            anchors.fill: parent
            source: root.pictureUrl
            visible: root.hasPicture
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 200

            onStatusChanged: {
                // The file is written elsewhere, by a grabber that outlives
                // this row; grabbing here crashes when the row is rebuilt
                // mid-grab. See NotificationPictureSaver.
                if (status === Image.Ready && root.keep && root.notification)
                    NotificationService.requestPictureSave(root.notification.key, root.pictureUrl)
            }
        }

        Image {
            anchors.centerIn: parent
            width: parent.width * 0.72
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

    // Loads the icon either way, so `hasIcon` is known for the badge and the
    // fallback alike.
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
        width: Math.round(Math.min(root.width, root.height) * 0.46)
        height: width
        radius: width * 0.3
        x: parent.width - width + 4
        y: parent.height - height + 4
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
