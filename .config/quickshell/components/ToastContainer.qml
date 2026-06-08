import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

PanelWindow {
    id: toastWindow

    property var notifServer: null
    property bool notifDnd: false
    property bool panelOpen: false
    property bool isStartup: true

    Timer {
        id: startupTimer
        interval: 500
        running: true
        repeat: false
        onTriggered: {
            toastWindow.isStartup = false;
        }
    }

    readonly property string customFont: "Google Sans Code NF"

    // Align to top-right below the bar
    anchors {
        top: true
        right: true
    }

    margins {
        top: 12 // Placed safely below the bar height (handled by compositor exclusiveZone) + 4px gap
        right: 80 // Aligned with the bar's right margin
    }

    implicitWidth: 300
    implicitHeight: toastList.contentHeight
    color: "transparent"

    // Mask window inputs dynamically so empty areas are completely click-through
    mask: Region {
        item: (toastList.contentHeight > 0 && !toastWindow.panelOpen) ? toastList : null
    }

    ListModel {
        id: toastModel
    }

    // Helper to remove a toast from the ListModel
    function removeToast(id) {
        for (var i = 0; i < toastModel.count; i++) {
            if (toastModel.get(i).notifId === id) {
                toastModel.remove(i);
                break;
            }
        }
    }

    // Dismiss all active toasts when any dropdown panel is opened
    onPanelOpenChanged: {
        if (panelOpen) {
            toastModel.clear();
        }
    }

    // Monitor incoming notifications
    Connections {
        target: toastWindow.notifServer

        function onNotification(notification) {
            // Ignore if DND is enabled, a dropdown panel is open, or during startup/reload
            if (toastWindow.isStartup || toastWindow.notifDnd || toastWindow.panelOpen) return;

            // Check if already in toastModel
            var exists = false;
            for (var i = 0; i < toastModel.count; i++) {
                if (toastModel.get(i).notifId === notification.id) {
                    exists = true;
                    break;
                }
            }

            if (!exists) {
                // Add to transient popups list
                toastModel.append({
                    "notifObject": notification,
                    "notifId": notification.id
                });
            }
        }
    }

    // Clean up from popups list if notification is closed from elsewhere (e.g. D-Bus client or history panel)
    Connections {
        target: toastWindow.notifServer ? toastWindow.notifServer.trackedNotifications : null

        function onObjectRemovedPost(object) {
            toastWindow.removeToast(object.id);
        }
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

    ListView {
        id: toastList
        width: parent.width
        height: contentHeight
        model: toastModel
        spacing: 6
        interactive: false
        clip: false

        displaced: Transition {
            NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic }
        }

        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 250; easing.type: Easing.OutQuad }
                NumberAnimation { property: "x"; to: toastList.width; duration: 250; easing.type: Easing.InQuad }
                NumberAnimation { property: "height"; to: 0; duration: 250; easing.type: Easing.OutQuad }
            }
        }

        delegate: Item {
            id: delegateItem
            width: toastList.width
            height: card.height
            clip: true

            // Cache values locally so they remain valid during the remove transition animation
            property var notifObj: model.notifObject
            property int notifId: model.notifId

            Timer {
                id: dismissTimer
                interval: (delegateItem.notifObj && delegateItem.notifObj.expireTimeout > 0) ? delegateItem.notifObj.expireTimeout : 5000
                running: true
                repeat: false
                onTriggered: {
                    toastWindow.removeToast(delegateItem.notifId);
                }
            }

            NotificationCard {
                id: card
                width: parent.width
                notification: delegateItem.notifObj
                customFont: toastWindow.customFont
                urgencyColor: delegateItem.notifObj ? toastWindow.urgencyColor(delegateItem.notifObj.urgency) : "#0070D8"
                urgencyBorder: delegateItem.notifObj ? toastWindow.urgencyBorder(delegateItem.notifObj.urgency) : "#1AFFFFFF"
                compact: false

                y: -height
                Component.onCompleted: {
                    slideAnim.running = true;
                }
                NumberAnimation on y {
                    id: slideAnim
                    to: 0
                    duration: 350
                    easing.type: Easing.OutBack
                }
            }
        }
    }
}
