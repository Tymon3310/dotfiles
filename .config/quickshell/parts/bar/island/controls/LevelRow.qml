// An icon that toggles mute, a draggable level and its percentage. Used by
// AudioCard for the output and the mic.

import QtQuick
import QtQuick.Layouts

import "../../../theme"
import "../../../components"

RowLayout {
    id: lvl

    property string icon
    property bool muted
    property int level
    signal toggled()
    signal picked(int percent)

    Layout.fillWidth: true
    spacing: 10

    Text {
        Layout.preferredWidth: 16
        horizontalAlignment: Text.AlignHCenter
        text: lvl.icon
        font.family: Theme.fontMono
        font.pixelSize: 14
        color: lvl.muted ? Theme.textMuted : Theme.text

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: lvl.toggled()
        }
    }

    // The whole strip is the hit area.
    Item {
        id: track

        Layout.fillWidth: true
        Layout.preferredHeight: 16

        function pick(x: real): void {
            lvl.picked(Math.max(0, Math.min(100, Math.round(x / track.width * 100))))
        }

        UsageBar {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: trackMouse.containsMouse || trackMouse.pressed ? 6 : 4
            progress: lvl.level / 100
            fillColor: lvl.muted ? Theme.indicatorDim : Theme.accent

            Behavior on implicitHeight {
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }
        }

        MouseArea {
            id: trackMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: event => track.pick(event.x)
            onPositionChanged: event => {
                if (pressed)
                    track.pick(event.x)
            }
            onWheel: event => lvl.picked(Math.max(0, Math.min(100,
                lvl.level + (event.angleDelta.y > 0 ? 5 : -5))))
        }
    }

    Text {
        Layout.preferredWidth: 34
        horizontalAlignment: Text.AlignRight
        text: lvl.muted ? "off" : `${lvl.level}%`
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        color: lvl.muted ? Theme.textMuted : Theme.text
    }
}
