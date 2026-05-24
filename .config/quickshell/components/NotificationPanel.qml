import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root
    implicitHeight: 450

    property var parentWindow: null
    property var notifServer: null
    property var notifHistory: null
    property bool hovered: panelHoverHandler.hovered
    property bool dnd: false

    readonly property string customFont: "Google Sans Code NF"

    // Expose notification count to Bar.qml for bell badge
    readonly property int unreadCount: notifHistory ? notifHistory.totalCount : 0

    HoverHandler {
        id: panelHoverHandler
    }

    // ── Helper: urgency colour ───────────────────────────────────────────────
    function urgencyColor(urgency) {
        if (urgency === NotificationUrgency.Critical) return "#FF4C4C";
        if (urgency === NotificationUrgency.Low)      return "#66FFFFFF";
        return "#0070D8";
    }
    function urgencyBorder(urgency) {
        if (urgency === NotificationUrgency.Critical) return "#FF4C4C";
        return "#1AFFFFFF";
    }

    // ── Panel chrome ─────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // ── Header row ───────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "NOTIFICATIONS"
                font.family: root.customFont
                font.pixelSize: 9
                font.bold: true
                color: "#0070D8"
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            // DND toggle
            Item {
                width: 20; height: 20
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: root.dnd ? "󰂛" : "󰂚"
                    font.family: root.customFont
                    font.pixelSize: 13
                    color: root.dnd ? "#FF4C4C" : "#66FFFFFF"
                    anchors.centerIn: parent
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dnd = !root.dnd
                }
            }

            // Clear all
            Item {
                width: 20; height: 20
                Layout.alignment: Qt.AlignVCenter
                visible: root.notifHistory && root.notifHistory.totalCount > 0

                Text {
                    text: "󰆴"
                    font.family: root.customFont
                    font.pixelSize: 13
                    color: clearMouse.containsMouse ? "#FF4C4C" : "#66FFFFFF"
                    anchors.centerIn: parent
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.notifHistory) root.notifHistory.clearAll();
                    }
                }
            }
        }

        // ── Divider ──────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#14FFFFFF"
        }

        // ── Empty state ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.notifHistory || root.notifHistory.totalCount === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "󰂚"
                    font.family: root.customFont
                    font.pixelSize: 28
                    color: "#22FFFFFF"
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "No notifications"
                    font.family: root.customFont
                    font.pixelSize: 10
                    color: "#33FFFFFF"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // ── Notification list ─────────────────────────────────────────────────
        ListView {
            id: notifList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.notifHistory && root.notifHistory.groups.count > 0
            model: root.notifHistory ? root.notifHistory.groups : null
            spacing: 6
            clip: true

            displaced: Transition {
                NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic }
            }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 250; easing.type: Easing.OutQuad }
                    NumberAnimation { property: "x"; to: notifList.width; duration: 250; easing.type: Easing.InQuad }
                    NumberAnimation { property: "height"; to: 0; duration: 250; easing.type: Easing.OutQuad }
                }
            }

            delegate: Column {
                id: groupColumn
                width: notifList.width
                spacing: 4

                property int groupIndex: index
                property string groupKey: model.groupKey
                property bool expandedState: model.expanded === true
                property var entries: {
                    if (!groupKey || !root.notifHistory) return [];
                    return root.notifHistory.notificationsData[groupKey] || [];
                }
                property var latestEntry: entries.length > 0 ? entries[0] : null
                property int entryCount: entries.length

                visible: latestEntry !== null

                NotificationCard {
                    width: parent.width
                    notificationData: groupColumn.latestEntry
                    delegateManaged: true
                    allowGroupToggle: groupColumn.entryCount > 1
                    groupExpanded: groupColumn.expandedState
                    groupedCount: groupColumn.entryCount
                    customFont: root.customFont
                    urgencyColor: root.urgencyColor(groupColumn.latestEntry ? groupColumn.latestEntry.urgency : NotificationUrgency.Normal)
                    urgencyBorder: root.urgencyBorder(groupColumn.latestEntry ? groupColumn.latestEntry.urgency : NotificationUrgency.Normal)
                    compact: true

                    onActivateRequested: (keepInHistory) => {
                        root.notifHistory.activateEntry(groupColumn.groupIndex, 0, keepInHistory);
                    }
                    onDismissRequested: {
                        root.notifHistory.removeEntry(groupColumn.groupIndex, 0, true);
                    }
                    onActionRequested: (identifier, keepInHistory) => {
                        root.notifHistory.invokeEntryAction(groupColumn.groupIndex, 0, identifier, keepInHistory);
                    }
                    onGroupToggleRequested: {
                        if (groupColumn.entryCount > 1) {
                            root.notifHistory.toggleExpanded(groupColumn.groupIndex);
                        }
                    }
                }

                // Expanded entries
                Column {
                    width: parent.width
                    spacing: 4
                    visible: groupColumn.expandedState && groupColumn.entryCount > 1

                    Repeater {
                        model: {
                            var result = [];
                            for (var i = 1; i < groupColumn.entries.length; i++) {
                                result.push(groupColumn.entries[i]);
                            }
                            return result;
                        }

                        delegate: Item {
                            width: groupColumn.width
                            height: nestedCard.height

                            NotificationCard {
                                id: nestedCard
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 14
                                notificationData: modelData
                                delegateManaged: true
                                customFont: root.customFont
                                urgencyColor: root.urgencyColor(modelData.urgency)
                                urgencyBorder: root.urgencyBorder(modelData.urgency)
                                compact: true

                                onActivateRequested: (keepInHistory) => {
                                    root.notifHistory.activateEntry(groupColumn.groupIndex, index + 1, keepInHistory);
                                }
                                onDismissRequested: {
                                    root.notifHistory.removeEntry(groupColumn.groupIndex, index + 1, true);
                                }
                                onActionRequested: (identifier, keepInHistory) => {
                                    root.notifHistory.invokeEntryAction(groupColumn.groupIndex, index + 1, identifier, keepInHistory);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
