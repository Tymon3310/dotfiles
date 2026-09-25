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

    // `shown`, `waiting` and `history` hold plain copies, never the
    // Notification objects: the server deletes an object as soon as its
    // application closes or replaces it, and a list still built from the
    // deleted object crashes Quickshell (a segfault while creating the row).
    // The objects themselves sit in `liveObjects`, a lookup by key that no
    // list is ever built from, to tell each application what happened to its
    // notification; an entry goes when its object does.
    //
    //   shown     on the island, newest first, at most `maxShown`
    //   waiting   the rest, oldest first; each moves up when a slot frees,
    //             and its time starts only then
    property var shown: []
    property var waiting: []
    readonly property int maxShown: 3

    property var history: []
    readonly property int historyLimit: 50

    property var liveObjects: ({})
    property int serial: 0

    // The newest on the island, for anything that shows one.
    readonly property var current: root.shown.length > 0 ? root.shown[0] : null

    // When each shown one times out, by key (absent: never). Kept apart from
    // the entries so extending one does not rebuild the list.
    property var deadlines: ({})

    // True while the pointer is over the stack: nothing times out under it.
    property bool held: false

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
        const update = list => list.map(entry =>
            entry.key === key ? Object.assign({}, entry, { picture: url }) : entry)
        root.shown = update(root.shown)
        root.waiting = update(root.waiting)
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

    readonly property bool active: root.shown.length > 0
    readonly property bool critical: root.shown.some(entry => root.isCritical(entry))

    function isCritical(entry: var): bool {
        return entry.urgency === NotificationUrgency.Critical
    }

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
        // The history is the shell's own and does not survive a restart, so
        // persistence is not claimed.
        persistenceSupported: false
        extraHints: ["image-data", "image_data", "icon-image"]

        onNotification: notification => {
            // Tracking keeps the object alive past this handler; without it
            // the notification is destroyed as soon as the signal returns.
            notification.tracked = true
            root.present(notification)
        }
    }

    // One clock for every shown notification, against `deadlines`.
    readonly property Timer tick: Timer {
        interval: 250
        repeat: true
        running: root.shown.length > 0
        onTriggered: {
            if (root.held)
                return
            const now = Date.now()
            for (const entry of root.shown) {
                const deadline = root.deadlines[entry.key]
                if (deadline !== undefined && deadline <= now)
                    root.dismissKey(entry.key)
            }
        }
    }

    // Letting go of the stack gives everything on it a moment more.
    onHeldChanged: {
        if (root.held)
            return
        const soon = Date.now() + 2000
        const deadlines = Object.assign({}, root.deadlines)
        for (const key in deadlines)
            deadlines[key] = Math.max(deadlines[key], soon)
        root.deadlines = deadlines
    }

    function timeoutFor(notification: var): int {
        // Critical urgency waits for the user. Anything else that asks to stay
        // forever is capped, or a misbehaving application owns the island.
        if (root.isCritical(notification))
            return 0
        if (notification.expireTimeout > 0)
            return Math.min(notification.expireTimeout, 15000)
        return root.defaultTimeout
    }

    function present(object: var): void {
        const notification = root.snapshot(object)
        root.history = [notification].concat(root.history).slice(0, root.historyLimit)

        // Critical notifications ignore do-not-disturb. One that never reaches
        // the island is expired at once, so a sender waiting on it
        // (`notify-send --wait`) is not left hanging.
        if (root.doNotDisturb && !root.isCritical(notification)) {
            object.expire()
            return
        }

        const key = notification.key
        const live = Object.assign({}, root.liveObjects)
        live[key] = object
        root.liveObjects = live
        // The application closed it, or it was expired or dismissed here.
        object.closed.connect(() => root.forget(key))

        if (root.shown.length < root.maxShown) {
            root.show(notification)
        } else if (root.isCritical(notification)) {
            // A critical one never waits: the oldest ordinary one steps back
            // to the front of the queue, its time reset.
            const bumped = root.shown.slice().reverse().find(entry => !root.isCritical(entry))
            if (bumped) {
                root.shown = root.shown.filter(entry => entry.key !== bumped.key)
                const deadlines = Object.assign({}, root.deadlines)
                delete deadlines[bumped.key]
                root.deadlines = deadlines
                root.waiting = [bumped].concat(root.waiting)
            }
            root.show(notification)
        } else {
            root.waiting = root.waiting.concat([notification])
        }

        root.arrived(notification)
    }

    function show(notification: var): void {
        const timeout = root.timeoutFor(notification)
        if (timeout > 0) {
            const deadlines = Object.assign({}, root.deadlines)
            deadlines[notification.key] = Date.now() + timeout
            root.deadlines = deadlines
        }
        root.shown = [notification].concat(root.shown)
    }

    // Off the island and out of the queue, without telling anyone; the next
    // waiting one moves up.
    function forget(key: int): void {
        if (!(key in root.liveObjects))
            return
        const live = Object.assign({}, root.liveObjects)
        delete live[key]
        root.liveObjects = live
        const deadlines = Object.assign({}, root.deadlines)
        delete deadlines[key]
        root.deadlines = deadlines
        root.shown = root.shown.filter(entry => entry.key !== key)
        root.waiting = root.waiting.filter(entry => entry.key !== key)
        while (root.shown.length < root.maxShown && root.waiting.length > 0) {
            const next = root.waiting[0]
            root.waiting = root.waiting.slice(1)
            root.show(next)
        }
    }

    // Timed out or hidden: the application is told it expired, which also
    // releases a sender waiting on it (`notify-send --wait`).
    function dismissKey(key: int): void {
        const object = root.liveObjects[key]
        root.forget(key)
        if (object)
            object.expire()
    }

    // The user closed it (its cross): the application is told it was
    // dismissed.
    function closeKey(key: int): void {
        const object = root.liveObjects[key]
        root.forget(key)
        if (object)
            object.dismiss()
    }

    // Runs one of its actions ("default" for a click on it). Let go of
    // without expiring it first: an expired notification's actions no longer
    // reach the application.
    function invokeKey(key: int, identifier: string): void {
        const object = root.liveObjects[key]
        root.forget(key)
        if (!object)
            return
        const action = (object.actions ?? []).find(a => a.identifier === identifier)
        if (action)
            action.invoke()
    }

    // Everything off the island and out of the queue.
    function dismiss(): void {
        for (const entry of root.shown.concat(root.waiting))
            root.dismissKey(entry.key)
    }

    // The newest one, for callers that show only that.
    function close(): void {
        if (root.current)
            root.closeKey(root.current.key)
    }

    function invoke(identifier: string): void {
        if (root.current)
            root.invokeKey(root.current.key, identifier)
    }

    function clearHistory(): void {
        root.history = []
    }

    function remove(notification: var): void {
        root.history = root.history.filter(entry => entry.key !== notification.key)
        root.dismissKey(notification.key)
    }

    // Do Not Disturb state, toggled from the notification center. Not kept
    // across restarts.
    property bool doNotDisturb: false

    function toggleDoNotDisturb(): void {
        root.doNotDisturb = !root.doNotDisturb
        if (root.doNotDisturb)
            root.dismiss()
    }
}
