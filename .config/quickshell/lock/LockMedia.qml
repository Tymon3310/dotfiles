import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import "../theme"
import "../services"
import "../components"

// Now playing, for the lock screen's corner: cover, track and controls.
Item {
    id: root

    property int screenHeight: 1080

    readonly property int art: Math.max(72, Math.round(root.screenHeight * 0.068))
    readonly property bool shown: MediaService.available && MediaService.title !== ""

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row

        spacing: 16

        ClippingRectangle {
            Layout.preferredWidth: root.art
            Layout.preferredHeight: root.art
            radius: Theme.radiusMedium
            color: Theme.islandSurface

            Image {
                anchors.fill: parent
                source: MediaService.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 256
            }
        }

        ColumnLayout {
            spacing: 2

            RowLayout {
                spacing: 10

                Text {
                    Layout.maximumWidth: 320
                    text: MediaService.title
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(16, Math.round(root.screenHeight * 0.0135))
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Spectrum {
                    Layout.alignment: Qt.AlignVCenter
                    height: 16
                    barWidth: 3
                    barSpacing: 2
                    minimum: 2
                    active: MediaService.playing && root.visible
                    barColor: Theme.text
                    opacity: 0.8
                }
            }

            Text {
                Layout.maximumWidth: 320
                text: MediaService.artist
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(13, Math.round(root.screenHeight * 0.011))
                color: Theme.text
                opacity: 0.65
            }

            Row {
                Layout.topMargin: 6
                spacing: 4

                Repeater {
                    model: [
                        { glyph: "󰒮", enabled: MediaService.canPrevious, run: () => MediaService.previous() },
                        { glyph: MediaService.playing ? "󰏤" : "󰐊", enabled: MediaService.canToggle, run: () => MediaService.toggle() },
                        { glyph: "󰒭", enabled: MediaService.canNext, run: () => MediaService.next() }
                    ]

                    Rectangle {
                        required property var modelData

                        width: 30
                        height: 30
                        radius: 15
                        color: mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        opacity: modelData.enabled ? 1 : 0.35

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.glyph
                            font.family: Theme.fontMono
                            font.pixelSize: 16
                            color: Theme.text
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: modelData.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.run()
                        }
                    }
                }
            }
        }
    }
}
