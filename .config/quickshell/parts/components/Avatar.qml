import QtQuick

import "../theme"
import "../services"

// A round picture, or initials when there is none.
Item {
    id: root

    property string source: AccountService.avatar
    property string initials: AccountService.initials
    property color ring: Theme.islandBorder

    implicitWidth: 64
    implicitHeight: 64

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.islandSurface
        border.color: root.ring
        border.width: 1.5
        clip: true

        Image {
            id: picture
            anchors.fill: parent
            source: root.source !== "" ? `file://${root.source}` : ""
            visible: root.source !== "" && status === Image.Ready
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Text {
            anchors.centerIn: parent
            visible: !picture.visible
            text: root.initials
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(root.height * 0.38)
            font.weight: Font.DemiBold
            color: Theme.text
        }
    }
}
