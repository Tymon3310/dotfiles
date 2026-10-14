// ╭────────────────────────────────────────────────────────────────────────────╮
// │                                                                            │
// │   L O C K   S U R F A C E                                                  │
// │   per-output lock visuals, blurred wallpaper, clock and login widget      │
// │                                                                            │
// │   github.com/andreumassanet/impasto                                        │
// │                                                                            │
// ╰────────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects
import Quickshell

import "../theme"
import "../services"

Item {
    id: root

    property string screenName: ""
    readonly property bool isActive: (Quickshell.screens.length <= 1) || (screenName !== "" && screenName === LockService.activeScreen)

    signal submitted(string password)

    function claim(): void {
        if (root.isActive)
            account.claim()
    }

    property real held: LockService.leaving ? 0 : 1

    // On entry, spread the frozen/blurred desktop out from the top island.
    // The source screenshot is already locked and immutable underneath it.
    property real lockReveal: 0
    property real clockReveal: 0
    ParallelAnimation {
        id: lockEntry
        running: false

        NumberAnimation {
            target: root
            property: "lockReveal"
            from: 0
            to: 1
            duration: 680
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            PauseAnimation { duration: 150 }
            NumberAnimation {
                target: root
                property: "clockReveal"
                from: 0
                to: 1
                duration: 440
                easing.type: Easing.OutBack
            }
        }
    }

    // The screenshot decodes asynchronously, so hold the entry animation
    // until it's on screen; otherwise the frost plays out over nothing and
    // the blur just appears. A fallback keeps the clock from never showing.
    property bool entryPending: false

    function beginEntry(): void {
        lockEntry.stop()
        root.lockReveal = 0
        root.clockReveal = 0
        root.entryPending = true
        entryFallback.restart()
        root.tryEntry(false)
    }

    function tryEntry(force: bool): void {
        if (!root.entryPending)
            return
        const settled = shot.status === Image.Ready || shot.status === Image.Error || String(shot.source) === ""
        if (!force && !settled)
            return
        root.entryPending = false
        entryFallback.stop()
        // One extra frame so the texture upload doesn't land on frame one
        entryKick.restart()
    }

    Timer {
        id: entryFallback
        interval: 600
        onTriggered: root.tryEntry(true)
    }

    Timer {
        id: entryKick
        interval: 32
        onTriggered: lockEntry.restart()
    }

    Component.onCompleted: {
        root.beginEntry()
        // Hold keyboard focus while resting so the first keypress wakes
        // without needing a mouse click to focus the password field.
        root.forceActiveFocus()
    }

    Connections {
        target: LockService
        function onLockedChanged(): void {
            if (!LockService.locked)
                return
            root.beginEntry()
            root.forceActiveFocus()
        }
    }

    Behavior on held {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Easing.InOutCubic }
    }

    property real awake: LockService.awake ? 1 : 0

    Behavior on awake {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    Connections {
        target: LockService
        function onAwakeChanged(): void {
            if (!LockService.awake) {
                account.clear()
                root.forceActiveFocus()
            } else if (root.isActive) {
                Qt.callLater(account.claim)
            }
        }
        function onActiveScreenChanged(): void {
            if (root.isActive && LockService.awake)
                Qt.callLater(account.claim)
        }
    }

    // Every surface accepts focus: the compositor delivers keys to the
    // focused output's surface, which is often not the active screen.
    // The key handler below adopts whichever screen received the key.
    focus: true
    Keys.onPressed: event => {
        // Adopt this screen first so a keypress on the focused (but
        // non-active) monitor still wakes and starts face auth.
        LockService.setActiveScreen(root.screenName)
        // Escape dismisses without rousing (rousing would start face auth).
        if (event.key === Qt.Key_Escape) {
            if (LockService.awake) {
                account.clear()
                LockService.rest()
                root.forceActiveFocus()
            }
            event.accepted = true
            return
        }
        const wasAwake = LockService.awake
        LockService.rouse()
        if (event.key === Qt.Key_Space) {
            if (!LockService.biopassRunning && !LockService.biopassVerified)
                LockService.triggerBiopass()
            Qt.callLater(account.claim)
            event.accepted = true
            return
        }
        if (!wasAwake && event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32) {
            account.append(event.text)
            event.accepted = true
            return
        }
        account.claim()
    }

    TapHandler {
        onTapped: {
            LockService.setActiveScreen(root.screenName)
            LockService.rouse()
            if (root.isActive)
                account.claim()
        }
    }

    // ── BACKGROUND ───────────────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        color: Theme.island
    }

    Image {
        id: shot
        anchors.fill: parent
        source: LockService.shotSourceFor(root.screenName)
        visible: true
        fillMode: Image.PreserveAspectCrop
        // Async so the multi-megapixel JPEG decode never blocks the GUI
        // thread mid-animation. The frost gates on Image.Ready.
        asynchronous: true
        cache: false
        onStatusChanged: root.tryEntry(false)
    }

    // Frost the whole frozen screenshot in place. The blur radius itself
    // ramps up on lock (lockReveal) and back down on unlock (held), so the
    // desktop visibly goes soft instead of crossfading to a blurred copy.
    // Floored just above zero: MultiEffect swaps shader variants when blur or
    // brightness hit exactly 0, which hitches the first and last frame.
    readonly property real frost: Math.max(0.002, root.held * root.lockReveal)

    MultiEffect {
        anchors.fill: parent
        source: shot
        visible: shot.status === Image.Ready
        blurEnabled: true
        blur: root.frost
        blurMax: SettingsService.lockBlur
        brightness: (root.screenName === "DP-1" ? 0.05 : -0.02) * root.frost
        contrast: (root.screenName === "DP-1" ? 0.08 : 0.0) * root.frost
        saturation: 0.0
    }

    // Balanced scrim for clear legibility without gloom or washout
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: 0.16 * root.frost
    }

    // A soft lower vignette keeps the password capsule readable without
    // flattening the captured wallpaper behind the clock.
    Rectangle {
        anchors.fill: parent
        opacity: root.frost
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 0.48; color: "#08000000" }
            GradientStop { position: 0.76; color: "#34000000" }
            GradientStop { position: 1.0; color: "#96000000" }
        }
    }

    // ── TOP NOTCH ISLAND ─────────────────────────────────────────────────────

    LockIsland {
        held: root.held
    }

    // ── CLOCK ────────────────────────────────────────────────────────────────

    Item {
        id: clockContainer

        readonly property real restY: Math.round((root.height - clock.height) / 2 - 40)
        readonly property real awakeY: root.isActive
            ? Math.max(70, Math.round(root.height * 0.15))
            : clockContainer.restY

        anchors.horizontalCenter: parent.horizontalCenter
        y: clockContainer.restY + (clockContainer.awakeY - clockContainer.restY) * root.awake
        width: clock.width
        height: clock.height
        opacity: root.held * root.clockReveal
        scale: (root.isActive ? (1 - 0.08 * root.awake) : 1)
            * (0.92 + 0.08 * root.clockReveal)
        transformOrigin: Item.Top

        Behavior on y { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
        Behavior on scale { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            shadowOpacity: 0.5
            shadowVerticalOffset: 3
            shadowColor: Theme.island
        }

        LockClock {
            id: clock
            screenHeight: root.height
        }
    }

    // ── ACCOUNT & PASSWORD (Active screen only) ──────────────────────────────

    LockAccount {
        id: account

        visible: root.isActive
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.20) - 24 * (1 - root.awake)
        opacity: (root.isActive ? 1 : 0) * root.awake * root.held
        scale: 0.97 + 0.03 * root.awake
        transformOrigin: Item.Center

        Behavior on anchors.bottomMargin { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
        Behavior on scale { NumberAnimation { duration: Theme.durationMedium; easing.type: Easing.OutCubic } }

        onSubmitted: password => root.submitted(password)
    }

    // Hint on active screen when resting
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        visible: root.isActive
        opacity: (1 - root.awake) * root.held * root.clockReveal * 0.65
        text: "Click anywhere or press any key to unlock"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textMuted

        Behavior on opacity { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
    }

    // Hint on secondary screen when awake
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        visible: !root.isActive
        opacity: root.awake * root.held * 0.6
        text: "Click, or press any key, to unlock on this screen"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textMuted

        Behavior on opacity { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
    }

    // ── POWER ACTIONS ────────────────────────────────────────────────────────

    LockPower {
        opacity: (root.isActive ? 1 : 0) * root.awake * root.held
        visible: opacity > 0
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24

        Behavior on opacity { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
    }

    // Black overlay for power actions (reboot/shutdown/logout) triggered from the lock screen
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: SessionService.fadingOut ? 1 : 0
        visible: opacity > 0
        z: 9999
        Behavior on opacity {
            NumberAnimation { duration: SessionService.fadeDuration; easing.type: Easing.InOutCubic }
        }
    }
}
