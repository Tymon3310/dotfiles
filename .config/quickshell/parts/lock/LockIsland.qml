import QtQuick

import "../theme"
import "../services"
import "../components"
import "../../components"

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
    readonly property real unlockedWidth: IslandMetrics.notchWidth

    // Morph width between locked compact padlock and full media/clock bar.
    // Reaches the desktop rest width by ~60% of the release so the carried
    // rest content lands on an already-full notch (no clipped text), then
    // holds until the lock surface lifts.
    readonly property real notchWidth: unlockedWidth
        + (lockedWidth - unlockedWidth) * Math.max(0, root.held * 1.5 - 0.5)

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    width: root.notchWidth
    height: root.notchHeight
    // No Behavior here: notchWidth already moves smoothly because it is
    // driven by the animated `held` prop. A Behavior on top would chase a
    // moving target and feel laggy/floaty.

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
            opacity: Math.min(1, Math.max(0, root.held * 2 - 1))

            // No Behavior on opacity: `held` is already animated, so chasing
            // it here only lagged the padlock's fade into the incoming rest
            // content (the lock ghosting over the clock at the handoff).
            Behavior on tint { ColorAnimation { duration: Theme.durationFast } }

            SequentialAnimation on scale {
                running: LockService.biopassRunning && !LockService.biopassVerified
                loops: Animation.Infinite
                NumberAnimation { to: 1.06; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.9; duration: 600; easing.type: Easing.InOutSine }
            }
        }
        // Rest content, handed over from the desktop island. Built only while
        // the lock is releasing, so the resting lock screen still pays nothing
        // for a hidden desktop UI. Fading it in as `held` falls means the
        // notch already looks like the unlocked bar when the lock surface
        // lifts, so the handoff is invisible instead of a content pop.
        Loader {
            id: restRow

            anchors.top: parent.top
            anchors.topMargin: root.barTopMargin
            anchors.horizontalCenter: parent.horizontalCenter

            active: LockService.leaving
            sourceComponent: IslandRestRow {}

            // Picks up exactly as the padlock finishes fading (held 0.5),
            // so the notch is never left empty mid-handoff.
            opacity: Math.min(1, Math.max(0, (0.5 - root.held) * 3))
            visible: opacity > 0
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
