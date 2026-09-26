// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T I F I C A T I O N   L I S T                                      │
// │   notification history                                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets

import Quickshell.Services.Notifications

import "../../../theme"
import "../../../services"
import "../../../components"

// Notification history kept by the shell's notification server.
Card {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Notifications"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Rectangle {
                visible: NotificationService.history.length > 0
                implicitWidth: Math.max(18, count.implicitWidth + 10)
                implicitHeight: 17
                radius: height / 2
                color: Theme.islandSurfaceHover

                Text {
                    id: count
                    anchors.centerIn: parent
                    text: NotificationService.history.length
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.weight: Font.DemiBold
                    color: Theme.textMuted
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: NotificationService.history.length > 0
                text: "Clear"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: clearMouse.containsMouse ? Theme.accent : Theme.textMuted

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.clearHistory()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: NotificationService.history.length === 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "Nothing new"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }

        // Scrolls; every entry is as tall as its text, nothing elided. The
        // service keeps the newest 50 and drops the oldest.
        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: NotificationService.history.length > 0
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: NotificationService.history

            ScrollBar.vertical: ScrollBar {
                policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                width: 4
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Theme.islandBorder
                }
            }

            // For "2 min ago"; refreshed each minute.
            property real now: Date.now()

            Timer {
                interval: 60000
                running: list.visible
                repeat: true
                onTriggered: list.now = Date.now()
            }

            delegate: Rectangle {
                id: entry

                required property var modelData

                readonly property bool critical:
                    entry.modelData.urgency === NotificationUrgency.Critical

                // Clear of the scroll bar.
                width: ListView.view.width - 8
                height: row.implicitHeight + 16
                radius: Theme.radiusSmall
                color: (entryMouse.containsMouse || entryHover.hovered) ? Theme.islandSurfaceHover : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                MouseArea {
                    id: entryMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: NotificationService.activate(entry.modelData)
                }

                RowLayout {
                    id: row

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    anchors.leftMargin: 9
                    anchors.rightMargin: 6
                    spacing: 9

                    NotificationPicture {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignTop
                        notification: entry.modelData
                        critical: entry.critical
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.summary
                            wrapMode: Text.Wrap
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: entry.modelData.body ?? ""
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                            linkColor: Theme.accent
                            onLinkActivated: link => {
                                Qt.openUrlExternally(link)
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                const minutes = Math.floor((list.now - (entry.modelData.time ?? list.now)) / 60000)
                                const age = minutes < 1 ? "now"
                                    : minutes < 60 ? `${minutes} min ago`
                                    : `${Math.floor(minutes / 60)} h ago`
                                return `${entry.modelData.appName} · ${age}`
                            }
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            color: Theme.textMuted
                            opacity: 0.7
                        }
                    }

                    IconButton {
                        Layout.alignment: Qt.AlignTop
                        z: 2
                        opacity: (entryMouse.containsMouse || entryHover.hovered) ? 1 : 0
                        icon: "󰅖"
                        iconSize: 11
                        onClicked: NotificationService.remove(entry.modelData)
                    }
                }

                HoverHandler {
                    id: entryHover
                }
            }
        }
    }
}
