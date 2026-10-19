// A small round glyph button, for the media card's lyric timing nudges.

import QtQuick

import "../../../theme"

Rectangle {
    id: root

    property string glyph: ""
    signal clicked()

    implicitWidth: 18
    implicitHeight: 18
    radius: width / 2
    color: mouse.containsMouse ? Theme.islandSurfaceHover : "transparent"
    border.width: 1
    border.color: mouse.containsMouse ? Theme.islandBorder : "transparent"

    // Squish while pressed, spring back on release.
    scale: mouse.pressed ? Theme.pressScale : 1
    Behavior on scale { NumberAnimation { duration: Theme.durationEnter; easing.type: Theme.easingSpring; easing.overshoot: Theme.springOvershoot * 3 } }

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.weight: Font.Bold
        color: mouse.containsMouse ? Theme.accent : Theme.textMuted
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
