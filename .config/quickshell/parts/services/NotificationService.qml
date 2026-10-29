pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon.
//
// Data lives in one table, `entries` (key -> plain object). Views never hold
// the Notification objects: the server deletes one as soon as its
// application closes it, and a view built from a deleted object crashes
// Quickshell. The objects sit in `live`, which no view reads.
//
// Two ListModels say what is shown, by key. They change in place, so a
// delegate is built once per notification and keeps its state and animations:
//
//   popups   on the island (or the fullscreen overlay), newest first
//   groups   the history, one row per application, latest activity first
//
// A view reads an entry with `entry(key)`, which depends on `revision`, so a
// replaced notification (new text, progress) updates the cards showing it.
Singleton {
    id: root

    property var entries: ({})
    property int revision: 0

    function entry(key: int): var {
        root.revision
        return root.entries[key] ?? null
    }

    // Keys, newest first, and the keys of each group (by `group`).
    property var order: []
    property var groupKeys: ({})
    readonly property int count: root.order.length
    readonly property int historyLimit: 50

    readonly property ListModel popups: ListModel {}
    readonly property ListModel groups: ListModel {}

    // Keys waiting for a popup slot, oldest first.
    property var queue: []
    readonly property int maxPopups: 3
    property int popupCount: 0
    readonly property bool active: root.popupCount > 0
    property bool critical: false

    // The monitor the popups show on: the focused one when the first of them
    // arrives, kept until the last one goes, so a stack never jumps screens.
    property string popupScreen: ""

    function showsOn(screenName: string): bool {
        return root.active && (root.popupScreen === "" || root.popupScreen === screenName)
    }

    // While the pointer is over the popups nothing times out; letting go
    // gives each at least two seconds more.
    property bool held: false
    property real now: Date.now()

    property bool doNotDisturb: false

    function toggleDoNotDisturb(): void {
        root.doNotDisturb = !root.doNotDisturb
        if (root.doNotDisturb)
            root.dismissPopups()
    }

    property var live: ({})
    property int serial: 0

    readonly property int defaultTimeout: SettingsService.notificationTimeout

    function timeoutFor(object: var): int {
        // Critical waits for the user. Anything else that asks to stay forever
        // is capped, or a misbehaving application owns the island.
        if (object.urgency === NotificationUrgency.Critical)
            return 0
        if (object.expireTimeout > 0)
            return Math.min(object.expireTimeout, 15000)
        return root.defaultTimeout
    }

    //
    // Pictures and icons.
    //
    // Quickshell folds `notify-send -i NAME` into `image` as
    // "image://icon/NAME", so an icon name and a real picture (an avatar, a
    // screenshot) arrive in the same field and are told apart here.

    function isThemeIcon(url: string): bool {
        return url.startsWith("image://icon/") && !url.startsWith("image://icon//")
    }

    function isIconFile(url: string): bool {
        return url.startsWith("image://icon//") && /\/(icons|pixmaps)\//.test(url)
    }

    // "image://icon//home/me/shot.png" is a plain file sent through the icon
    // provider, which can load it at 2×2 or draw its "missing" square while
    // reporting success. As a file:// URL a missing file is a plain error.
    function fileUrl(url: string): string {
        if (!url.startsWith("image://icon//"))
            return url
        const path = decodeURIComponent(url.slice("image://icon/".length).split("?")[0])
        return `file://${path}`
    }

    // Image data (`image://qsimage/…`) only exists while its object does.
    function isImageData(url: string): bool {
        return url.startsWith("image://qsimage")
    }

    function pictureOf(object: var): string {
        const image = `${object.image ?? ""}`
        if (image === "" || root.isThemeIcon(image) || root.isIconFile(image))
            return ""
        return root.fileUrl(image)
    }

    function iconOf(object: var): string {
        const image = `${object.image ?? ""}`
        if (root.isIconFile(image))
            return root.fileUrl(image)
        const names = []
        if (root.isThemeIcon(image))
            names.push(decodeURIComponent(image.slice("image://icon/".length).split("?")[0]))
        const appIcon = `${object.appIcon ?? ""}`
        if (appIcon.startsWith("/"))
            return `file://${appIcon}`
        if (appIcon.startsWith("file://"))
            return appIcon
        if (appIcon.startsWith("image://"))
            return root.fileUrl(appIcon)
        if (appIcon !== "")
            names.push(appIcon)
        const desktop = root.desktopEntryOf(object)
        if (desktop && desktop.icon)
            names.push(desktop.icon)
        for (const name of names) {
            const path = Quickshell.iconPath(name, true)
            if (path !== "")
                return root.fileUrl(path)
        }
        return ""
    }

    function desktopEntryOf(object: var): var {
        return (object.desktopEntry ? DesktopEntries.byId(object.desktopEntry) : null)
            ?? DesktopEntries.heuristicLookup(object.appName ?? "")
    }

    function read(object: var): var {
        const appName = `${object.appName ?? ""}`
        const desktop = root.desktopEntryOf(object)
        return {
            id: object.id,
            appName: appName !== "" ? appName : (desktop?.name ?? "Notification"),
            desktopEntry: `${object.desktopEntry ?? ""}`,
            group: (`${object.desktopEntry ?? ""}` || appName || "other").toLowerCase(),
            summary: `${object.summary ?? ""}`,
            body: `${object.body ?? ""}`,
            picture: root.pictureOf(object),
            icon: root.iconOf(object),
            critical: object.urgency === NotificationUrgency.Critical,
            actions: (object.actions ?? [])
                .map(action => ({ identifier: action.identifier, text: `${action.text ?? ""}` })),
            timeout: root.timeoutFor(object)
        }
    }

    //
    // Arrival.

    readonly property NotificationServer server: NotificationServer {
        // Survives a config reload; tracked notifications are handed to the
        // new generation again.
        keepOnReload: true

        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        persistenceSupported: false
        extraHints: ["image-data", "image_data", "icon-image"]

        onNotification: object => root.receive(object)
    }

    function receive(object: var): void {
        // Claude Code's own reminders: the island's agent badge already shows
        // when a session needs input.
        if (object.summary === "Claude Code") {
            object.dismiss()
            return
        }

        if (root.isHeadsetNotice(object)) {
            object.expire()
            return
        }

        // Tracking keeps the object alive past this handler.
        object.tracked = true

        // After a reload the server hands back what it still tracks: attach it
        // to its restored history entry instead of showing it again.
        if (root.restoredGeneration) {
            for (const key of root.order) {
                const e = root.entries[key]
                if (e.id === object.id && !(key in root.live)) {
                    root.attach(key, object)
                    return
                }
            }
        }

        root.serial += 1
        const key = root.serial
        const data = root.read(object)
        data.key = key
        data.time = Date.now()
        root.entries[key] = data
        root.attach(key, object)
        root.addToHistory(key)
        root.revision += 1

        if (root.doNotDisturb && !data.critical)
            root.retire(key)
        else
            root.popUp(key)
    }

    // Some headset utilities announce connections as notifications; the OSD
    // already shows those, so they become an OSD instead of a second card.
    function isHeadsetNotice(object: var): bool {
        const appName = `${object.appName ?? ""}`.toLowerCase()
        const isHeadsetApp = /\b(jbl[-_]quantum|headsetcontrol|jbl-quantum-tray)\b/i.test(appName)
            || (HeadsetService.model !== "" && appName.includes(HeadsetService.model.toLowerCase()))
        const text = `${object.summary ?? ""} ${object.body ?? ""}`
        if (!isHeadsetApp || !/\b(online|connected|offline|disconnected)\b/i.test(text))
            return false
        const connected = !/\b(offline|disconnected)\b/i.test(text)
        const battery = HeadsetService.battery
        OsdService.requested(
            connected ? "󰋋" : "󰟎",
            connected ? `Headset Connected${connected && battery >= 0 ? ` · ${battery}%` : ""}`
                : "Headset Disconnected",
            connected && battery >= 0 ? battery / 100.0 : -1)
        return true
    }

    function attach(key: int, object: var): void {
        root.live[key] = object
        root.entries[key].alive = true
        object.closed.connect(() => root.handleClosed(key))
        // A replacement updates the object in place, one property at a time;
        // the changes are gathered and applied once.
        const changed = () => root.markChanged(key)
        object.summaryChanged.connect(changed)
        object.bodyChanged.connect(changed)
        object.imageChanged.connect(changed)
        object.appIconChanged.connect(changed)
        object.actionsChanged.connect(changed)
        object.urgencyChanged.connect(changed)
    }

    property var changedKeys: ({})

    function markChanged(key: int): void {
        root.changedKeys[key] = true
        root.applyChanges.restart()
    }

    readonly property Timer applyChanges: Timer {
        interval: 0
        onTriggered: {
            const keys = Object.keys(root.changedKeys).map(Number)
            root.changedKeys = {}
            for (const key of keys)
                root.replaced(key)
        }
    }

    // New content for a notification already here: refresh it, move it to the
    // top of the history and show it again (a progress update just refreshes
    // a popup that is still up).
    function replaced(key: int): void {
        const object = root.live[key]
        const old = root.entries[key]
        if (!object || !old)
            return
        const data = root.read(object)
        data.key = key
        data.time = Date.now()
        root.entries[key] = data
        root.removeFromHistory(key)
        root.addToHistory(key)
        root.revision += 1

        if (root.popupIndex(key) >= 0)
            root.startTimer(key)
        else if (!root.doNotDisturb || data.critical)
            root.popUp(key)
    }

    //
    // Popups.

    function popupIndex(key: int): int {
        for (let i = 0; i < root.popups.count; i++) {
            if (root.popups.get(i).key === key)
                return i
        }
        return -1
    }

    function popUp(key: int): void {
        if (root.popupIndex(key) >= 0 || root.queue.indexOf(key) >= 0)
            return
        if (root.popups.count === 0)
            root.popupScreen = HyprlandService.focusedMonitor
        if (root.popups.count < root.maxPopups) {
            root.insertPopup(key)
            return
        }
        // A critical one never waits: the oldest ordinary one steps back to
        // the front of the queue.
        if (root.entries[key].critical) {
            for (let i = root.popups.count - 1; i >= 0; i--) {
                const bumped = root.popups.get(i).key
                if (!root.entries[bumped].critical) {
                    root.popups.remove(i)
                    root.queue = [bumped].concat(root.queue)
                    root.insertPopup(key)
                    return
                }
            }
            root.queue = [key].concat(root.queue)
            return
        }
        root.queue = root.queue.concat([key])
    }

    function insertPopup(key: int): void {
        root.startTimer(key)
        root.popups.insert(0, { key: key })
        root.updatePopupState()
    }

    function startTimer(key: int): void {
        const e = root.entries[key]
        root.now = Date.now()
        e.deadline = e.timeout > 0 ? root.now + e.timeout : 0
        e.remaining = e.timeout
        root.revision += 1
    }

    function hidePopup(key: int): void {
        root.queue = root.queue.filter(k => k !== key)
        const index = root.popupIndex(key)
        if (index < 0)
            return
        root.popups.remove(index)
        while (root.popups.count < root.maxPopups && root.queue.length > 0) {
            const next = root.queue[0]
            root.queue = root.queue.slice(1)
            root.insertPopup(next)
        }
        root.updatePopupState()
    }

    function updatePopupState(): void {
        root.popupCount = root.popups.count
        let critical = false
        for (let i = 0; i < root.popups.count; i++)
            critical = critical || root.entries[root.popups.get(i).key].critical
        root.critical = critical
        if (root.popups.count === 0) {
            root.popupScreen = ""
            root.held = false
        }
    }

    readonly property Timer tick: Timer {
        interval: 100
        repeat: true
        running: root.popupCount > 0 && !root.held
        onTriggered: {
            root.now = Date.now()
            const expired = []
            for (let i = 0; i < root.popups.count; i++) {
                const e = root.entries[root.popups.get(i).key]
                if (e.deadline > 0 && e.deadline <= root.now)
                    expired.push(e.key)
            }
            for (const key of expired)
                root.retire(key)
        }
    }

    onHeldChanged: {
        const now = Date.now()
        for (let i = 0; i < root.popups.count; i++) {
            const e = root.entries[root.popups.get(i).key]
            if (e.timeout <= 0)
                continue
            if (root.held)
                e.remaining = Math.max(0, e.deadline - now)
            else
                e.deadline = now + Math.max(e.remaining, 2000)
        }
        root.now = now
        root.revision += 1
    }

    // Time left as a fraction, for the popup's countdown line.
    function progressOf(key: int): real {
        const e = root.entry(key)
        if (!e || e.timeout <= 0)
            return 1
        const remaining = root.held ? e.remaining : e.deadline - root.now
        return Math.max(0, Math.min(1, remaining / e.timeout))
    }

    //
    // Leaving.

    // Off the popups but kept in the history. The object is kept too when it
    // still has a use there: actions to run (Discord opens the channel), or a
    // picture that only exists as image data. Otherwise it is expired now, so
    // a sender waiting on it (`notify-send --wait`) is answered.
    function retire(key: int): void {
        root.hidePopup(key)
        const object = root.live[key]
        const e = root.entries[key]
        if (!object || !e)
            return
        if (e.actions.length === 0 && !root.isImageData(e.picture))
            root.release(key, "expire")
    }

    // Let go of the live object: "expire", "dismiss", or "" when the
    // application already closed it.
    function release(key: int, how: string): void {
        const object = root.live[key]
        delete root.live[key]
        const e = root.entries[key]
        if (e) {
            e.alive = false
            if (root.isImageData(e.picture))
                e.picture = ""
            root.revision += 1
        }
        if (object && how === "expire")
            object.expire()
        else if (object && how === "dismiss")
            object.dismiss()
    }

    function handleClosed(key: int): void {
        if (!(key in root.live))
            return
        root.release(key, "")
        root.hidePopup(key)
    }

    // The user closed a popup: gone from the island, kept in the history.
    function close(key: int): void {
        root.hidePopup(key)
        root.release(key, "dismiss")
    }

    // Removed from the history (and the island, if it is up).
    function remove(key: int): void {
        root.hidePopup(key)
        root.release(key, "dismiss")
        root.removeFromHistory(key)
        delete root.entries[key]
        root.revision += 1
    }

    function dismissPopups(): void {
        const keys = root.queue.slice()
        for (let i = 0; i < root.popups.count; i++)
            keys.push(root.popups.get(i).key)
        for (const key of keys)
            root.retire(key)
    }

    function clearGroup(group: string): void {
        for (const key of (root.groupKeys[group] ?? []).slice())
            root.remove(key)
    }

    function clearHistory(): void {
        for (const key of root.order.slice())
            root.remove(key)
    }

    //
    // Clicks.

    // The live object is dropped before an action runs: invoking can make the
    // server close (and delete) it on the spot.
    function invoke(key: int, identifier: string): void {
        const object = root.live[key]
        const action = object ? (object.actions ?? []).find(a => a.identifier === identifier) : null
        if (action)
            delete root.live[key]
        root.remove(key)
        if (action)
            action.invoke()
    }

    // A click on the card: its default action while the application still
    // listens, else whatever it points at.
    function activate(key: int): void {
        const object = root.live[key]
        const e = root.entries[key]
        if (!e)
            return
        const actions = object ? (object.actions ?? []) : []
        const action = actions.find(a => a.identifier === "default") ?? actions[0]
        if (action)
            delete root.live[key]
        root.remove(key)
        if (action)
            action.invoke()
        else
            root.openTarget(e)
    }

    function openTarget(e: var): void {
        const url = `${e.summary} ${e.body}`.match(/https?:\/\/[^\s<>"']+/)
        if (url) {
            Qt.openUrlExternally(url[0])
            return
        }
        // Screenshots carry their file as the picture.
        if (e.group === "screenshot" && e.picture.startsWith("file://")) {
            Qt.openUrlExternally(e.picture)
            return
        }
        const id = e.desktopEntry || e.appName
        if (/^[\w.\-]+$/.test(id))
            Hyprland.dispatch(`hl.dsp.focus({ window = "class:${id.toLowerCase()}" })`)
        const desktop = root.desktopEntryOf(e)
        if (desktop)
            desktop.execute()
    }

    //
    // History.

    function addToHistory(key: int): void {
        const group = root.entries[key].group
        root.order = [key].concat(root.order)
        const keys = root.groupKeys[group] ?? []
        root.groupKeys[group] = [key].concat(keys)
        root.groupKeysChanged()

        let index = -1
        for (let i = 0; i < root.groups.count; i++) {
            if (root.groups.get(i).group === group) {
                index = i
                break
            }
        }
        if (index < 0)
            root.groups.insert(0, { group: group })
        else if (index > 0)
            root.groups.move(index, 0, 1)

        while (root.order.length > root.historyLimit)
            root.remove(root.order[root.order.length - 1])
        root.scheduleSave()
    }

    function removeFromHistory(key: int): void {
        const e = root.entries[key]
        if (!e)
            return
        root.order = root.order.filter(k => k !== key)
        const keys = (root.groupKeys[e.group] ?? []).filter(k => k !== key)
        if (keys.length > 0) {
            root.groupKeys[e.group] = keys
        } else {
            delete root.groupKeys[e.group]
            for (let i = 0; i < root.groups.count; i++) {
                if (root.groups.get(i).group === e.group) {
                    root.groups.remove(i)
                    break
                }
            }
        }
        root.groupKeysChanged()
        root.scheduleSave()
    }

    // "now", "5m", "2h", "3d".
    property real minuteNow: Date.now()
    readonly property Timer minuteTick: Timer {
        interval: 30000
        repeat: true
        running: root.count > 0
        onTriggered: root.minuteNow = Date.now()
    }

    function ago(time: real): string {
        const minutes = Math.floor((root.minuteNow - time) / 60000)
        if (minutes < 1)
            return "now"
        if (minutes < 60)
            return `${minutes}m`
        if (minutes < 1440)
            return `${Math.floor(minutes / 60)}h`
        return `${Math.floor(minutes / 1440)}d`
    }

    //
    // The history survives reloads and restarts (until logout: the file is
    // in the runtime directory). Popups are not restored.

    readonly property FileView historyFile: FileView {
        path: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/quickshell_notifications.json`
        blockLoading: true
        printErrors: false
    }

    // True when the history came from this same Quickshell instance (a config
    // reload), so the server's tracked objects can be matched to it.
    property bool restoredGeneration: false
    property bool loaded: false

    function load(): void {
        let saved = null
        try {
            saved = JSON.parse(root.historyFile.text() || "null")
        } catch (e) {
            saved = null
        }
        const list = saved && Array.isArray(saved.history) ? saved.history : []
        root.restoredGeneration = saved?.instanceId === Quickshell.instanceId
        // Oldest first, so each lands on top of the one before.
        for (const e of list.slice().reverse()) {
            if (!e || typeof e.key !== "number" || typeof e.group !== "string")
                continue
            if (root.isImageData(e.picture ?? ""))
                e.picture = ""
            e.alive = false
            root.entries[e.key] = e
            root.serial = Math.max(root.serial, e.key)
            root.addToHistory(e.key)
        }
        root.revision += 1
        root.loaded = true
    }

    function scheduleSave(): void {
        if (root.loaded)
            root.saveTimer.restart()
    }

    readonly property Timer saveTimer: Timer {
        interval: 500
        onTriggered: root.historyFile.setText(JSON.stringify({
            instanceId: Quickshell.instanceId,
            history: root.order.map(key => {
                const e = Object.assign({}, root.entries[key])
                delete e.deadline
                delete e.remaining
                return e
            })
        }))
    }

    Component.onCompleted: root.load()

    // quickshell ipc call notifications <dismiss|clear|toggleDnd>
    readonly property IpcHandler ipc: IpcHandler {
        target: "notifications"
        function dismiss(): void { root.dismissPopups() }
        function clear(): void { root.clearHistory() }
        function toggleDnd(): void { root.toggleDoNotDisturb() }
    }
}
