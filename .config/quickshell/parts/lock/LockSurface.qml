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
    property bool entryDone: false
    ParallelAnimation {
        id: lockEntry
        running: false
        onStopped: root.entryDone = true

        NumberAnimation {
            target: root
            property: "lockReveal"
            from: 0
            to: 1
            duration: Math.round(380 * Theme.motion)
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            PauseAnimation { duration: Math.round(80 * Theme.motion) }
            NumberAnimation {
                target: root
                property: "clockReveal"
                from: 0
                to: 1
                // No overshoot here: OutBack wobble on the big clock reads as lag.
                duration: Math.round(280 * Theme.motion)
                easing.type: Easing.OutCubic
            }
        }
    }

    // The screenshots decode asynchronously, so hold the entry animation
    // until they are on screen; otherwise the reveal plays out over a black
    // rect and the wallpaper pops in mid-animation. A short fallback caps
    // the wait when the decoder stalls.
    property bool entryStarted: false

    function armEntry(): void {
        root.entryStarted = false
        root.entryDone = false
        root.lockReveal = 0
        root.clockReveal = 0
        entryFallback.restart()
        root.tryEntry()
    }

    function tryEntry(): void {
        if (root.entryStarted)
            return
        // Gate on the blur source only: the sharp layer loads after the
        // entry (see below), so waiting for it would stall the reveal.
        const settled = (blurShot.status === Image.Ready || blurShot.status === Image.Error || String(blurShot.source) === "")
        if (!settled)
            return
        // One frame so the texture uploads land before the reveal animates.
        entrySettle.restart()
    }

    function startEntryNow(): void {
        if (root.entryStarted)
            return
        root.entryStarted = true
        entryFallback.stop()
        console.info("[lock-t] entry started")
        lockEntry.restart()
    }

    Timer {
        id: entryFallback
        interval: Math.round(250 * Theme.motion)
        onTriggered: root.startEntryNow()
    }

    Timer {
        id: entrySettle
        interval: 32
        onTriggered: root.startEntryNow()
    }

    Component.onCompleted: {
        root.armEntry()
        // Hold keyboard focus while resting so the first keypress wakes
        // without needing a mouse click to focus the password field.
        root.forceActiveFocus()
    }

    Connections {
        target: LockService
        function onLockedChanged(): void {
            if (!LockService.locked)
                return
            root.armEntry()
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
            console.info("[lock-t] space pressed")
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

    // Frozen desktop frame.
    Item {
        id: frame
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: Theme.island
        }

        // Half-resolution copy feeding ONLY the blur. Fullscreen blur passes and
        // texture uploads cost ~4x less this way; under a radius-48 blur the lost
        // detail is invisible. Must stay visible (invisible items don't feed
        // effects on Qt 6); file order puts it before the opaque full-res shot,
        // which covers it fully, so it never shows on screen.
        Image {
            id: blurShot
            anchors.fill: parent
            source: LockService.shotSourceFor(root.screenName)
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(Math.max(1, Math.round(root.width / 2)), Math.max(1, Math.round(root.height / 2)))
            asynchronous: true
            cache: false
            onStatusChanged: root.tryEntry()
        }

        Image {
            id: shot
            anchors.fill: parent
            // Loads only after the entry (or when leaving starts): at rest
            // the full blur covers this layer, so decoding it in the entry
            // window only buys jank. The pop is invisible under the blur.
            source: (root.entryDone || LockService.leaving) ? LockService.shotSourceFor(root.screenName) : ""
            visible: true
            fillMode: Image.PreserveAspectCrop
            // Half resolution like the blur source: decode + upload ~4x
            // cheaper, and this layer is only ever seen mid-fade under the
            // full blur, so the lost sharpness is invisible.
            sourceSize: Qt.size(Math.max(1, Math.round(root.width / 2)), Math.max(1, Math.round(root.height / 2)))
            // Async so the multi-megapixel JPEG decode never blocks the GUI
            // thread mid-animation.
            asynchronous: true
            cache: false
        }
    }

    // Frost the whole frozen screenshot in place. The blur is STATIC (rendered
    // once per lock); only its opacity animates — fading the blurred layer in
    // over the sharp shot on lock and out again on unlock. Animating the blur
    // radius itself would re-run a fullscreen blur every frame and stutter.
    MultiEffect {
        anchors.fill: parent
        source: blurShot
        visible: blurShot.status === Image.Ready && root.held > 0.01
        opacity: root.lockReveal * root.held
        blurEnabled: true
        blur: 1
        blurMax: SettingsService.lockBlur
        brightness: (root.screenName === "DP-1" ? 0.05 : -0.02)
        contrast: (root.screenName === "DP-1" ? 0.08 : 0.0)
        saturation: 0.0
    }

    // Balanced scrim for clear legibility without gloom or washout
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: 0.16 * root.held
    }

    // A soft lower vignette keeps the password capsule readable without
    // flattening the captured wallpaper behind the clock.
    Rectangle {
        anchors.fill: parent
        opacity: root.held
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

        // No Behaviors here: y/scale are already continuously animated via
        // the `awake`/`clockReveal` props. A Behavior on top would chase a
        // moving target and feel laggy/floaty.

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

        // No Behaviors on geometry: bottomMargin/scale already move smoothly
        // via the animated `awake` prop; chasing them would lag. Opacity keeps
        // its Behavior for the `isActive` step when switching screens.
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }

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
