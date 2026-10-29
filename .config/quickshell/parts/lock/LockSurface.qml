
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

    // The frozen shot loads synchronously with the surface, so the reveal can
    // begin as soon as its texture is up. The fallback still caps the wait if
    // the decoder ever stalls.
    property bool entryStarted: false

    function armEntry(): void {
        root.entryStarted = false
        root.lockReveal = 0
        root.clockReveal = 0
        entryFallback.restart()
        root.tryEntry()
    }

    function tryEntry(): void {
        if (root.entryStarted)
            return
        // Gate on the blur source: it is the layer that is drawn — the blur
        // effect reads it and it shows through as the blur fades.
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

    // Release: OutCubic, so the unlock answers on the very next frame
    // instead of easing in (InOutCubic read as a beat of lag after the
    // password). LockService lifts the surface at 80% of this.
    Behavior on held {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Easing.OutCubic }
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


    Item {
        id: frame
        anchors.fill: parent
        // With xray the live desktop is drawn underneath: fade the frozen
        // frame out onto it so the surface lifts with no visible cut (a
        // frozen wallpaper/JPEG frame snapping to the live one read as a
        // blink). Without xray only black is underneath, so stay opaque.
        opacity: (LockService.leaving && LockService.xray) ? root.held : 1

        Rectangle {
            anchors.fill: parent
            color: Theme.island
        }

        // Frozen desktop: feeds the blur AND is the first visible frame of the
        // lock. Loaded SYNCHRONOUSLY so the surface never paints its bare black
        // base for a frame while the JPEG decodes — that gap read as a
        // fullscreen black flash on entry. Full resolution so neither the
        // sharp reveal nor the blur looks upscaled. Must stay visible
        // (invisible items don't feed effects on Qt 6).
        Image {
            id: blurShot
            anchors.fill: parent
            source: LockService.shotSourceFor(root.screenName)
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(Math.max(1, Math.round(root.width)), Math.max(1, Math.round(root.height)))
            asynchronous: false
            cache: false
            onStatusChanged: root.tryEntry()
        }
    }

    // Frost the whole frozen screenshot in place. The blur is STATIC (rendered
    // once per lock); only its opacity animates — fading the blurred layer in
    // over the sharp desktop on lock and out again on unlock. Animating the
    // blur radius itself would re-run a fullscreen blur every frame.
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


    LockIsland {
        held: root.held
    }


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


    LockPower {
        opacity: (root.isActive ? 1 : 0) * root.awake * root.held
        visible: opacity > 0
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24

        Behavior on opacity { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
    }

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
