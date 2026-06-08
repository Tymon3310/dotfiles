import QtQuick
import QtQuick.Controls

Item {
    id: history
    visible: false

    property var notifServer: null
    property alias groups: groupModel
    property int totalCount: 0
    property int nextEntryUid: 1

    // Plain JavaScript object to hold notification data
    property var notificationsData: ({})

    ListModel {
        id: groupModel
    }

    function groupKeyFor(notification) {
        var source = notification.desktopEntry || notification.appName || "unknown";
        var summary = notification.summary || "";
        return source + "::" + summary;
    }

    function cloneHints(hints) {
        var copy = {};
        if (!hints) return copy;
        for (var key in hints) {
            copy[key] = hints[key];
        }
        return copy;
    }

    function cloneActions(actions) {
        var result = [];
        if (!actions) return result;
        for (var i = 0; i < actions.length; i++) {
            var action = actions[i];
            if (!action) continue;
            result.push({
                identifier: action.identifier || "",
                text: action.text || action.identifier || ""
            });
        }
        return result;
    }

    function createEntry(notification) {
        var entry = {
            uid: history.nextEntryUid++,
            liveId: notification.id,
            liveNotification: notification,
            groupKey: groupKeyFor(notification),
            appName: notification.appName || "System",
            appIcon: notification.appIcon || "",
            summary: notification.summary || "",
            body: notification.body || "",
            urgency: notification.urgency,
            image: notification.image || "",
            hints: cloneHints(notification.hints),
            actions: cloneActions(notification.actions),
            desktopEntry: notification.desktopEntry || "",
            time: new Date(),
            resident: notification.resident,
            transient: notification.transient
        };

        // Clear QObject reference when closed to prevent segfaults
        notification.closed.connect(function() {
            entry.liveNotification = null;
        });

        return entry;
    }

    function syncCounts() {
        var total = 0;
        for (var i = 0; i < groupModel.count; i++) {
            var groupKey = groupModel.get(i).groupKey;
            if (notificationsData[groupKey]) {
                total += notificationsData[groupKey].length;
            }
        }
        history.totalCount = total;
    }

    function findGroupIndex(groupKey) {
        for (var i = 0; i < groupModel.count; i++) {
            if (groupModel.get(i).groupKey === groupKey) {
                return i;
            }
        }
        return -1;
    }

    function hasNotificationId(id) {
        for (var groupKey in notificationsData) {
            var list = notificationsData[groupKey];
            if (list) {
                for (var i = 0; i < list.length; i++) {
                    if (list[i] && list[i].liveId === id) return true;
                }
            }
        }
        return false;
    }

    function addNotification(notification) {
        if (!notification) return;
        if (hasNotificationId(notification.id)) return;

        var entry = createEntry(notification);
        var groupIndex = findGroupIndex(entry.groupKey);

        if (groupIndex >= 0) {
            // Group exists: prepend entry to the group and move group to front
            var nextEntries = [entry];
            if (notificationsData[entry.groupKey]) {
                for (var i = 0; i < notificationsData[entry.groupKey].length; i++) {
                    nextEntries.push(notificationsData[entry.groupKey][i]);
                }
            }
            notificationsData[entry.groupKey] = nextEntries;
            
            var wasExpanded = groupModel.get(groupIndex).expanded === true;
            
            // Remove and re-insert at front
            groupModel.remove(groupIndex);
            groupModel.insert(0, {
                groupKey: entry.groupKey,
                expanded: wasExpanded
            });
        } else {
            // New group: insert at the front
            notificationsData[entry.groupKey] = [entry];
            groupModel.insert(0, {
                groupKey: entry.groupKey,
                expanded: false
            });
        }

        syncCounts();
    }

    function toggleExpanded(groupIndex) {
        if (groupIndex < 0 || groupIndex >= groupModel.count) return;
        var group = groupModel.get(groupIndex);
        groupModel.set(groupIndex, {
            groupKey: group.groupKey,
            expanded: !group.expanded
        });
    }

    function removeEntry(groupIndex, entryIndex, dismissLive) {
        if (groupIndex < 0 || groupIndex >= groupModel.count) return;

        var group = groupModel.get(groupIndex);
        var groupKey = group.groupKey;
        if (!notificationsData[groupKey]) return;
        if (entryIndex < 0 || entryIndex >= notificationsData[groupKey].length) return;

        var entry = notificationsData[groupKey][entryIndex];
        if (dismissLive !== false && entry && entry.liveNotification) {
            try {
                entry.liveNotification.dismiss();
            } catch (e) {
                console.warn("[NotificationHistory] dismiss failed:", e);
            }
        }

        var nextEntries = [];
        for (var i = 0; i < notificationsData[groupKey].length; i++) {
            if (i !== entryIndex) {
                nextEntries.push(notificationsData[groupKey][i]);
            }
        }

        if (nextEntries.length === 0) {
            groupModel.remove(groupIndex);
            delete notificationsData[groupKey];
        } else {
            notificationsData[groupKey] = nextEntries;
        }

        syncCounts();
    }

    function invokeEntryAction(groupIndex, entryIndex, actionIdentifier, keepInHistory) {
        if (groupIndex < 0 || groupIndex >= groupModel.count) return;
        var group = groupModel.get(groupIndex);
        var groupKey = group.groupKey;
        if (!notificationsData[groupKey]) return;
        if (entryIndex < 0 || entryIndex >= notificationsData[groupKey].length) return;

        var entry = notificationsData[groupKey][entryIndex];
        var invoked = false;

        if (entry.liveNotification) {
            var liveActions = entry.liveNotification.actions || [];
            for (var i = 0; i < liveActions.length; i++) {
                var action = liveActions[i];
                if (action && action.identifier === actionIdentifier) {
                    try {
                        action.invoke();
                        invoked = true;
                    } catch (e) {
                        console.warn("[NotificationHistory] action invoke failed:", e);
                    }
                    break;
                }
            }
        }

        if (!keepInHistory && !invoked && actionIdentifier === "default" && entry.liveNotification) {
            try {
                entry.liveNotification.dismiss();
            } catch (e2) {
                console.warn("[NotificationHistory] default fallback dismiss failed:", e2);
            }
        }

        if (!keepInHistory) {
            removeEntry(groupIndex, entryIndex, false);
        }
    }

    function activateEntry(groupIndex, entryIndex, keepInHistory) {
        if (groupIndex < 0 || groupIndex >= groupModel.count) return;
        var group = groupModel.get(groupIndex);
        var groupKey = group.groupKey;
        if (!notificationsData[groupKey]) return;
        if (entryIndex < 0 || entryIndex >= notificationsData[groupKey].length) return;

        var entry = notificationsData[groupKey][entryIndex];
        var actions = entry.actions || [];
        for (var i = 0; i < actions.length; i++) {
            if (actions[i] && actions[i].identifier === "default") {
                invokeEntryAction(groupIndex, entryIndex, "default", keepInHistory);
                return;
            }
        }

        if (!keepInHistory) {
            removeEntry(groupIndex, entryIndex, true);
        }
    }

    function clearAll() {
        for (var i = 0; i < groupModel.count; i++) {
            var group = groupModel.get(i);
            var groupKey = group.groupKey;
            if (notificationsData[groupKey]) {
                for (var j = 0; j < notificationsData[groupKey].length; j++) {
                    var entry = notificationsData[groupKey][j];
                    if (!entry.liveNotification) continue;
                    try {
                        entry.liveNotification.dismiss();
                    } catch (e) {
                        console.warn("[NotificationHistory] clearAll dismiss failed:", e);
                    }
                }
            }
        }

        groupModel.clear();
        notificationsData = {};
        syncCounts();
    }

    Connections {
        target: history.notifServer

        function onNotification(notification) {
            history.addNotification(notification);
        }
    }

    onNotifServerChanged: {
        if (notifServer) {
            // Populate history with any pre-existing tracked notifications (e.g. after config reload)
            for (var i = 0; i < notifServer.trackedNotifications.count; i++) {
                var notif = notifServer.trackedNotifications.get(i);
                if (notif) {
                    history.addNotification(notif);
                }
            }
        }
    }
}
