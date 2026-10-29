
import QtQuick
import QtQuick.Effects
import Quickshell

import "../theme"
import "../services"

Item {
    id: root

    property string screenName: ""
    readonly property bool isActive: (Quickshell.screens.length <= 1) || (screenName !== "" && screenName === LockService.activeScreen)

    // Each screen plays a part, so three monitors read as one lock rather
    // than three copies: "main" where you unlock (the clock and password),
    // then the others left to right: "stage" (the music, large, or the day
    // as a calendar page) and "info" (weather, agents, what arrived).
    // Unlocking from another screen moves the parts with you.
    readonly property var others: Quickshell.screens
        .filter(s => s.name !== LockService.activeScreen)
        .sort((a, b) => a.x - b.x)
        .map(s => s.name)
    readonly property string role: {
        if (root.isActive)
            return "main"
        const index = root.others.indexOf(root.screenName)
        if (root.others.length === 1)
            return (MediaService.available && MediaService.title !== "") ? "stage" : "info"
        return index === 0 ? "stage" : "info"
    }
    // The music has its own screen when there is more than one.
    readonly property bool stageElsewhere: Quickshell.screens.length > 1

    property real mainFade: root.role === "main" ? 1 : 0
    property real stageFade: root.role === "stage" ? 1 : 0
    property real infoFade: root.role === "info" ? 1 : 0
    Behavior on mainFade { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
    Behavior on stageFade { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
    Behavior on infoFade { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }

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
            duration: Math.round(520 * Theme.motion)
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            PauseAnimation { duration: Math.round(120 * Theme.motion) }
            NumberAnimation {
                target: root
                property: "clockReveal"
                from: 0
                to: 1
                // No overshoot here: OutBack wobble on the big clock reads as lag.
                duration: Math.round(520 * Theme.motion)
                easing.type: Easing.OutCubic
            }
        }
    }

    // The frozen shot loads synchronously with the surface, so the reveal can
    // begin as soon as its texture is up. The fallback still caps the wait if
    // the decoder ever stalls.
    property bool entryStarted: false

    // When this lock began; the clock counts notifications since.
    property real lockedAt: Date.now()

    function armEntry(): void {
        root.lockedAt = Date.now()
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

    // One wake animation drives the whole bottom-left block: the clock lifts
    // first and the password follows into the room it leaves (pillReveal);
    // going back to rest, the password leaves first and the clock settles
    // after. Waking eases out, so it answers on the next frame; resting
    // eases in and out.
    Behavior on awake {
        NumberAnimation {
            duration: Math.round(460 * Theme.motion)
            easing.type: LockService.awake ? Easing.OutCubic : Easing.InOutCubic
        }
    }

    readonly property real pillReveal: Math.max(0, Math.min(1, (root.awake - 0.4) / 0.6))

    // Fades the password between screens when the active one changes.
    property real activeFade: root.isActive ? 1 : 0
    Behavior on activeFade { NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing } }

    // The typed text is cleared once the pill has gone, not while it fades
    // (it would shrink to its resting width on the way out).
    Timer {
        id: clearLater
        interval: Math.round(500 * Theme.motion)
        onTriggered: {
            if (!LockService.awake)
                account.clear()
        }
    }

    Connections {
        target: LockService
        function onAwakeChanged(): void {
            if (!LockService.awake) {
                clearLater.restart()
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
                clearLater.restart()
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

    // The frozen desktop goes out of focus as the lock arrives and comes back
    // into focus as it leaves: the blur strength itself follows the reveal
    // (re-blurred each frame of the animation; the GPU keeps up easily),
    // rather than a blurred copy fading over a sharp one.
    readonly property real focusOut: root.lockReveal * root.held

    MultiEffect {
        anchors.fill: parent
        source: blurShot
        visible: blurShot.status === Image.Ready && root.held > 0.01
        blurEnabled: true
        blur: root.focusOut
        blurMax: SettingsService.lockBlur
        brightness: (root.screenName === "DP-1" ? 0.05 : -0.02) * root.focusOut
        contrast: (root.screenName === "DP-1" ? 0.08 : 0.0) * root.focusOut
        saturation: 0.0
    }

    // While music plays, the cover washes the background in its colours.
    // A tiny decode, blurred: only its colours matter.
    Image {
        id: artWash

        readonly property bool wanted: MediaService.available && MediaService.artUrl !== ""
            && artWash.status === Image.Ready

        anchors.fill: parent
        source: MediaService.artUrl
        sourceSize: Qt.size(6, 6)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        opacity: (artWash.wanted ? 0.45 : 0) * root.lockReveal * root.held
        visible: opacity > 0.01

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1
            blurMax: 64
            // Darkened and pushed towards colour: a tint, never a lighter
            // screen (a pale cover would otherwise grey everything out).
            brightness: -0.6
            saturation: 0.7
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: 0.22 * root.held
    }

    // Darker towards the bottom, where the clock and the controls sit.
    Rectangle {
        anchors.fill: parent
        opacity: root.held
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 0.45; color: "#10000000" }
            GradientStop { position: 0.75; color: "#50000000" }
            GradientStop { position: 1.0; color: "#b0000000" }
        }
    }

    // Shared by the clock, the password and the media: the corners' inset.
    readonly property int marginX: Math.round(root.width * 0.055)
    readonly property int marginBottom: Math.round(root.height * 0.09)


    LockIsland {
        held: root.held
    }


    // Bottom left: the clock, lifted to make room for the password when
    // awake.
    Item {
        id: clockContainer

        readonly property real lift: root.isActive ? root.awake * (account.pillHeight + 22) : 0

        x: root.marginX
        y: root.height - root.marginBottom - height - lift
        width: clock.width
        height: clock.height
        // Each line of the clock rises in on its own (LockClock.reveal);
        // leaving plays the same in reverse as `held` falls.
        opacity: root.mainFade
        visible: opacity > 0.01

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
            reveal: root.clockReveal * root.held
            since: root.lockedAt
        }
    }


    LockAccount {
        id: account

        visible: root.isActive
        // Under the clock, its pill lined up with the date.
        x: root.marginX + Math.round(clock.timeSize * 0.035) - 2
        y: root.height - root.marginBottom - account.pillHeight + 12 * (1 - root.pillReveal)
        opacity: root.activeFade * root.pillReveal * root.held
        scale: 0.98 + 0.02 * root.pillReveal
        transformOrigin: Item.Left

        onSubmitted: password => root.submitted(password)
    }

    LockStage {
        anchors.fill: parent
        opacity: root.stageFade
        visible: opacity > 0.01
        reveal: root.clockReveal * root.held
    }

    LockInfo {
        anchors.fill: parent
        opacity: root.infoFade
        visible: opacity > 0.01
        reveal: root.clockReveal * root.held
        since: root.lockedAt
    }

    // Above the media: the song's lyrics, when they are synced.
    LockLyrics {
        anchors.right: parent.right
        anchors.rightMargin: root.marginX
        y: media.y - height - 18
        // A wrapped line makes the block taller: glide up, not jump.
        Behavior on y { NumberAnimation { duration: Math.round(300 * Theme.motion); easing.type: Easing.OutCubic } }
        screenHeight: root.height
        maxWidth: Math.round(root.width * 0.38)
        wanted: media.visible
        visible: wanted && shown
        opacity: media.reveal
        transform: Translate { x: 40 * (1 - media.reveal) }
    }

    // Bottom right: what is playing.
    LockMedia {
        id: media
        anchors.right: parent.right
        anchors.rightMargin: root.marginX
        y: root.height - root.marginBottom - height
        screenHeight: root.height
        visible: root.isActive && shown && !root.stageElsewhere
        // Slides in from the right edge, a beat after the clock.
        readonly property real reveal: Math.max(0, Math.min(1, (root.clockReveal * root.held - 0.25) / 0.75))
        opacity: reveal
        transform: Translate { x: 40 * (1 - media.reveal) }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        visible: root.isActive
        opacity: (1 - root.awake) * root.held * root.clockReveal * 0.5
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
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.top: parent.top
        anchors.topMargin: 18

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
