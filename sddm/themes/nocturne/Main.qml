import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import QtQuick.Effects

import "components"

Rectangle {
    id: root

    color: "#000000"

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

    // The wallpaper goes out of focus as the greeter appears (the blur
    // strength follows `reveal`), like the desktop's lock screen.
    property real reveal: 0
    property real clockReveal: 0
    SequentialAnimation {
        running: true
        PauseAnimation { duration: 150 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "reveal"; to: 1; duration: 700; easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: 180 }
                NumberAnimation { target: root; property: "clockReveal"; to: 1; duration: 600; easing.type: Easing.OutCubic }
            }
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: bgImage
        blurEnabled: true
        blur: root.reveal
        blurMax: 48
        brightness: -0.04 * root.reveal
    }

    Rectangle {
        anchors.fill: parent
        color: "#bf000000"
        opacity: 0.22 * root.reveal
    }

    // Darker towards the bottom, where the clock and the controls sit.
    Rectangle {
        anchors.fill: parent
        opacity: root.reveal
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 0.45; color: "#10000000" }
            GradientStop { position: 0.75; color: "#50000000" }
            GradientStop { position: 1.0; color: "#b0000000" }
        }
    }

    // Shared by the clock and the password: the corner's inset.
    readonly property int marginX: Math.round(root.width * 0.055)
    readonly property int marginBottom: Math.round(root.height * 0.09)
    readonly property int timeSize: Math.round(root.height * 0.2)

    // One wake animation for the bottom-left block: the clock lifts first and
    // the password follows into the room it leaves; going back, the password
    // leaves first and the clock settles after.
    property real awakeP: root.awake ? 1 : 0
    Behavior on awakeP {
        NumberAnimation { duration: 460; easing.type: root.awake ? Easing.OutCubic : Easing.InOutCubic }
    }
    readonly property real pillReveal: Math.max(0, Math.min(1, (root.awakeP - 0.4) / 0.6))

    // Date, time: each rises in on its own.
    function part(index: int): real {
        return Math.max(0, Math.min(1, (root.clockReveal - index * 0.12) / 0.76))
    }


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


    readonly property bool isPrimary: (typeof primaryScreen !== "undefined" ? primaryScreen : true)

    // Each screen plays a part instead of showing the same login three
    // times: the primary one logs in; the others, left to right, show a
    // greeting (pointing at the login screen) and the day as a calendar
    // page. Each screen runs its own greeter, so a key or click on a side
    // screen makes that one a login screen too: a password is never typed
    // into a field nobody can see.
    property bool claimed: false

    // KWin gives the keyboard to the greeter shown last, often a side
    // screen's. The primary one asks for it once all are up.
    Timer {
        interval: 600
        running: root.isPrimary
        onTriggered: {
            if (root.Window.window)
                root.Window.window.requestActivate()
        }
    }

    // A key on a side screen with the mouse elsewhere: point at the login
    // screen instead of opening one here.
    property bool sideHint: false
    Timer {
        id: sideHintTimer
        interval: 2500
        onTriggered: root.sideHint = false
    }
    HoverHandler { id: screenHover }
    readonly property var primaryInfo: Qt.application.screens.length > 0
        ? Qt.application.screens[0] : null
    readonly property var sideNames: {
        const list = []
        for (let i = 1; i < Qt.application.screens.length; i++)
            list.push(Qt.application.screens[i])
        return list.sort((a, b) => a.virtualX - b.virtualX).map(s => s.name)
    }
    readonly property string role: {
        if (root.isPrimary || root.claimed || Qt.application.screens.length <= 1)
            return "main"
        return root.sideNames.indexOf(Screen.name) === 0 ? "greeting" : "date"
    }
    property real mainFade: root.role === "main" ? 1 : 0
    Behavior on mainFade { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
    // Where the login screen is, from here.
    readonly property bool loginOnLeft: root.primaryInfo
        ? root.primaryInfo.virtualX < Screen.virtualX : true
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
        root.claimed = true
        root.sideHint = false
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

    // SDDM accepts only one PAM transaction at a time. A password submitted
    // during a face scan replaces it if the face login hasn't been sent yet.
    // Otherwise the scan is cancelled via the helper so PAM fails fast and
    // the user can simply press Enter again — nothing is queued.
    function attempt(password: string): void {
        if (root.fadingOut)
            return
        if (root.authenticating) {
            if (root.pendingFaceAuth && password !== "") {
                if (!root.loginCommitted) {
                    sddmCommitTimer.stop()
                    root.beginLogin(password, account.userName, session.currentIndex)
                    return
                }
                faceTimeout.stop()
                root.faceScanning = false
                root.faceFailed = false
                root.helperPost("face-cancel")
                root.message = qsTr("Face scan cancelled — press Enter to log in")
            }
            return
        }
        root.beginLogin(password, account.userName, session.currentIndex)
    }

    function helperPost(endpoint: string): void {
        const send = function(token: string) {
            try {
                let req = new XMLHttpRequest()
                req.open("POST", "http://127.0.0.1:18293/" + endpoint, true)
                if (token)
                    req.setRequestHeader("X-Helper-Token", token)
                req.send()
            } catch (e) {}
        }
        if (root.helperToken)
            send(root.helperToken)
        else
            root.readHelperToken(send)
    }

    function beginLogin(password: string, userName: string, sessionIndex: int): void {
        faceTimeout.stop()

        root.faceScanning = false
        // Keep the password input live while PAM performs the face attempt;
        // if it fails, text typed during the scan remains available.
        root.authenticating = true
        root.faceScanning = password === ""
        root.pendingFaceAuth = password === ""
        root.loginCommitted = false
        root.failed = false
        root.message = ""

        // Hold the login; face attempts stay visible until PAM responds.
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
        }

        function onInformationMessage(infoMsg: string): void {
            // Sent by pam.d/sddm after the face matches, then PAM pauses so
            // the tick and island morph can play before SDDM drops the greeter.
            if (infoMsg.trim() === "nocturne:face-verified") {
                root.acceptFace()
                return
            }
            root.message = infoMsg
        }
    }

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
        root.pendingPassword = ""
        root.faceScanning = false
        root.pendingFaceAuth = false
        root.loginCommitted = false
        root.confirmed = false
        root.exitFrom = ""
        root.pendingPowerAction = action

        // Notify local helper daemon of power intent & firmware-setup state
        root.helperPost((action === "reboot-uefi") ? "reboot-uefi"
                        : (action === "shutdown") ? "shutdown" : "reboot-normal")

        root.fadingOut = true
        sddmCommitTimer.start()
    }

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

        // Morph blob: starts as the source's exact shape and swells into a
        // circle around the source's centre, staying fully round, until it is
        // big enough to cover the farthest screen corner.
        Rectangle {
            readonly property real p: root.exitP
            readonly property rect r: root.exitRect
            readonly property real cx: r.x + r.width / 2
            readonly property real cy: r.y + r.height / 2
            readonly property real reach: Math.max(
                Math.hypot(cx, cy),
                Math.hypot(sddmFadeOverlay.width - cx, cy),
                Math.hypot(cx, sddmFadeOverlay.height - cy),
                Math.hypot(sddmFadeOverlay.width - cx, sddmFadeOverlay.height - cy))
            // Round off the source's square corners (island top) early on
            readonly property real round: Math.min(1, p * 3)
            readonly property real stadium: Math.min(width, height) / 2

            visible: root.exitFrom !== "" && p > 0
            color: "#000000"
            width: r.width + (2 * reach - r.width) * p
            height: r.height + (2 * reach - r.height) * p
            x: cx - width / 2
            y: cy - height / 2
            topLeftRadius: root.exitTopRadius + (stadium - root.exitTopRadius) * round
            topRightRadius: topLeftRadius
            bottomLeftRadius: root.exitBottomRadius + (stadium - root.exitBottomRadius) * round
            bottomRightRadius: bottomLeftRadius
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

    // At z: 50, but PowerRow and SessionPicker are at z: 60, allowing power actions
    // to be clicked directly without waking up or triggering the camera!

    MouseArea {
        id: sleepTapArea
        anchors.fill: parent
        z: root.awake ? -1 : 50
        cursorShape: root.awake ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: root.wakeUp()
    }


    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // Bottom left: the date and a very large time, lifted to make room for
    // the password when awake.
    Item {
        id: clockContainer

        x: root.marginX
        y: root.height - root.marginBottom - height - root.awakeP * (account.pillHeight + 22)
        opacity: root.mainFade
        visible: opacity > 0.01
        width: clockCol.implicitWidth
        height: clockCol.implicitHeight

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            shadowOpacity: 0.5
            shadowVerticalOffset: 3
            shadowColor: Theme.island
        }

        Column {
            id: clockCol

            Text {
                x: Math.round(root.timeSize * 0.035)
                text: Qt.formatDateTime(root.now, "dddd, d MMMM")
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(15, Math.round(root.height * 0.016))
                font.weight: Font.Medium
                font.letterSpacing: 0.3
                color: Theme.text
                opacity: 0.85 * root.part(0)
                transform: Translate { y: 14 * (1 - root.part(0)) }
            }

            Text {
                text: Qt.formatDateTime(root.now, "HH:mm")
                font.family: "Google Sans Display"
                font.pixelSize: root.timeSize
                font.weight: Font.Normal
                font.letterSpacing: -root.timeSize * 0.03
                font.features: { "tnum": 1 }
                color: Theme.text
                height: Math.round(root.timeSize * 0.92)
                verticalAlignment: Text.AlignVCenter
                opacity: root.part(1)
                transform: Translate { y: 24 * (1 - root.part(1)) }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.wakeUp()
        }
    }


    // Side screen: a greeting, pointing at where to log in.
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Math.round(root.height * 0.03)
        spacing: Math.round(root.height * 0.012)
        opacity: (root.role === "greeting" ? 1 : 0) * root.clockReveal
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 380 } }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const hour = root.now.getHours()
                return hour < 5 ? qsTr("Good night")
                    : hour < 12 ? qsTr("Good morning")
                    : hour < 18 ? qsTr("Good afternoon")
                    : qsTr("Good evening")
            }
            font.family: "Google Sans Display"
            font.pixelSize: Math.round(root.height * 0.085)
            color: Theme.text
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.loginOnLeft ? qsTr("←   log in on the left") : qsTr("log in on the right   →")
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(root.height * 0.02)
            color: Theme.text
            opacity: 0.55
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.12)
        opacity: root.sideHint ? 0.9 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 200 } }
        text: root.loginOnLeft ? qsTr("←   Click the login screen to type") : qsTr("Click the login screen to type   →")
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.height * 0.02)
        font.weight: Font.Medium
        color: Theme.text
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        visible: root.role === "greeting"
        text: sddm.hostName
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.text
        opacity: 0.35 * root.clockReveal
    }

    // Side screen: the day, as a calendar page, beside the month.
    Row {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Math.round(root.height * 0.02)
        spacing: Math.round(root.width * 0.07)
        opacity: (root.role === "date" ? 1 : 0) * root.clockReveal
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 380 } }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "dddd").toUpperCase()
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(root.height * 0.02)
                font.weight: Font.DemiBold
                font.letterSpacing: Math.round(root.height * 0.006)
                color: Theme.accent
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "d")
                font.family: "Google Sans Display"
                font.pixelSize: Math.round(root.height * 0.36)
                color: Theme.text
                height: Math.round(root.height * 0.36 * 0.95)
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "MMMM yyyy")
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(root.height * 0.024)
                color: Theme.text
                opacity: 0.6
            }
        }

        MonthGrid {
            anchors.verticalCenter: parent.verticalCenter
            today: root.now
            cell: Math.round(root.height * 0.055)
            fontFamily: Theme.fontFamily
            textColor: Theme.text
            accentColor: Theme.accent
            accentTextColor: Theme.accentText
        }
    }

    AccountPill {
        id: account

        // Under the clock, lined up with the date.
        x: root.marginX + Math.round(root.timeSize * 0.035) - 2
        y: root.height - root.marginBottom - account.pillHeight + 12 * (1 - root.pillReveal)
        opacity: root.pillReveal
        scale: 0.98 + 0.02 * root.pillReveal
        transformOrigin: Item.Left
        visible: opacity > 0
        // Sit above the black blob that floods out of it, then fade at the end
        z: root.exitFrom === "pill" && root.exitP > 0 ? 10000 : 10

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
        anchors.bottomMargin: 28
        opacity: root.awake ? 0 : 0.5 * root.clockReveal * root.mainFade
        visible: opacity > 0
        text: qsTr("Click anywhere or press any key to unlock")
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textMuted

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationFast }
        }
    }


    PowerRow {
        z: 60
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.top: parent.top
        anchors.topMargin: 18
        visible: root.role === "main"
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
        anchors.rightMargin: root.marginX
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.marginBottom
        visible: root.role === "main"
        opacity: (root.awake ? 1.0 : 0.6) * root.clockReveal
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

        sessions: sessionModel
        currentIndex: sessionModel.lastIndex
    }


    focus: true
    Component.onCompleted: {
        root.forceActiveFocus()
        root.readHelperToken()
    }
    Keys.onPressed: event => {
        if (root.role !== "main" && !screenHover.hovered) {
            root.sideHint = true
            sideHintTimer.restart()
            event.accepted = true
            return
        }
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
