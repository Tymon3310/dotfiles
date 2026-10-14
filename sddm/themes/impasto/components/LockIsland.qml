// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L O C K   I S L A N D                                                  │
// │   top notch holding padlock with biometric status animations             │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "."

Item {
    id: root

    property bool unlocked: false
    property bool scanning: false
    property bool failed: false
    // 0 → 1 fades the island out at the end of the exit morph
    property real dissolve: 0

    signal clicked()

    opacity: 1 - root.dissolve

    property real tick: root.unlocked ? 1 : 0
    Behavior on tick {
        NumberAnimation { duration: Theme.durationTick; easing.type: Easing.OutCubic }
    }

    readonly property int capsuleH: 30
    readonly property int barTopMargin: 4
    readonly property int notchHeight: root.capsuleH + root.barTopMargin
    readonly property int notchWidth: 76

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    width: root.notchWidth
    height: root.notchHeight

    NotchFillet {
        anchors.right: body.left
        anchors.top: parent.top
        mirrored: true
        color: Theme.island
    }

    NotchFillet {
        anchors.left: body.right
        anchors.top: parent.top
        color: Theme.island
    }

    Rectangle {
        id: body

        anchors.fill: parent
        color: Theme.island
        border.width: 0
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Theme.radiusLarge
        bottomRightRadius: Theme.radiusLarge
        clip: true

        Padlock {
            id: padlock
            anchors.centerIn: parent
            scale: 0.92
            opened: root.unlocked
            tint: {
                if (root.unlocked)
                    return Theme.green
                if (root.scanning)
                    return Theme.accent
                if (root.failed)
                    return Theme.red
                return Theme.text
            }

            // Shackle pops open, then the padlock gives way to the tick
            opacity: root.unlocked ? 0 : 1
            Behavior on opacity {
                NumberAnimation { duration: Theme.durationTick; easing.type: Theme.easing }
            }

            SequentialAnimation on scale {
                running: root.scanning && !root.unlocked
                loops: Animation.Infinite
                NumberAnimation { to: 1.08; duration: 550; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.92; duration: 550; easing.type: Easing.InOutSine }
            }
        }

        Checkmark {
            anchors.centerIn: parent
            width: 20
            height: 20
            thickness: 2.6
            color: Theme.green
            progress: root.tick
            scale: 0.7 + 0.3 * root.tick
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
