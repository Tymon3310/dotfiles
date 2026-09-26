// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A C C O U N T   P I L L                                                │
// │   morphing login capsule · face unlock & password authentication         │
// │                                                                          │
// │   matches impasto lockscreen aesthetics & animations                     │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "."

Item {
    id: root

    property var users: null
    property bool awake: false
    property int currentIndex: (users && users.lastIndex !== undefined && users.lastIndex >= 0) ? users.lastIndex : 0

    property bool authenticating: false
    property bool failed: false
    property string message: ""
    property bool capsLock: false

    property bool faceScanning: false
    property bool faceVerified: false
    property bool faceFailed: false

    property bool userPickerExpanded: false

    signal submitted(string password)
    signal faceRetryRequested()
    signal userChosen(int index)

    function claim(): void {
        field.forceActiveFocus()
    }

    function clear(): void {
        field.clear()
    }

    readonly property bool hasText: field.text !== ""

    function append(ch: string): void {
        field.text += ch
        field.forceActiveFocus()
    }

    // SDDM userModel adapter
    Instantiator {
        id: rows
        model: root.users
        delegate: QtObject {
            required property string name
            required property string realName
            required property url icon
        }
        onObjectAdded: (index, object) => {
            if (object && (object.name === "tymon" || object.name === "Tymon3310")) {
                root.currentIndex = index
            }
        }
    }

    readonly property bool many: rows.count > 1

    readonly property var current: rows.count > 0
        ? rows.objectAt(Math.max(0, Math.min(root.currentIndex, rows.count - 1)))
        : null

    readonly property string userName: root.current !== null ? root.current.name : ""
    readonly property string displayName: {
        if (root.current === null)
            return ""
        const real = root.current.realName
        return (real !== undefined && real !== "") ? real : root.current.name
    }
    readonly property string userIcon: root.current !== null ? String(root.current.icon) : ""

    function initialsOf(label: string): string {
        const words = String(label).trim().split(/\s+/).filter(w => w.length > 0)
        if (words.length === 0)
            return "?"
        if (words.length === 1)
            return words[0].charAt(0).toUpperCase()
        return (words[0].charAt(0) + words[words.length - 1].charAt(0)).toUpperCase()
    }

    readonly property bool typing: root.awake
        || field.text !== ""
        || field.activeFocus
        || (root.authenticating && !root.faceScanning)
        || root.failed

    readonly property int pillHeight: 56
    readonly property int face: 44
    readonly property int inset: 6
    readonly property int fieldWidth: 360

    implicitWidth: pill.width
    implicitHeight: root.pillHeight + 40

    // Shake animation on failed attempt
    SequentialAnimation {
        id: refusal

        loops: 2
        NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: -9; duration: 55; easing.type: Easing.OutCubic }
        NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: 9; duration: 55; easing.type: Easing.OutCubic }
        NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: 0; duration: 55; easing.type: Easing.OutCubic }
    }

    Connections {
        target: root
        function onFailedChanged(): void {
            if (root.failed)
                refusal.restart()
        }
    }

    Rectangle {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        readonly property real computedRestingWidth: root.inset + root.face + 14 + restingCol.implicitWidth + 24
        width: root.typing
            ? root.fieldWidth
            : Math.max(220, computedRestingWidth)
        height: root.pillHeight
        radius: Theme.radiusPill
        color: Theme.island
        border.width: 1
        border.color: {
            if (root.failed)
                return Theme.red
            return root.typing ? Theme.accent : Theme.islandBorder
        }

        Behavior on width {
            NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.durationFast }
        }

        // Subtle drop shadow backing
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: parent.radius + 2
            color: "#60000000"
            z: -1
        }

        // ── AVATAR ──────────────────────────────────────────────────────────
        Item {
            id: avatarHolder
            x: root.inset
            anchors.verticalCenter: parent.verticalCenter
            width: root.face
            height: root.face
            z: 2

            Avatar {
                id: picture
                anchors.fill: parent
                source: root.userIcon
                initials: root.initialsOf(root.displayName)
                ring: {
                    if (root.faceVerified)
                        return Theme.green
                    if (root.faceScanning)
                        return Theme.accent
                    if (root.faceFailed)
                        return Theme.red
                    return Theme.islandBorder
                }
            }

            // Scanning indicator ring around avatar
            RingIndicator {
                id: scannerRing
                anchors.centerIn: parent
                width: root.face + 8
                height: root.face + 8
                visible: root.faceScanning && !root.faceVerified
                thickness: 2
                progress: 0.28
                trackColor: "transparent"
                fillColor: Theme.accent

                RotationAnimator {
                    target: scannerRing
                    running: root.faceScanning && !root.faceVerified
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }

            // Badge checkmark if face verified
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 16
                height: 16
                radius: 8
                color: Theme.green
                visible: root.faceVerified
                scale: visible ? 1 : 0
                Behavior on scale {
                    NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack }
                }

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: Theme.accentText
                }
            }

            // Click avatar to trigger face unlock
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.userPickerExpanded = false
                    root.faceRetryRequested()
                }
            }
        }

        // ── RESTING STATE CONTAINER ─────────────────────────────────────────
        Item {
            id: restingArea
            anchors.left: avatarHolder.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            height: restingCol.implicitHeight
            opacity: root.typing ? 0 : 1
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }

            Column {
                id: restingCol
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Row {
                    spacing: 6

                    Text {
                        text: root.displayName
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.many
                        text: "󰅀"
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        color: Theme.text
                        opacity: 0.7
                        rotation: root.userPickerExpanded ? 180 : 0
                        Behavior on rotation {
                            NumberAnimation { duration: Theme.durationFast }
                        }
                    }
                }

                Text {
                    text: {
                        if (root.faceVerified)
                            return qsTr("Face recognized")
                        if (root.faceScanning)
                            return qsTr("Looking for you...")
                        if (root.faceFailed)
                            return qsTr("Face not recognized (click to retry)")
                        return qsTr("Click to scan face or enter password")
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: {
                        if (root.faceVerified)
                            return Theme.green
                        if (root.faceScanning)
                            return Theme.accent
                        if (root.faceFailed)
                            return Theme.red
                        return Theme.textMuted
                    }

                    Behavior on color {
                        ColorAnimation { duration: Theme.durationFast }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.many) {
                        root.userPickerExpanded = !root.userPickerExpanded
                    } else {
                        field.forceActiveFocus()
                    }
                }
            }
        }

        // ── TYPING STATE (PASSWORD INPUT) ───────────────────────────────────
        TextInput {
            id: field

            anchors.left: avatarHolder.right
            anchors.leftMargin: 16
            anchors.right: send.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            opacity: root.typing ? 1 : 0
            visible: opacity > 0

            echoMode: TextInput.Password
            passwordCharacter: "●"
            passwordMaskDelay: 0
            enabled: (!root.authenticating || root.faceScanning)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall + 2
            font.letterSpacing: 3
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentText
            clip: true

            Behavior on opacity {
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.faceScanning
                    ? qsTr("Enter password or use face...")
                    : (root.faceFailed ? qsTr("Face not recognized — enter password") : qsTr("Enter password..."))
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.letterSpacing: 0
                visible: field.text === "" && !root.authenticating
            }

            onAccepted: {
                if (field.text === "")
                    return
                root.submitted(field.text)
            }

            onTextChanged: {
                if (root.failed && field.text !== "")
                    root.failed = false
            }

            Keys.onEscapePressed: {
                field.clear()
                field.focus = false
                root.userPickerExpanded = false
            }
        }

        // ── SEND / SPINNER BUTTON ───────────────────────────────────────────
        Rectangle {
            id: send

            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: width / 2
            color: (root.authenticating && !root.faceScanning) ? "transparent"
                : (sendMouse.containsMouse ? Theme.accentHover : Theme.accent)
            opacity: root.typing ? 1 : 0
            scale: root.typing ? 1 : 0.6
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }
            Behavior on scale {
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }
            Behavior on color {
                ColorAnimation { duration: Theme.durationFast }
            }

            Text {
                anchors.centerIn: parent
                text: "󰁔"
                font.family: Theme.fontMono
                font.pixelSize: 18
                color: Theme.accentText
                visible: !(root.authenticating && !root.faceScanning)
            }

            RingSpinner {
                anchors.centerIn: parent
                visible: root.authenticating && !root.faceScanning
                running: visible
                fillColor: Theme.accent
            }

            MouseArea {
                id: sendMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !(root.authenticating && !root.faceScanning) && field.text !== ""
                onClicked: {
                    if (field.text !== "")
                        root.submitted(field.text)
                }
            }
        }
    }

    // ── STATUS / ERROR / CAPS LOCK ──────────────────────────────────────────
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: pill.bottom
        anchors.topMargin: 12
        text: root.capsLock ? qsTr("Caps Lock is on") : root.message
        visible: text !== ""
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        color: root.capsLock ? Theme.indicatorWarn : Theme.indicatorBad
    }

    // ── MULTI-USER POPUP SHEET ──────────────────────────────────────────────
    Capsule {
        id: sheet

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: pill.top
        anchors.bottomMargin: 14
        width: 320
        height: list.height + 16
        radius: Theme.radiusLarge
        visible: opacity > 0
        opacity: root.userPickerExpanded ? 1 : 0
        scale: root.userPickerExpanded ? 1 : 0.96
        transformOrigin: Item.Bottom

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }

        Column {
            id: list

            anchors.centerIn: parent
            width: parent.width - 16

            Repeater {
                model: root.users

                Rectangle {
                    required property int index
                    required property string name
                    required property string realName
                    required property url icon

                    width: list.width
                    height: 52
                    radius: Theme.radiusMedium
                    color: rowArea.containsMouse ? Theme.islandSurface : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: Theme.durationFast }
                    }

                    Avatar {
                        id: mark

                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 32
                        source: String(icon)
                        initials: root.initialsOf(realName !== "" ? realName : name)
                    }

                    Text {
                        anchors.left: mark.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 38
                        anchors.verticalCenter: parent.verticalCenter
                        text: (realName !== "" && realName !== undefined) ? realName : name
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: index === root.currentIndex ? Font.DemiBold : Font.Normal
                        color: Theme.text
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: index === root.currentIndex
                        text: "󰄬"
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                        color: Theme.accent
                    }

                    MouseArea {
                        id: rowArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentIndex = index
                            root.userPickerExpanded = false
                            root.userChosen(index)
                        }
                    }
                }
            }
        }
    }
}
