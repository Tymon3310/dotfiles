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
        source: "background.jpg"
        sourceSize: Qt.size(root.width, root.height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        smooth: true
        mipmap: false
    }

    // Let the wallpaper stay vivid while gently protecting the clock and
    // controls from bright or busy areas of the image.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#08000000" }
            GradientStop { position: 0.42; color: "#10000000" }
            GradientStop { position: 0.72; color: "#38000000" }
            GradientStop { position: 1.0; color: "#a8000000" }
        }
    }

    // ── TOP NOTCH ISLAND ────────────────────────────────────────────────────

    LockIsland {
        id: topIsland

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        unlocked: root.faceVerified
        scanning: root.faceScanning
        failed: root.faceFailed || root.failed
        // Sit above the black blob that floods out of it, then fade at the end
        z: root.exitFrom === "island" && root.exitP > 0 ? 10000 : 0
        dissolve: root.exitFrom === "island" ? root.exitDissolve : 0
        onClicked: {
            if (!root.awake)
                root.wakeUp()
            else
                root.attemptFace()
        }
    }

    // ── AWAKE & AUTHENTICATION STATE ────────────────────────────────────────

    readonly property bool isPrimary: (typeof primaryScreen !== "undefined" ? primaryScreen : true)
    property bool awake: false

    property bool authenticating: false
    property bool failed: false
    property string message: ""

    property bool faceScanning: false
    property bool faceVerified: false
    property bool faceFailed: false
    property bool pendingFaceAuth: false
    property bool loginCommitted: false
    // Password was accepted for submission (optimistic ✓ in the pill)
    property bool confirmed: false
    property string queuedPassword: ""
    property string queuedUser: ""
    property int queuedSessionIndex: -1
    property string helperToken: ""
    property int helperTokenRetries: 0

    Timer {
        id: helperTokenRetryTimer
        interval: 500
        repeat: true
        running: root.helperToken === "" && root.helperTokenRetries < 10
        onTriggered: {
            root.helperTokenRetries++
            root.readHelperToken()
            if (root.helperToken !== "")
                stop()
        }
    }

    function readHelperToken(callback: var): void {
        try {
            let req = new XMLHttpRequest()
            req.onreadystatechange = function() {
                if (req.readyState === XMLHttpRequest.DONE) {
                    if (req.status === 200 || (req.status === 0 && req.responseText)) {
                        root.helperToken = req.responseText.trim()
                    }
                    if (typeof callback === "function") {
                        callback(root.helperToken)
                    }
                }
            }
            req.open("GET", "file:///run/sddm-helper-token")
            req.send()
        } catch (e) {
            if (typeof callback === "function") {
                callback("")
            }
        }
    }

    function wakeUp(): void {
        if (!root.awake) {
            root.awake = true
            Qt.callLater(account.claim)
            if (root.isPrimary)
                Qt.callLater(root.attemptFace)
        }
    }

    // SDDM cannot cancel PAM from QML. Stop the scan animation without
    // disabling password entry; a submitted password waits for PAM to finish.
    Timer {
        id: faceTimeout
        interval: 4500
        repeat: false
        onTriggered: {
            if (root.faceScanning) {
                root.faceScanning = false
                root.faceFailed = true
                root.message = qsTr("Face scan is taking too long — enter password")
            }
        }
    }

    // Face authentication through SDDM's PAM transaction.
    function attemptFace(): void {
        // fadingOut: a login or power action is already on its way out
        if (!root.isPrimary || root.authenticating || root.fadingOut)
            return
        // Let the PAM module perform biometric verification exactly once.
        // A separate UI-side biopass-helper run races PAM for the camera and
        // does not authenticate SDDM's PAM transaction.
        root.faceFailed = false
        root.attempt("")
    }

    // SDDM accepts only one PAM transaction at a time. Remember password
    // submissions during face authentication instead of sending a second login.
    function attempt(password: string): void {
        if (root.fadingOut)
            return
        if (root.authenticating) {
            if (root.pendingFaceAuth && password !== "") {
                root.queuedPassword = password
                root.queuedUser = account.userName
                root.queuedSessionIndex = session.currentIndex
                faceTimeout.stop()
                root.faceScanning = false
                root.message = qsTr("Password queued — waiting for face authentication")
            }
            return
        }
        root.beginLogin(password, account.userName, session.currentIndex)
    }

    function clearQueuedLogin(): void {
        root.queuedPassword = ""
        root.queuedUser = ""
        root.queuedSessionIndex = -1
    }

    function beginLogin(password: string, userName: string, sessionIndex: int): void {
        faceTimeout.stop()
        root.clearQueuedLogin()

        root.faceScanning = false
        // Keep the password input live while PAM performs the face attempt;
        // if it fails, text typed during the scan remains available.
        root.authenticating = true
        root.faceScanning = password === ""
        root.pendingFaceAuth = password === ""
        root.loginCommitted = false
        root.failed = false
        root.message = ""

        // Queue the login; face attempts stay visible until PAM responds.
        if (password === "")
            faceTimeout.restart()
        root.pendingPassword = password
        root.pendingUser = userName
        root.pendingSessionIndex = sessionIndex
        root.pendingLoginIsFace = password === ""
        root.pendingPowerAction = ""
        // Give the scan indicator a brief visible start before a fast PAM
        // success. SDDM tears the greeter down as soon as a login succeeds, so
        // password logins confirm optimistically: tick, morph the pill out to
        // black, then submit. A wrong password reverses it (onLoginFailed).
        root.confirmed = password !== ""
        if (password !== "")
            root.exitFrom = "pill"
        root.fadingOut = password !== ""
        sddmCommitTimer.start()
    }

    function acceptFace(): void {
        if (root.fadingOut)
            return
        faceTimeout.stop()
        root.faceScanning = false
        root.faceFailed = false
        root.failed = false
        root.message = ""
        root.faceVerified = true
        root.exitFrom = "island"
        root.fadingOut = true
    }

    Connections {
        target: sddm

        function onLoginSucceeded(): void {
            // Face logins only learn of success here; morph out of the island
            // (best effort: the greeter may be gone before it finishes).
            if (root.pendingFaceAuth)
                root.exitFrom = "island"
            faceTimeout.stop()
            root.clearQueuedLogin()
            root.pendingPassword = ""
            root.authenticating = false
            root.faceScanning = false
            root.faceVerified = true
            root.pendingFaceAuth = false
            root.failed = false
            root.message = ""
            root.fadingOut = true
        }

        function onLoginFailed(): void {
            const wasFaceAuth = root.pendingFaceAuth
            const password = root.queuedPassword
            const userName = root.queuedUser
            const sessionIndex = root.queuedSessionIndex
            root.clearQueuedLogin()
            root.pendingPassword = ""
            root.pendingFaceAuth = false
            root.loginCommitted = false
            faceTimeout.stop()
            sddmCommitTimer.stop()
            root.authenticating = false
            root.faceScanning = false
            root.confirmed = false
            root.fadingOut = false
            root.failed = true
            root.faceFailed = wasFaceAuth
            root.message = wasFaceAuth
                ? qsTr("Face not recognized — enter password")
                : qsTr("Wrong password")
            if (wasFaceAuth && password !== "")
                root.beginLogin(password, userName, sessionIndex)
        }

        function onInformationMessage(infoMsg: string): void {
            // Sent by pam.d/sddm after the face matches, then PAM pauses so
            // the tick and island morph can play before SDDM drops the greeter.
            if (infoMsg.trim() === "impasto:face-verified") {
                root.acceptFace()
                return
            }
            root.message = infoMsg
        }
    }

    // ── POWER FADEOUT STATE & EXECUTION ─────────────────────────────────────
    property bool fadingOut: false
    property string pendingPowerAction: ""
    property string pendingPassword: ""
    property string pendingUser: ""
    property int pendingSessionIndex: -1
    property bool pendingLoginIsFace: false

    Timer {
        id: sddmCommitTimer
        interval: root.pendingFaceAuth ? 100
            : root.pendingPowerAction !== "" ? 540
            : Theme.durationConfirm + Theme.durationExit + 40
        repeat: false
        onTriggered: {
            root.loginCommitted = true
            if (root.pendingPowerAction === "reboot" || root.pendingPowerAction === "reboot-uefi") {
                sddm.reboot()
            } else if (root.pendingPowerAction === "shutdown") {
                sddm.powerOff()
            } else {
                const password = root.pendingLoginIsFace ? "" : root.pendingPassword
                root.pendingPassword = ""
                sddm.login(root.pendingUser, password, root.pendingSessionIndex)
            }
        }
    }

    function triggerPowerFade(action: string): void {
        faceTimeout.stop()
        root.clearQueuedLogin()
        root.pendingPassword = ""
        root.faceScanning = false
        root.pendingFaceAuth = false
        root.loginCommitted = false
        root.confirmed = false
        root.exitFrom = ""
        root.pendingPowerAction = action

        // Notify local helper daemon of power intent & firmware-setup state
        const sendPowerRequest = function(token: string) {
            try {
                let req = new XMLHttpRequest()
                let endpoint = (action === "reboot-uefi") ? "reboot-uefi"
                             : (action === "shutdown") ? "shutdown" : "reboot-normal"
                let url = "http://127.0.0.1:18293/" + endpoint
                req.open("POST", url, true)
                if (token)
                    req.setRequestHeader("X-Helper-Token", token)
                req.send()
            } catch (e) {}
        }

        if (root.helperToken) {
            sendPowerRequest(root.helperToken)
        } else {
            root.readHelperToken(sendPowerRequest)
        }

        root.fadingOut = true
        sddmCommitTimer.start()
    }

    // ── FULL-SCREEN FADEOUT ──────────────────────────────────────────────────
    // Power actions dissolve the whole screen to black. Logins instead morph:
    // the black of the pill (password) or island (face) floods outward until it
    // covers the screen, with the source element riding on top and fading last.

    // "pill" | "island" | "" (plain fade)
    property string exitFrom: ""
    property real exitP: 0
    readonly property real exitDissolve: Math.max(0, (root.exitP - 0.6) / 0.4)

    // Source geometry, captured when the morph starts
    property rect exitRect: Qt.rect(0, 0, 0, 0)
    property real exitTopRadius: 0
    property real exitBottomRadius: 0

    function captureExitSource(): void {
        if (root.exitFrom === "pill") {
            const pill = account.capsule
            root.exitRect = pill.mapToItem(root, 0, 0, pill.width, pill.height)
            root.exitTopRadius = pill.height / 2
            root.exitBottomRadius = pill.height / 2
        } else if (root.exitFrom === "island") {
            root.exitRect = topIsland.mapToItem(root, 0, 0, topIsland.width, topIsland.height)
            root.exitTopRadius = 0
            root.exitBottomRadius = Theme.radiusLarge
        }
    }

    SequentialAnimation {
        id: exitIn

        // Let the ✓ land before the pill starts to grow
        PauseAnimation { id: exitPause; duration: Theme.durationConfirm }
        NumberAnimation {
            target: root
            property: "exitP"
            to: 1
            duration: Theme.durationExit
            easing.type: Easing.InOutCubic
        }
    }

    NumberAnimation {
        id: exitOut

        target: root
        property: "exitP"
        to: 0
        duration: Theme.durationMorph
        easing.type: Theme.easing
    }

    Item {
        id: sddmFadeOverlay
        anchors.fill: parent
        z: 9999
        visible: root.fadingOut || sddmBaseFade.opacity > 0 || root.exitP > 0

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.BlankCursor
            acceptedButtons: Qt.AllButtons
            onPressed: (mouse) => mouse.accepted = true
        }

        // Base fade to ensure all display corners smoothly dissolve to pure black
        Rectangle {
            id: sddmBaseFade
            anchors.fill: parent
            color: "#000000"
            opacity: root.fadingOut && root.exitFrom === "" ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 500; easing.type: Easing.InOutCubic }
            }
        }

        // Morph blob: grows from the source's exact shape to the full screen
        Rectangle {
            readonly property real p: root.exitP
            readonly property rect r: root.exitRect

            visible: root.exitFrom !== "" && p > 0
            color: "#000000"
            x: r.x * (1 - p)
            y: r.y * (1 - p)
            width: r.width + (sddmFadeOverlay.width - r.width) * p
            height: r.height + (sddmFadeOverlay.height - r.height) * p
            topLeftRadius: root.exitTopRadius * (1 - p)
            topRightRadius: root.exitTopRadius * (1 - p)
            bottomLeftRadius: root.exitBottomRadius * (1 - p)
            bottomRightRadius: root.exitBottomRadius * (1 - p)
        }

        Connections {
            target: root
            function onFadingOutChanged(): void {
                if (root.fadingOut && !root.loginCommitted) {
                    sddmCommitTimer.start()
                } else if (!root.fadingOut) {
                    sddmCommitTimer.stop()
                }

                if (root.fadingOut && root.exitFrom !== "") {
                    root.captureExitSource()
                    exitOut.stop()
                    exitPause.duration = root.exitFrom === "pill" ? Theme.durationConfirm : 0
                    exitIn.restart()
                } else if (!root.fadingOut) {
                    exitIn.stop()
                    if (root.exitP > 0)
                        exitOut.restart()
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
        // Sit above the black blob that floods out of it, then fade at the end
        z: root.exitFrom === "pill" && root.exitP > 0 ? 10000 : 10

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
        faceAuthPending: root.pendingFaceAuth
        faceVerified: root.faceVerified
        faceFailed: root.faceFailed
        confirmed: root.confirmed
        dissolve: root.exitFrom === "pill" ? root.exitDissolve : 0

        onSubmitted: password => root.attempt(password)
        onFaceRetryRequested: root.attemptFace()
        onDismissed: {
            root.failed = false
            root.message = ""
        }
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
    Component.onCompleted: {
        root.forceActiveFocus()
        root.readHelperToken()
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space && !account.hasText) {
            if (!root.awake)
                root.wakeUp()
            else
                root.attemptFace()
            event.accepted = true
            return
        }
        if (!root.awake) {
            root.wakeUp()
        }
        if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32) {
            account.append(event.text)
            event.accepted = true
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
