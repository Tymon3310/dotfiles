import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: card

    property var notification: null
    property var notificationData: null
    property bool delegateManaged: false
    property bool allowGroupToggle: false
    property bool groupExpanded: false
    property int groupedCount: 1
    property string customFont: "Google Sans Code NF"
    property string urgencyColor: "#0070D8"
    property string urgencyBorder: "#1AFFFFFF"
    property bool compact: false
    readonly property var effectiveNotification: card.notificationData ? card.notificationData : card.notification

    signal activateRequested(bool keepInHistory)
    signal dismissRequested()
    signal actionRequested(string identifier, bool keepInHistory)
    signal groupToggleRequested()

    height: cardRow.implicitHeight + 16
    clip: false

    // Entrance animation
    opacity: 0
    Component.onCompleted: {
        card.opacity = 0;
        opacityAnim.running = true;
    }
    NumberAnimation {
        id: opacityAnim
        target: card
        property: "opacity"
        to: 1
        duration: 220
        easing.type: Easing.OutCubic
    }

    function activateNotification(keepInHistory) {
        var keep = keepInHistory === true;
        if (card.delegateManaged) {
            card.activateRequested(keep);
            return;
        }

        if (!card.effectiveNotification) return;

        var actionsList = card.effectiveNotification.actions || [];
        var foundDefault = false;
        for (var i = 0; i < actionsList.length; i++) {
            var action = actionsList[i];
            if (action && action.identifier === "default" && action.invoke) {
                try {
                    action.invoke();
                    foundDefault = true;
                } catch (e) {
                    console.warn("[NotificationCard] Failed to invoke default action:", e);
                }
                break;
            }
        }

        if (!keep && !foundDefault && card.notification && card.notification.dismiss) {
            card.notification.dismiss();
        }
    }
 
    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | (card.allowGroupToggle ? Qt.RightButton : Qt.NoButton)
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton && card.allowGroupToggle && card.groupedCount > 1) {
                card.groupToggleRequested();
                return;
            }

            if (mouse.button === Qt.LeftButton) {
                card.activateNotification((mouse.modifiers & Qt.ShiftModifier) !== 0);
            }
        }
    }

    // Card background
    Rectangle {
        anchors.fill: parent
        color: card.compact ? "transparent" : "#E6000000" // Sleek dark glass for toasts, transparent for panel list items
        radius: 10
        border.color: card.compact ? "transparent" : card.urgencyBorder
        border.width: 1

        // Left urgency stripe
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 0
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: card.compact ? 6 : 4
            anchors.bottomMargin: card.compact ? 6 : 4
            width: 3
            radius: 2
            color: card.urgencyColor
        }
    }

    // Hover highlight
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: cardMouse.containsMouse ? "#0DFFFFFF" : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // Bottom separator for list view items (only in panel center)
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        height: 1
        color: "#14FFFFFF"
        visible: card.compact
    }

    // Main content layout: Icon on the left, details column on the right
    RowLayout {
        id: cardRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        anchors.leftMargin: 14
        spacing: 12

        // Left column: Square Icon/Image
        Item {
            id: iconContainer
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            Layout.alignment: Qt.AlignTop
            visible: hasIcon

            readonly property bool hasIcon: card.effectiveNotification && (
                (card.effectiveNotification.image && card.effectiveNotification.image !== "") ||
                (card.effectiveNotification.appIcon && card.effectiveNotification.appIcon !== "")
            )
            readonly property string iconSource: {
                if (!card.effectiveNotification) return "";
                if (card.effectiveNotification.image && card.effectiveNotification.image !== "") return card.effectiveNotification.image;
                if (card.effectiveNotification.appIcon && card.effectiveNotification.appIcon !== "") return "image://icon/" + card.effectiveNotification.appIcon;
                return "";
            }

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: "#1AFFFFFF"
                clip: true

                Image {
                    anchors.fill: parent
                    source: iconContainer.iconSource
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(38, 38)
                }
            }
        }

        // Right column: details (App header, Summary, Body, Progress, Actions)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 4

            // App name row + close button
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: card.effectiveNotification ? (card.effectiveNotification.appName || "System") : ""
                    font.family: card.customFont
                    font.pixelSize: 8
                    color: card.urgencyColor
                    Layout.alignment: Qt.AlignVCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Item { Layout.fillWidth: true }

                // Timestamp
                Text {
                    text: {
                        if (!card.effectiveNotification || !card.effectiveNotification.time) return "";
                        var now = new Date();
                        var t = card.effectiveNotification.time;
                        var diffMs = now - t;
                        var diffMin = Math.floor(diffMs / 60000);
                        if (diffMin < 1) return "now";
                        if (diffMin < 60) return diffMin + "m ago";
                        var diffH = Math.floor(diffMin / 60);
                        if (diffH < 24) return diffH + "h ago";
                        return Math.floor(diffH / 24) + "d ago";
                    }
                    font.family: card.customFont
                    font.pixelSize: 7
                    color: "#44FFFFFF"
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    visible: card.groupedCount > 1
                    text: card.groupExpanded ? ("[" + card.groupedCount + "] -") : ("[" + card.groupedCount + "] +")
                    font.family: card.customFont
                    font.pixelSize: 7
                    color: "#66FFFFFF"
                    Layout.alignment: Qt.AlignVCenter
                }

                // Close button
                Item {
                    width: 16; height: 16
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: "󰅖"
                        font.family: card.customFont
                        font.pixelSize: 9
                        color: closeBtnMouse.containsMouse ? "#FF4C4C" : "#33FFFFFF"
                        anchors.centerIn: parent
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    MouseArea {
                        id: closeBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (card.delegateManaged) {
                                card.dismissRequested();
                            } else if (card.notification && card.notification.dismiss) {
                                card.notification.dismiss();
                            }
                        }
                    }
                }
            }

            // Summary
            Text {
                text: card.effectiveNotification ? (card.effectiveNotification.summary || "") : ""
                font.family: card.customFont
                font.pixelSize: 10
                font.bold: true
                color: "#FFFFFF"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                visible: text !== ""
            }

            // Body
            Text {
                text: card.effectiveNotification ? (card.effectiveNotification.body || "") : ""
                font.family: card.customFont
                font.pixelSize: 9
                color: "#99FFFFFF"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                maximumLineCount: card.compact ? 3 : 8
                elide: Text.ElideRight
                visible: text !== ""
                textFormat: Text.StyledText
            }

            // Progress bar (from hints["value"])
            Rectangle {
                Layout.fillWidth: true
                height: 3
                radius: 2
                color: "#1AFFFFFF"
                visible: {
                    if (!card.effectiveNotification || !card.effectiveNotification.hints) return false;
                    var v = card.effectiveNotification.hints["value"];
                    return v !== undefined && v !== null;
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: 2
                    color: card.urgencyColor
                    width: {
                        if (!card.effectiveNotification || !card.effectiveNotification.hints) return 0;
                        var v = card.effectiveNotification.hints["value"];
                        if (v === undefined || v === null) return 0;
                        return Math.max(0, Math.min(1, v / 100.0)) * parent.width;
                    }
                    Behavior on width { NumberAnimation { duration: 150 } }
                }
            }

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: card.effectiveNotification && card.effectiveNotification.actions && card.effectiveNotification.actions.length > 0

                Repeater {
                    model: card.effectiveNotification ? card.effectiveNotification.actions : null

                    delegate: Item {
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: actionBtn.implicitWidth + 16
                        Layout.maximumWidth: 120

                        Rectangle {
                            anchors.fill: parent
                            radius: 5
                            color: actionMouse.containsMouse ? "#1A0070D8" : "#0DFFFFFF"
                            border.color: actionMouse.containsMouse ? "#0070D8" : "#1AFFFFFF"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                        }

                        Text {
                            id: actionBtn
                            anchors.centerIn: parent
                            text: modelData.text || modelData.identifier
                            font.family: card.customFont
                            font.pixelSize: 8
                            color: actionMouse.containsMouse ? "#0070D8" : "#CCFFFFFF"
                            elide: Text.ElideRight
                            width: parent.width - 16
                            horizontalAlignment: Text.AlignHCenter
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                var keep = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                                if (card.delegateManaged) {
                                    card.actionRequested(modelData.identifier, keep);
                                } else {
                                    if (modelData.invoke) modelData.invoke();
                                    if (!keep && card.notification && card.notification.dismiss) {
                                        card.notification.dismiss();
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

}
