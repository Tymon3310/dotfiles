import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../../theme"
import "../../../services"
import "../../../components"
import ".."

// The dashboard's notification history, grouped by application, the most
// recently active group first. A group shows its newest notification; the
// rest unfold from its header.
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
                visible: NotificationService.count > 0
                implicitWidth: Math.max(18, count.implicitWidth + 10)
                implicitHeight: 17
                radius: height / 2
                color: Theme.islandSurfaceHover

                Text {
                    id: count
                    anchors.centerIn: parent
                    text: NotificationService.count
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.weight: Font.DemiBold
                    color: Theme.textMuted
                }
            }

            Item { Layout.fillWidth: true }

            IconButton {
                icon: NotificationService.doNotDisturb ? "󰂛" : "󰂚"
                iconSize: 13
                iconColor: NotificationService.doNotDisturb ? Theme.accent : Theme.textMuted
                implicitWidth: 24
                implicitHeight: 22
                onClicked: NotificationService.toggleDoNotDisturb()
            }

            Text {
                visible: NotificationService.count > 0
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
            visible: NotificationService.count === 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: NotificationService.doNotDisturb ? "Do not disturb is on" : "Nothing new"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: NotificationService.count > 0
            clip: true
            spacing: 10
            boundsBehavior: Flickable.StopAtBounds
            model: NotificationService.groups

            ScrollBar.vertical: ScrollBar {
                policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                width: 4
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Theme.islandBorder
                }
            }

            delegate: Column {
                id: group

                required property string group

                readonly property var keys: NotificationService.groupKeys[group.group] ?? []
                readonly property var newest: NotificationService.entry(group.keys[0] ?? -1)
                property bool expanded: false

                width: ListView.view.width - 8
                spacing: 4

                // Header: icon, app, how many, and the group's controls.
                Item {
                    width: parent.width
                    height: 20

                    HoverHandler { id: headerHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 2
                        spacing: 6

                        NotificationPicture {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            entry: group.newest ? Object.assign({}, group.newest, { picture: "", critical: false }) : null
                        }

                        Text {
                            text: group.newest?.appName ?? ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            font.weight: Font.DemiBold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.4
                            color: Theme.textMuted
                        }

                        Text {
                            visible: group.keys.length > 1
                            text: group.keys.length
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                            opacity: 0.6
                        }

                        Item { Layout.fillWidth: true }

                        IconButton {
                            visible: group.keys.length > 1
                            icon: group.expanded ? "󰅃" : "󰅀"
                            iconSize: 11
                            implicitWidth: 20
                            implicitHeight: 18
                            onClicked: group.expanded = !group.expanded
                        }

                        IconButton {
                            opacity: headerHover.hovered ? 1 : 0
                            icon: "󰅖"
                            iconSize: 10
                            implicitWidth: 20
                            implicitHeight: 18
                            onClicked: NotificationService.clearGroup(group.group)
                        }
                    }
                }

                Repeater {
                    model: group.expanded ? group.keys : group.keys.slice(0, 1)

                    NotificationCard {
                        required property int modelData
                        key: modelData
                        width: group.width
                        popup: false
                    }
                }
            }
        }
    }
}
