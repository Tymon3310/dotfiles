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
    readonly property bool isActive: (screenName === "" || screenName === LockService.activeScreen || Quickshell.screens.length <= 1)

    signal submitted(string password)

    function claim(): void {
        if (root.isActive)
            account.claim()
    }

    property real held: LockService.leaving ? 0 : 1

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
            if (!LockService.awake)
                account.clear()
            else if (root.isActive)
                Qt.callLater(account.claim)
        }
        function onActiveScreenChanged(): void {
            if (root.isActive)
                Qt.callLater(account.claim)
        }
    }

    focus: root.isActive
    Keys.onPressed: event => {
        if (!root.isActive) return
        LockService.setActiveScreen(root.screenName)
        LockService.rouse()
        account.claim()
    }

    TapHandler {
        onTapped: {
            LockService.setActiveScreen(root.screenName)
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
        visible: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: false
    }

    MultiEffect {
        anchors.fill: parent
        source: shot
        visible: shot.status === Image.Ready
        blurEnabled: true
        blur: root.held
        blurMax: SettingsService.lockBlur
        // Gentle luminance correction for DP-1 HDR 10-bit buffer without washing out contrast
        brightness: (root.screenName === "DP-1" ? 0.05 : -0.02) * root.held
        contrast: (root.screenName === "DP-1" ? 0.08 : 0.0) * root.held
        saturation: 0.0
    }

    // Balanced scrim for clear legibility without gloom or washout
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: 0.16 * root.held
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
        opacity: root.held
        scale: root.isActive ? (1 - 0.08 * root.awake) : 1
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

        Behavior on anchors.bottomMargin { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }

        onSubmitted: password => root.submitted(password)
    }

    // Hint on secondary screen when awake
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        visible: !root.isActive
        opacity: root.awake * root.held * 0.6
        text: "Click anywhere to unlock on this screen"
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
}
