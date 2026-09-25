import QtQuick
import QtQuick.Effects

import "../theme"
import "../services"
import "../components"

Item {
    id: root

    signal submitted(string password)

    function claim(): void {
        field.forceActiveFocus()
    }

    function clear(): void {
        field.clear()
    }

    readonly property bool typing: field.text !== ""
        || LockService.authenticating
        || LockService.failed

    readonly property int pillHeight: 56
    readonly property int face: 44
    readonly property int inset: 6
    readonly property int fieldWidth: 360

    implicitWidth: holder.width
    implicitHeight: root.pillHeight + 40

    Item {
        id: holder

        anchors.horizontalCenter: parent.horizontalCenter
        width: pill.width
        height: pill.height

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            shadowOpacity: 0.5
            shadowVerticalOffset: 4
            shadowColor: Theme.island
        }

        SequentialAnimation {
            id: refusal

            loops: 2
            NumberAnimation { target: holder; property: "anchors.horizontalCenterOffset"; to: -9; duration: 55; easing.type: Easing.OutCubic }
            NumberAnimation { target: holder; property: "anchors.horizontalCenterOffset"; to: 9; duration: 55; easing.type: Easing.OutCubic }
            NumberAnimation { target: holder; property: "anchors.horizontalCenterOffset"; to: 0; duration: 55; easing.type: Easing.OutCubic }
        }

        Connections {
            target: LockService
            function onFailedChanged(): void {
                if (LockService.failed)
                    refusal.restart()
            }
        }

        Rectangle {
            id: pill

            width: root.typing
                ? root.fieldWidth
                : root.inset + root.face + 14 + resting.implicitWidth + 24
            height: root.pillHeight
            radius: Theme.radiusPill
            color: Theme.island
            border.width: 1
            border.color: {
                if (LockService.failed)
                    return Theme.red
                return root.typing ? Theme.accent : Theme.islandBorder
            }

            Behavior on width { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    LockService.rouse()
                    field.forceActiveFocus()
                }
            }

            Avatar {
                id: picture
                x: root.inset
                anchors.verticalCenter: parent.verticalCenter
                width: root.face
                height: root.face
                ring: {
                    if (LockService.biopassVerified)
                        return Theme.green
                    if (LockService.biopassRunning)
                        return Theme.accent
                    if (LockService.biopassFailed)
                        return Theme.red
                    return Theme.islandBorder
                }
            }

            // Scanning indicator ring around avatar
            RingIndicator {
                id: scannerRing
                anchors.centerIn: picture
                width: root.face + 8
                height: root.face + 8
                visible: LockService.biopassRunning && !LockService.biopassVerified
                thickness: 2
                progress: 0.28
                trackColor: "transparent"
                fillColor: Theme.accent

                RotationAnimator {
                    target: scannerRing
                    running: LockService.biopassRunning && !LockService.biopassVerified
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }

            // Badge checkmark if face verified
            Rectangle {
                anchors.right: picture.right
                anchors.bottom: picture.bottom
                width: 16
                height: 16
                radius: 8
                color: Theme.green
                visible: LockService.biopassVerified
                scale: visible ? 1 : 0
                Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: Theme.accentText
                }
            }

            // Click avatar to trigger face retry
            MouseArea {
                anchors.fill: picture
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    LockService.rouse()
                    LockService.triggerBiopass()
                }
            }

            // Resting state: Name & hint
            Column {
                id: resting

                anchors.left: picture.right
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                opacity: root.typing ? 0 : 1
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }

                Text {
                    text: AccountService.name
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Text {
                    text: {
                        if (LockService.biopassVerified)
                            return "Face recognized"
                        if (LockService.biopassRunning)
                            return "Looking for you..."
                        if (LockService.biopassFailed)
                            return "Face not recognized (click to retry)"
                        return "Enter your password"
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: {
                        if (LockService.biopassVerified)
                            return Theme.green
                        if (LockService.biopassRunning)
                            return Theme.accent
                        if (LockService.biopassFailed)
                            return Theme.red
                        return Theme.textMuted
                    }

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                }
            }

            // Typing state: Password field
            TextInput {
                id: field

                anchors.left: picture.right
                anchors.leftMargin: 16
                anchors.right: send.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                opacity: root.typing ? 1 : 0

                echoMode: TextInput.Password
                passwordCharacter: "●"
                passwordMaskDelay: 0
                enabled: !LockService.authenticating && !LockService.leaving
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall + 2
                font.letterSpacing: 3
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                clip: true

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }

                onAccepted: {
                    root.submitted(field.text)
                    field.clear()
                }

                onTextChanged: {
                    if (LockService.failed && field.text !== "")
                        LockService.failed = false
                }

                Keys.onEscapePressed: {
                    field.clear()
                    LockService.rest()
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Shift || event.key === Qt.Key_CapsLock || event.key === Qt.Key_Escape)
                        return
                    event.accepted = !LockService.awake
                    LockService.rouse()
                }
            }

            // Send Button & Spinner
            Rectangle {
                id: send

                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: width / 2
                color: LockService.authenticating ? "transparent"
                    : (press.containsMouse ? Theme.accentHover : Theme.accent)
                opacity: root.typing ? 1 : 0
                scale: root.typing ? 1 : 0.6
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing } }
                Behavior on scale { NumberAnimation { duration: Theme.durationMedium; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                Text {
                    anchors.centerIn: parent
                    visible: !LockService.authenticating
                    text: "󰁔"
                    font.family: Theme.fontMono
                    font.pixelSize: 18
                    color: Theme.accentText
                }

                RingIndicator {
                    id: spinner
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    visible: LockService.authenticating
                    thickness: 2
                    progress: 0.28
                    trackColor: "transparent"
                    fillColor: Theme.accent

                    RotationAnimator {
                        target: spinner
                        running: LockService.authenticating
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                    }
                }

                MouseArea {
                    id: press
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !LockService.authenticating
                    onClicked: {
                        root.submitted(field.text)
                        field.clear()
                    }
                }
            }
        }
    }

    // Error message below
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: holder.bottom
        anchors.topMargin: 12
        text: LockService.message
        visible: text !== ""
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        color: Theme.red
    }
}
