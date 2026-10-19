// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   O S D   L A Y E R                                                      │
// │   what the resting island morphs into for volume, locks and the headset  │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// Styled like the agent alert: the icon in a tinted badge that pops in, a
// level bar when there is one, and the label. Toggles (caps lock, mic mute,
// a headset connecting) also send out a ripple; level changes (volume) only
// pop when the OSD first appears, so dragging a slider doesn't strobe.
//
// The tint carries meaning: red for muted or a low battery, green for
// charging, connected or switched on, the accent otherwise. IslandBar reads
// `tint` for the glow along the island's lower edge.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property real progress: -1

    readonly property bool hasLevel: root.progress >= 0

    // Glyphs that mean "off" / "muted".
    readonly property var offGlyphs: ["󰍭", "󰝟", "󰟎"]
    // Glyphs that mean "charging".
    readonly property var chargingGlyphs: ["󰂄"]

    readonly property bool isOff: root.offGlyphs.includes(root.icon)
        || /\b(off|muted|disconnected)\b/i.test(root.label)
    readonly property bool isLow: root.hasLevel && root.progress <= 0.15
        && /headset|battery/i.test(root.label) && !root.chargingGlyphs.includes(root.icon)
    readonly property bool isGood: root.chargingGlyphs.includes(root.icon)
        || /\b(on|active|connected|charging)\b/i.test(root.label)

    readonly property color tint: root.isOff || root.isLow ? Theme.indicatorBad
        : root.isGood ? Theme.indicatorGood : Theme.accent

    implicitWidth: contentRow.implicitWidth
    implicitHeight: Theme.capsuleHeight

    // Pop whenever what the OSD is about changes; a ripple for toggles.
    property string kind: `${root.icon}|${root.hasLevel ? "level" : root.label}`
    onKindChanged: root.pop()
    onVisibleChanged: if (root.visible) root.pop()

    function pop(): void {
        popAnim.restart()
        if (!root.hasLevel)
            ripple.restart()
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 10

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20

            Rectangle {
                id: ring
                anchors.centerIn: parent
                width: 20
                height: 20
                radius: 10
                color: "transparent"
                border.width: 1.5
                border.color: root.tint
                opacity: 0
            }

            ParallelAnimation {
                id: ripple
                NumberAnimation { target: ring; property: "scale"; from: 1; to: 2.1; duration: 700; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring; property: "opacity"; from: 0.7; to: 0; duration: 700; easing.type: Easing.OutCubic }
            }

            Rectangle {
                id: badge
                anchors.centerIn: parent
                width: 20
                height: 20
                radius: 10
                color: Theme.tintWash(root.tint, 0.2)

                Behavior on color { ColorAnimation { duration: Theme.durationMedium } }

                Text {
                    anchors.centerIn: parent
                    text: root.icon
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                    color: root.tint

                    Behavior on color { ColorAnimation { duration: Theme.durationMedium } }
                }
            }

            SequentialAnimation {
                id: popAnim
                NumberAnimation { target: badge; property: "scale"; from: 0.5; to: 1.15; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { target: badge; property: "scale"; to: 1; duration: 150; easing.type: Easing.InOutQuad }
            }
        }

        // The level, when there is one.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasLevel
            width: 120
            height: 6
            radius: height / 2
            color: Theme.islandSurfaceHover

            Rectangle {
                width: Math.max(parent.height, parent.width * Math.min(1, Math.max(0, root.progress)))
                height: parent.height
                radius: height / 2
                color: root.tint

                Behavior on width {
                    NumberAnimation { duration: Theme.durationEnter; easing.type: Theme.easingSpring; easing.overshoot: Theme.springOvershoot }
                }
                Behavior on color { ColorAnimation { duration: Theme.durationMedium } }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall + 1
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Theme.text
        }
    }
}
