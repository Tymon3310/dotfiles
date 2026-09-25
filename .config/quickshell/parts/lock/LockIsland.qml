import QtQuick
import Quickshell

import "../theme"
import "../services"
import "../components"

// The island on the lock screen: top notch holding the padlock.
// Matches the exact resting dimensions and curvature of IslandBar.
Item {
    id: root

    property real held: 1

    readonly property int capsuleH: Theme.capsuleHeight
    readonly property int barTopMargin: Theme.barTopMargin
    readonly property int notchHeight: root.capsuleH + root.barTopMargin

    // Matches the IslandBar rest width exactly
    readonly property int notchWidth: restRow.implicitWidth + 28

    anchors.horizontalCenter: parent.horizontalCenter
    y: 0
    width: root.notchWidth
    height: root.notchHeight

    Behavior on width { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
    Behavior on height { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }

    SystemClock {
        id: clockTime
        precision: SystemClock.Minutes
    }

    // Fillets attaching notch to top screen edge
    NotchFillet {
        anchors.right: body.left
        anchors.top: parent.top
        mirrored: true
    }

    NotchFillet {
        anchors.left: body.right
        anchors.top: parent.top
    }

    Rectangle {
        id: body

        anchors.fill: parent
        color: Theme.island
        border.width: 0
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Theme.radiusLarge
        bottomRightRadius: Theme.radiusLarge

        // 1. Padlock in the notch while locked (with Biopass visual feedback)
        Padlock {
            id: padlock
            anchors.centerIn: parent
            scale: 0.9
            opened: LockService.leaving || LockService.biopassVerified
            tint: {
                if (LockService.biopassVerified)
                    return Theme.green
                if (LockService.biopassRunning)
                    return Theme.accent
                if (LockService.biopassFailed)
                    return Theme.red
                return Theme.text
            }
            opacity: root.held

            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
            Behavior on tint { ColorAnimation { duration: Theme.durationFast } }

            SequentialAnimation on scale {
                running: LockService.biopassRunning && !LockService.biopassVerified
                loops: Animation.Infinite
                NumberAnimation { to: 1.06; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.9; duration: 600; easing.type: Easing.InOutSine }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.held > 0.5
            onClicked: {
                LockService.rouse()
                LockService.triggerBiopass()
            }
        }

        // 2. Bar's resting content (media + clock) fading in upon unlock
        Item {
            anchors.top: parent.top
            anchors.topMargin: root.barTopMargin
            anchors.horizontalCenter: parent.horizontalCenter
            width: restRow.implicitWidth
            height: root.capsuleH
            opacity: 1 - root.held
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

            Row {
                id: restRow
                anchors.centerIn: parent
                spacing: 10

                // Media Album Art Thumbnail
                Item {
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: Theme.islandSurfaceHover
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: MediaService.artUrl
                            visible: source !== "" && status === Image.Ready
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !MediaService.available || MediaService.artUrl === ""
                            text: "󰝚"
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            color: Theme.accent
                        }
                    }
                }

                // Song Name
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: MediaService.available && (MediaService.title !== "")
                    width: visible ? Math.min(280, songText.implicitWidth) : 0
                    height: root.capsuleH
                    clip: true

                    Text {
                        id: songText
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        text: MediaService.artist !== ""
                            ? `${MediaService.title}  •  ${MediaService.artist}`
                            : MediaService.title
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.text
                        elide: Text.ElideRight
                    }
                }

                // Spectrum Visualizer
                Spectrum {
                    anchors.verticalCenter: parent.verticalCenter
                    barWidth: 2.5
                    barSpacing: 1.5
                    minimum: 2
                    height: 14
                    active: MediaService.playing
                    barColor: Theme.accent
                    visible: MediaService.available
                }

                // Clock Time
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: clockText.implicitWidth
                    height: root.capsuleH

                    Text {
                        id: clockText
                        anchors.centerIn: parent
                        text: Qt.formatDateTime(clockTime.date, SettingsService.clockFormat || "HH:mm")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall + 1
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: Theme.text
                    }
                }

                // Divider
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "|"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Light
                    color: Theme.textMuted
                    opacity: 0.25
                }

                // Date
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: dateText.implicitWidth
                    height: root.capsuleH

                    Text {
                        id: dateText
                        anchors.centerIn: parent
                        text: Qt.formatDateTime(clockTime.date, "dddd, d MMM")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall - 1
                        font.weight: Font.Medium
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}
