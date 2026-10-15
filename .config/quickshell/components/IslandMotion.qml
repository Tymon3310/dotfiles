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
            PauseAnimation { duration: Math.round(30 * Theme.motion) }
            NumberAnimation {
                target: root.island
                property: "notchYOffset"
                from: -root.island.capsuleH - root.island.barTopMargin - 20
                to: 0
                duration: Math.round(280 * Theme.motion)
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }

        SequentialAnimation {
            PauseAnimation { duration: Math.round(200 * Theme.motion) }
            NumberAnimation {
                target: root.island
                property: "islandsEmergeProgress"
                from: 0.0
                to: 1.0
                duration: Math.round(380 * Theme.motion)
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
        duration: Math.round(220 * Theme.motion)
        easing.type: Easing.InOutCubic
    }

    // Side islands emergence (out from notch) - fluid glide
    NumberAnimation {
        id: sideIslandsEmergeAnimation
        target: root.island
        property: "islandsEmergeProgress"
        from: 0.0
        to: 1.0
        duration: Math.round(380 * Theme.motion)
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

    // LOCK: side islands retract while the notch shrinks to compact 72px.
    // The shrink itself is driven by the width/height Behaviors (fast path
    // when closed, see IslandBar): a single driver. A second explicit
    // animation on the same properties would fight the Behavior for
    // precedence and split the shrink into stages.
    // The demorph flag is set synchronously in onPrepareLock so the binding
    // changes exactly once, in the same tick as close().
    // LockService captures once both finish (Theme.durationIslandGone).
    NumberAnimation {
        id: lockSequence
        target: root.island
        property: "islandsEmergeProgress"
        to: 0.0
        duration: Theme.durationIslandRetract
        easing.type: Easing.InOutCubic
    }

    // TEMPORARY lock-morph sampler for diagnosing staged shrinks. Remove
    // once the transition is confirmed smooth.
    property real dbgT0: 0
    property int dbgN: 0
    readonly property Timer dbgSampler: Timer {
        interval: 30
        repeat: true
        onTriggered: {
            root.dbgN += 1
            console.info("[lock-t] morph t=" + Math.round(Date.now() - root.dbgT0) + "ms w=" + Math.round(root.island.capsule.width) + " prog=" + root.islandsEmergeProgress.toFixed(2))
            if (root.dbgN >= 12)
                root.dbgSampler.stop()
        }
    }

    // UNLOCK: side islands glide out while the notch morphs back to full
    // width (reset synchronously in onLeavingChanged); the lock surface
    // lifts as they land.
    SequentialAnimation {
        id: unlockSequence

        // Begin the side-island glide early so it runs while the lock
        // surface fades, finishing just as the surface lifts — no dead
        // pause with a full-width island and no side islands.
        PauseAnimation {
            duration: Math.round(100 * Theme.motion)
        }

        NumberAnimation {
            target: root.island
            property: "islandsEmergeProgress"
            from: 0.0
            to: 1.0
            duration: Math.round(380 * Theme.motion)
            easing.type: Easing.InOutCubic
        }
    }

    Component.onCompleted: {
        if (LockService.leaving) {
            // Recreated mid-unlock (e.g. output re-announce): snap to the
            // resting state instead of replaying the startup drop-in.
            root.island.notchYOffset = 0
            root.island.isDemorphed = false
            root.island.islandsEmergeProgress = 1.0
        } else if (!LockService.locked) {
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
            console.info("[lock-t] island prepare")
            root.island.close()
            root.island.isDemorphed = true
            root.dbgT0 = Date.now()
            root.dbgN = 0
            root.dbgSampler.start()
            lockSequence.restart()
        }

        function onLockedChanged(): void {
            if (LockService.locked) {
                root.dbgSampler.stop()
                root.island.close()
                root.island.isDemorphed = true
                root.island.islandsEmergeProgress = 0.0
            }
        }

        // Start the normal bar's notch morph underneath the lock surface.
        // LockSurface runs the matching `held` animation on this same state;
        // by the time it disappears, the two islands have the same geometry.
        function onLeavingChanged(): void {
            if (LockService.leaving) {
                console.info("[lock-t] island unlock start")
                root.island.notchYOffset = 0
                root.island.isDemorphed = false
                unlockSequence.restart()
            }
        }
    }

}
