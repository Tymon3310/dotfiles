// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M A I N                                                                │
// │   sddm login screen · impasto aesthetics, lockscreen animations & face   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

import "components"

Rectangle {
    id: root

    color: "#000000"

    // ── BACKGROUND ──────────────────────────────────────────────────────────
    // Full 5K native resolution image (5120x3200) loaded uncompressed without blur or downsampling

    Image {
        id: bgImage
        anchors.fill: parent
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        smooth: true
        mipmap: false
    }

    // ── TOP NOTCH ISLAND ────────────────────────────────────────────────────

    LockIsland {
        id: topIsland

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        unlocked: root.faceVerified
        scanning: root.faceScanning
        failed: root.faceFailed || root.failed
        onClicked: root.wakeUp()
    }

    // ── AWAKE & AUTHENTICATION STATE ────────────────────────────────────────

    property bool awake: false

    property bool authenticating: false
    property bool failed: false
    property string message: ""

    property bool faceScanning: false
    property bool faceVerified: false
    property bool faceFailed: false
    property bool isFaceAttempt: false

    function wakeUp(): void {
        if (!root.awake) {
            root.awake = true
            root.attemptFace()
            Qt.callLater(account.claim)
        }
    }

    // Safety timeout so face scan never hangs or blocks input
    Timer {
        id: faceTimeout
        interval: 4000
        repeat: false
        onTriggered: {
            if (root.faceScanning) {
                root.faceScanning = false
                root.faceFailed = true
            }
        }
    }

    // Non-blocking face authentication attempt
    function attemptFace(): void {
        if (root.authenticating || root.faceScanning)
            return
        root.isFaceAttempt = true
        root.faceScanning = true
        root.faceVerified = false
        root.faceFailed = false
        root.failed = false
        root.message = ""
        // Notice: root.authenticating remains FALSE so the password field is 100% active and editable!
        faceTimeout.restart()
        sddm.login(account.userName, "", session.currentIndex)
    }

    // User password authentication attempt (cancels face scan and submits)
    function attempt(password: string): void {
        faceTimeout.stop()
        root.isFaceAttempt = false
        root.faceScanning = false
        root.authenticating = true
        root.failed = false
        root.message = ""
        sddm.login(account.userName, password, session.currentIndex)
    }

    Connections {
        target: sddm

        function onLoginSucceeded(): void {
            faceTimeout.stop()
            root.authenticating = false
            root.faceScanning = false
            root.faceVerified = true
            root.failed = false
            root.message = ""
        }

        function onLoginFailed(): void {
            faceTimeout.stop()
            root.authenticating = false
            if (root.isFaceAttempt) {
                root.isFaceAttempt = false
                root.faceScanning = false
                root.faceFailed = true
            } else {
                root.failed = true
                root.message = qsTr("Wrong password")
            }
        }

        function onInformationMessage(infoMsg: string): void {
            root.message = infoMsg
        }
    }

    // ── POWER FADEOUT STATE & EXECUTION ─────────────────────────────────────
    property bool fadingOut: false
    property string pendingPowerAction: ""

    Timer {
        id: sddmCommitTimer
        interval: 600
        repeat: false
        onTriggered: {
            if (root.pendingPowerAction === "reboot" || root.pendingPowerAction === "reboot-uefi") {
                sddm.reboot()
            } else if (root.pendingPowerAction === "shutdown") {
                sddm.powerOff()
            }
        }
    }

    function triggerPowerFade(action: string): void {
        faceTimeout.stop()
        root.faceScanning = false
        root.pendingPowerAction = action

        // Notify local helper daemon of power intent & firmware-setup state
        try {
            let req = new XMLHttpRequest()
            let endpoint = (action === "reboot-uefi") ? "reboot-uefi"
                         : (action === "shutdown") ? "shutdown" : "reboot-normal"
            req.open("GET", "http://127.0.0.1:18293/" + endpoint, true)
            req.send()
        } catch (e) {}

        root.fadingOut = true
        sddmCommitTimer.start()
    }

    // ── EXPANDING WAVE FADEOUT OVERLAY ───────────────────────────────────────
    Item {
        id: sddmFadeOverlay
        anchors.fill: parent
        z: 9999
        visible: root.fadingOut || sddmBaseFade.opacity > 0

        readonly property real centerX: root.width / 2
        readonly property real centerY: 20
        readonly property real targetRadius: Math.ceil(Math.hypot(root.width / 2, root.height)) + 100

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.BlankCursor
            acceptedButtons: Qt.AllButtons
            onPressed: (mouse) => mouse.accepted = true
        }

        Rectangle {
            id: sddmBaseFade
            anchors.fill: parent
            color: "#000000"
            opacity: 0.0
        }

        Rectangle {
            id: sddmMainWave
            width: 0
            height: width
            radius: width / 2
            x: sddmFadeOverlay.centerX - width / 2
            y: sddmFadeOverlay.centerY - height / 2
            color: "#000000"
        }

        ParallelAnimation {
            id: sddmWaveAnim

            NumberAnimation {
                target: sddmMainWave
                property: "width"
                from: 60
                to: sddmFadeOverlay.targetRadius * 2.2
                duration: 600
                easing.type: Easing.OutQuad
            }

            SequentialAnimation {
                PauseAnimation { duration: 270 }
                NumberAnimation {
                    target: sddmBaseFade
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 330
                    easing.type: Easing.InQuad
                }
            }
        }

        Connections {
            target: root
            function onFadingOutChanged(): void {
                if (root.fadingOut) {
                    sddmMainWave.width = 60
                    sddmBaseFade.opacity = 0.0
                    sddmWaveAnim.restart()
                } else {
                    sddmWaveAnim.stop()
                    sddmBaseFade.opacity = 0.0
                    sddmMainWave.width = 0
                }
            }
        }
    }

    // ── WAKE-UP FULLSCREEN TAP AREA ─────────────────────────────────────────
    // At z: 50, but PowerRow and SessionPicker are at z: 60, allowing power actions
    // to be clicked directly without waking up or triggering the camera!

    MouseArea {
        id: sleepTapArea
        anchors.fill: parent
        z: root.awake ? -1 : 50
        cursorShape: root.awake ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: root.wakeUp()
    }

    // ── CLOCK (MORPHS FROM CENTER TO COMPACT POSITION) ──────────────────────

    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Item {
        id: clockContainer

        readonly property real restY: Math.round((root.height - clockCol.implicitHeight) / 2 - 30)
        readonly property real awakeY: Math.max(68, Math.round(root.height * 0.14))

        anchors.horizontalCenter: parent.horizontalCenter
        y: clockContainer.restY + (clockContainer.awakeY - clockContainer.restY) * (root.awake ? 1 : 0)
        width: clockCol.implicitWidth
        height: clockCol.implicitHeight
        scale: root.awake ? 0.86 : 1.0
        transformOrigin: Item.Top

        Behavior on y {
            NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.8
            shadowOpacity: 0.6
            shadowVerticalOffset: 3
            shadowColor: Theme.island
        }

        Column {
            id: clockCol
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "HH:mm")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeClock
                font.weight: Font.Light
                color: Theme.text
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "dddd, d MMMM")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Normal
                color: Theme.text
                opacity: 0.85
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.wakeUp()
        }
    }

    // ── ACCOUNT PILL (LOCKSCREEN MORPHING CAPSULE) ──────────────────────────

    AccountPill {
        id: account

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.20) - (root.awake ? 0 : 28)
        opacity: root.awake ? 1 : 0
        visible: opacity > 0
        z: 10

        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }

        awake: root.awake
        users: userModel

        authenticating: root.authenticating
        failed: root.failed
        message: root.message
        capsLock: keyboard.capsLock

        faceScanning: root.faceScanning
        faceVerified: root.faceVerified
        faceFailed: root.faceFailed

        onSubmitted: password => root.attempt(password)
        onFaceRetryRequested: root.attemptFace()
        onUserChosen: index => {
            root.failed = false
            root.message = ""
            root.attemptFace()
        }
    }

    // Hint when resting/sleeping
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        opacity: root.awake ? 0 : 0.65
        visible: opacity > 0
        text: qsTr("Click anywhere or press any key to unlock")
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textMuted

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationFast }
        }
    }

    // ── BATTERY ─────────────────────────────────────────────────────────────

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: Theme.barTopMargin + 6
        width: Theme.capsuleHeight
        height: Theme.capsuleHeight
        radius: Theme.radiusPill
        color: Theme.island
        border.width: 1
        border.color: Theme.islandBorder
        visible: charge.available
        opacity: root.awake ? 1 : 0.5
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

        BatteryRing {
            id: charge

            anchors.centerIn: parent
            size: Theme.capsuleHeight
        }
    }

    // ── POWER AND SESSION (z: 60 to sit above sleepTapArea) ──────────────────

    PowerRow {
        z: 60
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        opacity: root.awake ? 1.0 : 0.6
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

        canReboot: sddm.canReboot
        canPowerOff: sddm.canPowerOff

        onRebootRequested: (toUefi) => root.triggerPowerFade(toUefi ? "reboot-uefi" : "reboot")
        onPowerOffRequested: () => root.triggerPowerFade("shutdown")
    }

    SessionPicker {
        id: session
        z: 60

        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        opacity: root.awake ? 1.0 : 0.6
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

        sessions: sessionModel
        currentIndex: sessionModel.lastIndex
    }

    // ── KEYBOARD INTERACTION ────────────────────────────────────────────────

    focus: true
    Component.onCompleted: root.forceActiveFocus()
    Keys.onPressed: event => {
        if (!root.awake) {
            root.wakeUp()
            if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32) {
                account.append(event.text)
                event.accepted = true
            }
        }
    }

    Keys.onEscapePressed: {
        if (account.hasText) {
            account.clear()
        } else if (root.awake) {
            root.awake = false
        }
    }
}
