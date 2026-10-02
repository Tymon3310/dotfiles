import QtQuick
import Quickshell

import "../parts/theme"
import "../parts/services"

// Startup and lock choreography, separate from the panel's layout and routing.
Scope {
    id: root
    required property var island

    // ── ANIMATION STATES (STARTUP, UNLOCK, LOCK & PANELS) ────────────────────

    property real notchYOffset: -root.island.capsuleH - root.island.barTopMargin - 20
    property real islandsEmergeProgress: 0.0
    property bool isDemorphed: false

    ParallelAnimation {
        id: startupAnimation

        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation {
                target: root.island
                property: "notchYOffset"
                from: -root.island.capsuleH - root.island.barTopMargin - 20
                to: 0
                duration: 480
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }

        SequentialAnimation {
            PauseAnimation { duration: 340 }
            NumberAnimation {
                target: root.island
                property: "islandsEmergeProgress"
                from: 0.0
                to: 1.0
                duration: 620
                easing.type: Easing.OutCubic
            }
        }
    }

    // Side islands retraction (into notch) - relaxed and smooth
    NumberAnimation {
        id: sideIslandsRetractAnimation
        target: root.island
        property: "islandsEmergeProgress"
        to: 0.0
        duration: 360
        easing.type: Easing.InOutCubic
    }

    // Side islands emergence (out from notch) - fluid glide
    NumberAnimation {
        id: sideIslandsEmergeAnimation
        target: root.island
        property: "islandsEmergeProgress"
        from: 0.0
        to: 1.0
        duration: 620
        easing.type: Easing.OutCubic
    }

    // Timer ensuring side islands pop out AFTER the island completes its morph/demorph back to rest
    readonly property Timer postMorphEmergeTimer: Timer {
        interval: Theme.durationMorph + 60
        onTriggered: {
            if (root.island.below === "" && !LockService.locked && !root.island.isDemorphed) {
                sideIslandsEmergeAnimation.restart()
            }
        }
    }

    readonly property string below: root.island.below
    onBelowChanged: {
        if (root.island.below !== "") {
            postMorphEmergeTimer.stop()
            sideIslandsRetractAnimation.restart()
        } else {
            postMorphEmergeTimer.restart()
        }
    }

    // LOCK: 1. Retract side islands into notch -> 2. Demorph notch down to compact 72px.
    // LockService captures only after both stages finish.
    SequentialAnimation {
        id: lockSequence

        NumberAnimation {
            target: root.island
            property: "islandsEmergeProgress"
            to: 0.0
            duration: Theme.durationIslandRetract
            easing.type: Easing.InOutCubic
        }

        ScriptAction {
            script: root.island.isDemorphed = true
        }
    }

    // UNLOCK: 1. Morph notch to full width -> 2. Pop out side islands after morph finishes
    SequentialAnimation {
        id: unlockSequence

        ScriptAction {
            script: {
                root.island.notchYOffset = 0
                root.island.isDemorphed = false
            }
        }

        // Begin the side-island glide shortly before the lock surface lifts.
        // InOut easing keeps them almost tucked away at handoff, avoiding a
        // visible pop while still avoiding a dead pause afterward.
        PauseAnimation {
            duration: Math.max(0, Theme.durationMorph - 80)
        }

        NumberAnimation {
            target: root.island
            property: "islandsEmergeProgress"
            from: 0.0
            to: 1.0
            duration: 620
            easing.type: Easing.InOutCubic
        }
    }

    Component.onCompleted: {
        if (!LockService.locked) {
            startupAnimation.start()
        } else {
            root.island.notchYOffset = 0
            root.island.isDemorphed = true
            root.island.islandsEmergeProgress = 0.0
        }
    }

    Connections {
        target: LockService

        function onPrepareLock(): void {
            root.island.close()
            lockSequence.restart()
        }

        function onLockedChanged(): void {
            if (LockService.locked) {
                root.island.close()
                root.island.isDemorphed = true
                root.island.islandsEmergeProgress = 0.0
            }
        }

        // Start the normal bar's notch morph underneath the lock surface.
        // LockSurface runs the matching `held` animation on this same state;
        // by the time it disappears, the two islands have the same geometry.
        function onLeavingChanged(): void {
            if (LockService.leaving)
                unlockSequence.restart()
        }
    }

}
