import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root
    implicitWidth: previewRow.implicitWidth
    implicitHeight: previewRow.implicitHeight

    property var notifHistory: null
    property bool panelOpen: false

    readonly property string customFont: "Google Sans Code NF"
    readonly property var latestNotification: {
        if (!root.notifHistory || root.notifHistory.groups.count === 0) return null;
        var firstGroup = root.notifHistory.groups.get(0);
        if (!firstGroup || !firstGroup.entries || firstGroup.entries.length === 0) return null;
        return firstGroup.entries[0];
    }

    function urgencyColor(urgency) {
        if (urgency === NotificationUrgency.Critical) return "#FF4C4C";
        if (urgency === NotificationUrgency.Low)      return "#66FFFFFF";
        return "#0070D8";
    }

    visible: root.latestNotification !== null

    RowLayout {
        id: previewRow
        anchors.fill: parent
        spacing: 10

        // Icon from latest notification
        Item {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            visible: latestNotification && (latestNotification.image || latestNotification.appIcon)

            Rectangle {
                anchors.fill: parent
                radius: 5
                color: "#1AFFFFFF"
                clip: true

                Image {
                    anchors.fill: parent
                    source: {
                        if (!root.latestNotification) return "";
                        if (root.latestNotification.image && root.latestNotification.image !== "") {
                            return root.latestNotification.image;
                        }
                        if (root.latestNotification.appIcon && root.latestNotification.appIcon !== "") {
                            return "image://icon/" + root.latestNotification.appIcon;
                        }
                        return "";
                    }
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(32, 32)
                }
            }
        }

        // Notification details column
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                text: root.latestNotification ? (root.latestNotification.appName || "System") : ""
                font.family: root.customFont
                font.pixelSize: 8
                font.bold: true
                color: root.latestNotification ? root.urgencyColor(root.latestNotification.urgency) : "#0070D8"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: root.latestNotification ? (root.latestNotification.summary || "") : ""
                font.family: root.customFont
                font.pixelSize: 9
                font.bold: true
                color: "#FFFFFF"
                Layout.fillWidth: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                text: root.latestNotification ? (root.latestNotification.body || "") : ""
                font.family: root.customFont
                font.pixelSize: 8
                color: "#99FFFFFF"
                Layout.fillWidth: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // Unread count badge
        Item {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter
            visible: root.notifHistory && root.notifHistory.totalCount > 1

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "#FF4C4C"

                Text {
                    anchors.centerIn: parent
                    text: root.notifHistory ? Math.min(root.notifHistory.totalCount, 99) : "0"
                    font.family: root.customFont
                    font.pixelSize: 10
                    font.bold: true
                    color: "#FFFFFF"
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.panelOpen = !root.panelOpen;
        }
    }

    // Hover highlight
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: parent.MouseArea !== undefined && parent.children[1].containsMouse ? "#0DFFFFFF" : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }
}
