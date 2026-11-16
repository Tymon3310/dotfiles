import QtQuick

import "../theme"

// The rounded surface every control centre section uses. `bare` drops the
// surface and keeps the contents, for module details shown directly on the
// island.
Rectangle {
    id: root

    default property alias content: inner.data
    property int padding: 14
    property bool bare: false

    radius: Theme.radiusMedium
    color: root.bare ? "transparent" : Theme.islandSurface
    border.color: Theme.islandBorder
    border.width: root.bare ? 0 : 1

    Behavior on color { ColorAnimation { duration: Theme.paletteTransition } }

    // A faint light from above: a white wash fading out near the top (above
    // any content that paints the flat card colour, like the lyric fades),
    // so cards read as raised surfaces rather than flat slabs.
    Rectangle {
        visible: !root.bare
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.035) }
            GradientStop { position: 0.18; color: Qt.rgba(1, 1, 1, 0) }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
