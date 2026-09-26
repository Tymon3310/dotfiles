// ╭────────────────────────────────────────────────────────────────────────────╮
// │                                                                            │
// │   H Y P R L A N D   S E R V I C E                                        │
// │   workspace state · read from hyprctl, refreshed on events               │
// │                                                                            │
// │   github.com/andreumassanet/impasto                                        │
// │                                                                            │
// ╰────────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Workspace state for the bar.
//
// Quickshell 0.3.0 ships an object model for this, but against Hyprland 0.55
// it reports every workspace with id -1 and no monitors at all, so the widget
// built on it can only ever highlight workspace 1. The event socket and
// dispatch do work, so the state is read from hyprctl and refreshed on the
// events that change it — no polling.
QtObject {
    id: root

    // Slots always drawn, so the bar keeps a stable width.
    readonly property int slots: SettingsService.workspaceCount
    // Stretches past the setting for any workspace in use, so a monitor
    // parked on workspace 24 still gets its dot.
    readonly property int maximum: Math.max(SettingsService.workspaceMax,
        ...root.inUse.filter(id => id > 0))

    // Occupied, focused, or active on any monitor.
    readonly property var inUse: root.occupiedIds
        .concat([root.activeId])
        .concat(Object.values(root.activeByMonitor))

    property int activeId: 1
    property var occupiedIds: []

    // Per monitor, from `hyprctl monitors`: each one's active workspace, and
    // which monitor has focus. A bar on another screen draws its active
    // workspace, but not as the focused one.
    property var activeByMonitor: ({})
    property string focusedMonitor: ""

    function activeOn(monitor: string): int {
        return root.activeByMonitor[monitor] ?? root.activeId
    }

    function isOccupied(workspaceId: int): bool {
        return root.occupiedIds.indexOf(workspaceId) >= 0
    }

    // The fixed slots, plus any higher workspace that is occupied or active.
    readonly property var visibleIds: {
        const ids = []
        for (let id = 1; id <= root.slots; id++)
            ids.push(id)
        for (const id of root.inUse) {
            if (id > root.slots && id <= root.maximum && ids.indexOf(id) < 0)
                ids.push(id)
        }
        return ids.sort((left, right) => left - right)
    }

    function isVisible(workspaceId: int): bool {
        return root.visibleIds.indexOf(workspaceId) >= 0
    }

    function focus(workspaceId: int): void {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspaceId} })`)
    }

    // Events come in bursts (a workspace switch sends several), and every
    // hyprctl call is a fork of the whole shell; Quickshell 0.3 occasionally
    // crashes in a forked child, so the fewer the better. One batched call,
    // at most every 80 ms.
    function refresh(): void {
        root.settle.restart()
    }

    readonly property Timer settle: Timer {
        interval: 80
        onTriggered: root.stateProcess.running = true
    }

    // ── ON DEMAND ───────────────────────────────────────────────────────────
    //
    // Monitors and keybindings only matter while the settings window is open,
    // so they are queried when asked for rather than kept in step with events.

    property var monitors: []
    property var binds: []

    readonly property Process monitorsProcess: Process {
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.parseJson(text)
                if (Array.isArray(list))
                    root.monitors = list
            }
        }
    }

    readonly property Process bindsProcess: Process {
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.parseJson(text)
                if (Array.isArray(list))
                    root.binds = list
            }
        }
    }

    // ── WINDOWS ─────────────────────────────────────────────────────────────
    //
    // Wayland toplevels do not carry a workspace, so the list comes from
    // hyprctl and thumbnails from the toplevel, matched on title.

    property var clients: []

    // Keep the client list refreshed on every window event, even when it is
    // empty. Without it, refreshes only happen while the list is non-empty,
    // which is fine for the overview but freezes the dock once the last
    // window closes.
    property bool watchClients: false

    // Address (`0x…`) of the window with keyboard focus, or "". Not
    // `focusHistoryID == 0`, which stays on the last window after focus moves
    // to an empty workspace. Updated from `activewindowv2`, which sends the
    // address without `0x` and an empty string for no window.
    property string focusedAddress: ""

    readonly property Process focusedProcess: Process {
        command: ["hyprctl", "activewindow", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const window = root.parseJson(text)
                root.focusedAddress = window && typeof window.address === "string"
                    ? window.address : ""
            }
        }
    }

    readonly property Process clientsProcess: Process {
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.parseJson(text)
                if (!Array.isArray(list))
                    return
                root.clients = list.filter(client => client.mapped && client.workspace
                    && client.workspace.id > 0)
            }
        }
    }

    function loadClients(): void { root.clientsProcess.running = true }

    function clientsOn(workspaceId: int): var {
        return root.clients.filter(client => client.workspace.id === workspaceId)
    }

    function focusWindow(address: string): void {
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${address}" })`)
    }

    function closeWindow(address: string): void {
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${address}" })`)
        root.refresh()
        root.loadClients()
    }

    function toggleFloating(address: string): void {
        Hyprland.dispatch(`hl.dsp.window.float({ window = "address:${address}" })`)
        root.refresh()
        root.loadClients()
    }

    // Swap two specific windows (`target` names the second; plain
    // `swapwindow` only takes a direction).
    //
    // The swap warps the pointer to the moved window, so this runs as a Lua
    // chunk that saves the cursor position, swaps and restores it within one
    // compositor iteration. `cursor:no_warps` is not an option: focus-on-click
    // relies on the warp elsewhere.
    function swapWindows(address: string, target: string): void {
        if (address === target)
            return
        const swap = `hl.dsp.window.swap({ window = "address:${address}", target = "address:${target}" })`
        Hyprland.dispatch(`function() local p = hl.get_cursor_pos() hl.dispatch(${swap})`
            + ` if p then hl.dispatch(hl.dsp.cursor.move({ x = p.x, y = p.y })) end end`)
        root.loadClients()
    }

    // Floating windows only; tiled ones are placed by the layout.
    function moveFloating(address: string, x: int, y: int): void {
        Hyprland.dispatch(`hl.dsp.window.move({ window = "address:${address}", x = ${x}, y = ${y} })`)
        root.loadClients()
    }

    // `follow = false` keeps the view in place. The Lua API accepts
    // `silent = true` but ignores it and switches workspace anyway.
    function moveClient(address: string, workspaceId: int): void {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${workspaceId}, window = "address:${address}", follow = false })`)
        root.refresh()
        root.loadClients()
    }

    // ── BIND NAMES ──────────────────────────────────────────────────────────
    //
    // `hyprctl binds` returns a modifier mask and key; `hl.bind` wants
    // "SUPER + SHIFT + N". The keys page and `ShortcutService` share this so
    // the string passed to `hl.unbind` matches exactly.
    readonly property var modifierNames: [
        { bit: 64, name: "SUPER" },
        { bit: 4,  name: "CTRL" },
        { bit: 8,  name: "ALT" },
        { bit: 1,  name: "SHIFT" }
    ]

    function spell(bind: var): string {
        const parts = []
        for (const modifier of root.modifierNames) {
            if (bind.modmask & modifier.bit)
                parts.push(modifier.name)
        }
        parts.push(bind.key || `code ${bind.keycode}`)
        return parts.join(" + ")
    }

    function loadMonitors(): void { root.monitorsProcess.running = true }
    function loadBinds(): void { root.bindsProcess.running = true }

    // `hyprctl --batch` prints the two JSON arrays back to back: the
    // workspaces, then the monitors. The focused monitor's workspace is the
    // focused one.
    readonly property Process stateProcess: Process {
        command: ["hyprctl", "--batch", "j/workspaces; j/monitors"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const firstEnd = text.indexOf("]")
                const secondStart = text.indexOf("[", firstEnd)
                if (firstEnd < 0 || secondStart < 0)
                    return
                const workspaces = root.parseJson(text.slice(0, firstEnd + 1))
                const monitors = root.parseJson(text.slice(secondStart))
                if (!Array.isArray(workspaces) || !Array.isArray(monitors))
                    return
                root.occupiedIds = workspaces
                    .filter(workspace => workspace.windows > 0)
                    .map(workspace => workspace.id)
                const active = {}
                for (const monitor of monitors) {
                    if (!monitor.activeWorkspace)
                        continue
                    active[monitor.name] = monitor.activeWorkspace.id
                    if (monitor.focused) {
                        root.focusedMonitor = monitor.name
                        root.activeId = monitor.activeWorkspace.id
                    }
                }
                root.activeByMonitor = active
            }
        }
    }

    readonly property Connections events: Connections {
        target: Hyprland

        function onRawEvent(event): void {
            switch (event.name) {
            case "workspace":
            case "workspacev2":
            case "createworkspace":
            case "createworkspacev2":
            case "destroyworkspace":
            case "destroyworkspacev2":
            case "openwindow":
            case "closewindow":
            case "movewindow":
            case "movewindowv2":
            case "focusedmon":
            case "focusedmonv2":
                if (event.name === "focusedmon" || event.name === "focusedmonv2") {
                    const parts = `${event.data}`.split(",")
                    if (parts[0] && parts[0] !== "") {
                        root.focusedMonitor = parts[0]
                        if (parts[1]) {
                            const wsId = parseInt(parts[1])
                            if (!isNaN(wsId)) {
                                root.activeId = wsId
                                const copy = Object.assign({}, root.activeByMonitor)
                                copy[parts[0]] = wsId
                                root.activeByMonitor = copy
                            }
                        }
                    }
                }
                root.refresh()
                if (root.watchClients || root.clients.length > 0)
                    root.loadClients()
                break
            case "moveworkspace":
            case "moveworkspacev2":
            case "monitoradded":
            case "monitoraddedv2":
            case "monitorremoved":
            case "monitorremovedv2":
                root.refresh()
                if (root.watchClients || root.clients.length > 0)
                    root.loadClients()
                break
            // Focus changes only affect the client list, and only watchers
            // need it; skipping it otherwise saves a process per alt-tab.
            case "activewindow":
            case "activewindowv2":
                if (event.name === "activewindowv2")
                    root.focusedAddress = event.data === "" ? "" : `0x${event.data}`
                if (root.watchClients)
                    root.loadClients()
                break
            }
        }
    }

    function parseJson(text: string): var {
        if (!text || text.trim() === "")
            return null
        try {
            return JSON.parse(text)
        } catch (error) {
            console.warn("Cannot parse the hyprctl response:", error)
            return null
        }
    }
}
