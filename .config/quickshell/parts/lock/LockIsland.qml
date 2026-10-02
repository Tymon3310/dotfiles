import QtQuick

import "../theme"
import "../services"
import "../components"

// The island on the lock screen: top notch holding the padlock.
// Matches the exact resting dimensions and curvature of IslandBar.
Item {
    id: root

    property real held: 1

    readonly property int capsuleH: Theme.capsuleHeight
    readonly property int barTopMargin: Theme.barTopMargin
    readonly property int notchHeight: root.capsuleH + root.barTopMargin

    // The locked notch stays compact, then matches the desktop at handoff.
    readonly property int lockedWidth: 72
    // Unlocked notch matches IslandBar rest width
    readonly property real unlockedWidth: IslandMetrics.notchWidth

    // Morph width between locked compact padlock and full media/clock bar
    readonly property real notchWidth: unlockedWidth + (lockedWidth - unlockedWidth) * root.held

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    width: root.notchWidth
    height: root.notchHeight

    Behavior on width { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
    Behavior on height { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }

    // Fillets attaching notch to top screen edge
    NotchFillet {
        anchors.right: body.left
        anchors.top: parent.top
        mirrored: true
    }

    NotchFillet {
        anchors.left: body.right
        anchors.top: parent.top
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

        // 1. Padlock in the notch while locked (with Biopass visual feedback)
        Padlock {
            id: padlock
            anchors.centerIn: parent
            scale: 0.9
            opened: LockService.leaving || LockService.biopassVerified
            tint: {
                if (LockService.biopassVerified)
                    return Theme.green
                if (LockService.biopassRunning)
                    return Theme.accent
                if (LockService.biopassFailed)
                    return Theme.red
                return Theme.text
            }
            opacity: root.held

            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            Behavior on tint { ColorAnimation { duration: Theme.durationFast } }

            SequentialAnimation on scale {
                running: LockService.biopassRunning && !LockService.biopassVerified
                loops: Animation.Infinite
                NumberAnimation { to: 1.06; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.9; duration: 600; easing.type: Easing.InOutSine }
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.held > 0.5
            onClicked: {
                LockService.rouse()
                LockService.triggerBiopass()
            }
        }

    }
}
