import QtQuick
import Quickshell
import Quickshell.Widgets
import QtQuick.Effects

import "../theme"
import "../services"
import "../components"

// A side screen's part on the lock: the music, large, with its lyrics. With
// nothing playing, a calendar page instead (the day, big).
Item {
    id: root

    property real reveal: 1

    readonly property bool playing: MediaService.available && MediaService.title !== ""
    readonly property int cover: Math.round(Math.min(root.height * 0.36, root.width * 0.3))

    // Each piece rises in a little after the one before.
    function part(index: int): real {
        return Math.max(0, Math.min(1, (root.reveal - index * 0.12) / 0.64))
    }

    // Music, centred; lyrics arriving make it taller, so it glides up.
    Column {
        id: music
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round((root.height - music.height) / 2 - root.height * 0.02)
        Behavior on y { NumberAnimation { duration: Math.round(400 * Theme.motion); easing.type: Easing.OutCubic } }
        spacing: Math.round(root.height * 0.022)
        visible: root.playing
        opacity: root.playing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationMorph } }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.cover
            height: root.cover
            opacity: root.part(0)
            scale: 0.94 + 0.06 * root.part(0)

            ClippingRectangle {
                id: art
                anchors.fill: parent
                radius: Theme.radiusLarge
                color: Theme.islandSurface

                Image {
                    anchors.fill: parent
                    source: MediaService.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 640
                }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 1
                shadowOpacity: 0.6
                shadowVerticalOffset: 12
                shadowColor: "black"
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            opacity: root.part(1)
            transform: Translate { y: 14 * (1 - root.part(1)) }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, root.width * 0.5)
                    text: MediaService.title
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(root.height * 0.028)
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Spectrum {
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.round(root.height * 0.02)
                    barWidth: 4
                    barSpacing: 3
                    minimum: 3
                    active: MediaService.playing && root.visible
                    barColor: Theme.text
                    opacity: 0.8
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, root.width * 0.6)
                horizontalAlignment: Text.AlignHCenter
                text: MediaService.artist
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(root.height * 0.017)
                color: Theme.text
                opacity: 0.65
            }
        }

        LockLyrics {
            anchors.horizontalCenter: parent.horizontalCenter
            align: Qt.AlignHCenter
            screenHeight: root.height
            maxWidth: Math.round(root.width * 0.7)
            wanted: root.visible && root.playing
            // Takes no room until there are lyrics to show.
            visible: shown
            opacity: root.part(2)
            Behavior on opacity { NumberAnimation { duration: Theme.durationMedium } }
        }
    }

    // Nothing playing: the day, as a calendar page.
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Math.round(root.height * 0.04)
        visible: !root.playing
        spacing: 0

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd").toUpperCase()
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(root.height * 0.02)
            font.weight: Font.DemiBold
            font.letterSpacing: Math.round(root.height * 0.006)
            color: Theme.accent
            opacity: root.part(0)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "d")
            font.family: "Google Sans Display"
            font.pixelSize: Math.round(root.height * 0.36)
            font.weight: Font.Normal
            color: Theme.text
            height: Math.round(root.height * 0.36 * 0.95)
            verticalAlignment: Text.AlignVCenter
            opacity: root.part(1)
            transform: Translate { y: 24 * (1 - root.part(1)) }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "MMMM yyyy")
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(root.height * 0.024)
            color: Theme.text
            opacity: 0.6 * root.part(2)
        }
    }
}
