import QtQuick
import Quickshell

import "../parts/theme"
import "../parts/services"

Scope {
    id: root
    required property var island


    property real notchYOffset: -root.island.capsuleH - root.island.barTopMargin - 20
    property real islandsEmergeProgress: 0.0
    property bool isDemorphed: false

    // STARTUP: the same morph as an unlock, from nothing.
    //   1. wait a beat, so the song and clock have loaded and the island
    //      opens straight to its final width instead of growing in steps;
    //   2. drop in from above as the compact 72px pill, with a small bounce;
    //   3. spring open sideways while the clock and song scale in;
    //   4. the side capsules glide out from under it as it settles.
    property bool unfurling: false

    SequentialAnimation {
        id: startupAnimation

        PauseAnimation { duration: Math.round(260 * Theme.motion) }

        // The opening starts while the drop is still settling, so the two
        // read as one motion rather than drop, pause, open.
        ParallelAnimation {
            NumberAnimation {
                target: root.island
                property: "notchYOffset"
                to: 0
                duration: Math.round(320 * Theme.motion)
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }

            SequentialAnimation {
                PauseAnimation { duration: Math.round(140 * Theme.motion) }
                ScriptAction {
                    script: {
                        root.unfurling = true
                        root.island.isDemorphed = false
                    }
                }
            }
        }

        PauseAnimation { duration: Math.round(Theme.durationSpring * 0.25) }

        NumberAnimation {
            target: root.island
            property: "islandsEmergeProgress"
            from: 0.0
            to: 1.0
            duration: Math.round(460 * Theme.motion)
            easing.type: Easing.OutBack
            easing.overshoot: 0.9
        }

        ScriptAction { script: root.unfurling = false }
    }

    NumberAnimation {
        id: sideIslandsRetractAnimation
        target: root.island
        property: "islandsEmergeProgress"
        to: 0.0
        duration: Math.round(220 * Theme.motion)
        easing.type: Easing.InOutCubic
    }

    // Side islands emergence (out from notch) - fluid glide. From wherever
    // they are, not from 0: restarting from 0 mid-glide (an interrupted
    // retract, or the unlock glide still running) snapped them back in.
    NumberAnimation {
        id: sideIslandsEmergeAnimation
        target: root.island
        property: "islandsEmergeProgress"
        to: 1.0
        duration: Math.round(380 * Theme.motion)
        easing.type: Easing.OutCubic
    }

    // Side islands glide back out once the island is well into its return
    // to rest. Returning runs over durationIslandRetract (see IslandBar), not
    // durationMorph; the capsules track the island's edges and sit beneath
    // it, so starting halfway through reads as one motion with no dead gap.
    readonly property Timer postMorphEmergeTimer: Timer {
        interval: Math.round(Theme.durationIslandRetract * 0.5)
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

    // UNLOCK: the notch morphs back to full width under the lock surface
    // (reset synchronously in onLeavingChanged), so by the time the surface
    // lifts the two islands are pixel-identical.
    //
    // With session_lock_xray the desktop shows through the fading lock, so
    // the side capsules glide out during the release, starting as the lock
    // notch reaches full width. Without it nothing under the lock is seen,
    // and starting early would show them mid-glide at the cut, so they wait
    // for the surface to lift (onLockedChanged).
    SequentialAnimation {
        id: unlockEmerge
        PauseAnimation { duration: Math.round(70 * Theme.motion) }
        NumberAnimation {
            target: root.island
            property: "islandsEmergeProgress"
            to: 1.0
            duration: Math.round(320 * Theme.motion)
            easing.type: Easing.OutCubic
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
            // Starts as the hidden compact pill; see startupAnimation.
            root.island.isDemorphed = true
            root.island.islandsEmergeProgress = 0.0
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
            unlockEmerge.stop()
            lockSequence.restart()
        }

        function onLockedChanged(): void {
            if (LockService.locked) {
                root.island.close()
                root.island.isDemorphed = true
                root.island.islandsEmergeProgress = 0.0
            } else if (root.island.below === "" && !unlockEmerge.running
                    && root.island.islandsEmergeProgress < 1) {
                // Surface lifted without xray: glide the side capsules out
                // now, so they animate in visibly instead of popping.
                sideIslandsEmergeAnimation.restart()
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
                if (LockService.xray && root.island.below === "")
                    unlockEmerge.restart()
            }
        }
    }

}
