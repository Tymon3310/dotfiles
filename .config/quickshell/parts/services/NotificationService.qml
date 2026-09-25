// ╭────────────────────────────────────────────────────────────────────────────╮
// │                                                                            │
// │   N O T I F I C A T I O N   S E R V I C E                                │
// │   the shell is the notification daemon                                   │
// │                                                                            │
// │   github.com/andreumassanet/impasto                                        │
// │                                                                            │
// ╰────────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Owns org.freedesktop.Notifications. If another daemon holds the name, the
// server stays unregistered and takes over by itself once it is released.
//
// Only capabilities the island actually renders are declared; claiming more
// makes applications send content that gets dropped.
Singleton {
    id: root

    signal arrived(var notification)

    // For notifications that do not set their own timeout.
    readonly property int defaultTimeout: SettingsService.notificationTimeout

    // `current` and `history` hold plain copies, never the Notification
    // objects: the server deletes an object as soon as its application closes
    // or replaces it, and a list still built from the deleted object crashes
    // Quickshell (a segfault while creating the row). `live` is the one handle
    // kept, to tell the application when the user closes it; it is dropped
    // when the object goes away.
    property var current: null
    property var history: []
    readonly property int historyLimit: 50

    property var live: null
    property int serial: 0

    // ── PICTURE AND ICON ───────────────────────────────────────────────
    //
    // Quickshell folds `notify-send -i NAME` into `image` as
    // "image://icon/NAME", so an icon name and a real picture (an avatar, a
    // screenshot) arrive in the same field. They are told apart here:
    //
    //   picture   a real image: image data, a file, an image-path hint
    //   icon      the application's icon: the name it sent if the theme has
    //             it, else its desktop entry's, found by id or by app name
    //
    // Either may be empty; NotificationPicture shows what loads.

    function isThemeIcon(url: string): bool {
        // "image://icon/name", not "image://icon//some/file.png".
        return url.startsWith("image://icon/") && !url.startsWith("image://icon//")
    }

    // `-i /usr/share/icons/.../app.png`: a file, but an application icon.
    function isIconFile(url: string): bool {
        return url.startsWith("image://icon//") && /\/(icons|pixmaps)\//.test(url)
    }

    // "image://icon//home/me/shot.png" is a plain file routed through
    // Quickshell's icon provider, which loads it as an icon: sometimes at a
    // 2×2 size, failing, and then drawing its pink-and-black "missing" square
    // while reporting success, so nothing falls back. As a file:// URL Qt's
    // own loader reads it, and a missing file is an error that falls through.
    function fileUrl(url: string): string {
        if (!url.startsWith("image://icon//"))
            return url
        const path = decodeURIComponent(url.slice("image://icon/".length).split("?")[0])
        return `file://${path}`
    }

    function pictureOf(notification: var): string {
        const image = `${notification.image ?? ""}`
        if (image === "" || root.isThemeIcon(image) || root.isIconFile(image))
            return ""
        return root.fileUrl(image)
    }

    function iconOf(notification: var): string {
        const image = `${notification.image ?? ""}`
        if (root.isIconFile(image))
            return root.fileUrl(image)
        const names = []
        if (root.isThemeIcon(image))
            names.push(decodeURIComponent(image.slice("image://icon/".length).split("?")[0]))
        const appIcon = `${notification.appIcon ?? ""}`
        if (appIcon.startsWith("/"))
            return `file://${appIcon}`
        if (appIcon.startsWith("file://"))
            return appIcon
        if (appIcon.startsWith("image://"))
            return root.fileUrl(appIcon)
        if (appIcon !== "")
            names.push(appIcon)
        const entry = (notification.desktopEntry ? DesktopEntries.byId(notification.desktopEntry) : null)
            ?? DesktopEntries.heuristicLookup(notification.appName ?? "")
        if (entry && entry.icon)
            names.push(entry.icon)
        for (const name of names) {
            // A desktop entry's Icon= may be an absolute file, which comes
            // back through the icon provider too.
            const path = Quickshell.iconPath(name, true)
            if (path !== "")
                return root.fileUrl(path)
        }
        return ""
    }

    // A picture handed over as image data only lives as long as the
    // notification, so the popup saves a copy once it has drawn it
    // (NotificationPicture) and the history is pointed at that.
    function keepPicture(key: int, url: string): void {
        root.history = root.history.map(entry =>
            entry.key === key ? Object.assign({}, entry, { picture: url }) : entry)
        if (root.current && root.current.key === key)
            root.current = Object.assign({}, root.current, { picture: url })
    }

    function snapshot(notification: var): var {
        root.serial += 1
        return {
            picture: root.pictureOf(notification),
            icon: root.iconOf(notification),
            key: root.serial,
            id: notification.id,
            summary: notification.summary ?? "",
            body: notification.body ?? "",
            appName: notification.appName ?? "",
            appIcon: notification.appIcon ?? "",
            image: notification.image ?? "",
            urgency: notification.urgency,
            expireTimeout: notification.expireTimeout,
            // Buttons, by identifier; "default" is the click on the popup.
            actions: (notification.actions ?? [])
                .map(action => ({ identifier: action.identifier, text: action.text ?? "" })),
            time: Date.now()
        }
    }

    readonly property bool active: root.current !== null
    readonly property bool critical: root.active
        && root.current.urgency === NotificationUrgency.Critical

    readonly property NotificationServer server: NotificationServer {
        id: server

        // Survives a config reload, so editing the shell does not drop a
        // notification that is on screen.
        keepOnReload: true

        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        actionIconsSupported: true
        actionsSupported: true
        persistenceSupported: true
        extraHints: ["image-data", "image_data", "icon-image"]

        onNotification: notification => {
            console.log("===> NOTIF ARRIVED: appName=" + notification.appName + " appIcon=" + notification.appIcon + " image=" + notification.image + " summary=" + notification.summary)
            try {
                console.log("===> NOTIF HINTS:", JSON.stringify(notification.hints))
            } catch (e) {
                console.log("===> NOTIF HINTS ERR:", e)
            }
            // Tracking keeps the object alive past this handler; without it
            // the notification is destroyed as soon as the signal returns.
            notification.tracked = true
            root.present(notification)
        }
    }

    readonly property Timer expiry: Timer {
        onTriggered: root.dismiss()
    }

    function timeoutFor(notification: var): int {
        // Critical urgency waits for the user. Anything else that asks to stay
        // forever is capped, or a misbehaving application owns the island.
        if (notification.urgency === NotificationUrgency.Critical)
            return 0
        if (notification.expireTimeout > 0)
            return Math.min(notification.expireTimeout, 15000)
        return root.defaultTimeout
    }

    function present(object: var): void {
        const notification = root.snapshot(object)
        console.log("===> SNAPSHOT RESULT: picture=" + notification.picture + " icon=" + notification.icon)
        root.history = [notification].concat(root.history).slice(0, root.historyLimit)

        // Critical notifications ignore do-not-disturb. One that never reaches
        // the island is expired at once, so a sender waiting on it
        // (`notify-send --wait`) is not left hanging.
        const isCritical = notification.urgency === NotificationUrgency.Critical
        if (root.doNotDisturb && !isCritical) {
            object.expire()
            return
        }

        // Newest wins, except over a critical one. The newcomer is still
        // recorded.
        if (root.critical && !isCritical) {
            object.expire()
            return
        }

        // The one it replaces is expired rather than left open.
        if (root.live && root.live !== object)
            root.live.expire()

        root.current = notification
        root.live = object
        object.closed.connect(() => {
            if (root.live === object)
                root.live = null
        })

        const timeout = root.timeoutFor(notification)
        root.expiry.stop()
        if (timeout > 0) {
            root.expiry.interval = timeout
            root.expiry.start()
        }

        root.arrived(notification)
    }

    function dismiss(): void {
        root.expiry.stop()
        if (root.live) {
            root.live.dismiss()
            root.live = null
        }
        root.current = null
    }

    function invoke(identifier: string): void {
        const live = root.live
        root.dismiss()
        if (!live)
            return
        const action = (live.actions ?? []).find(a => a.identifier === identifier)
        if (action)
            action.invoke()
    }

    // Do Not Disturb state, toggled from the notification center
    property bool doNotDisturb: false
}
