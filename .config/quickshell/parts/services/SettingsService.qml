// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E T T I N G S   S E R V I C E                                        │
// │   the few preferences the extracted parts read                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell

// Stand-in for impasto's SettingsService: only the keys the parts under
// `parts/` read, as plain properties. Nothing is saved; assign a property
// (`SettingsService.barHeight = 30`) or call `set()` to change it for this run.
Singleton {
    id: root

    readonly property string stateDirectory:
        `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell`

    // ── BAR ─────────────────────────────────────────────────────────────

    // Matches the dotfiles bar (30 px, attached to the top edge).
    property int barHeight: 30
    property int barMargin: 0

    // ── CLOCK ───────────────────────────────────────────────────────────

    property string clockFormat: "HH:mm"
    property bool clockShowsDate: false
    property bool clockShowsSeconds: false

    // ── WORKSPACES ──────────────────────────────────────────────────────

    // Dots always shown; the ones past it appear while occupied.
    property int workspaceCount: 5
    property int workspaceMax: 20

    // Workspaces each monitor owns, in order: 1–20 on the first monitor,
    // 21–40 on the second. The bar on each screen shows its own block.
    property int workspacesPerMonitor: 20

    // ── NOTIFICATIONS ───────────────────────────────────────────────────

    property bool doNotDisturb: false
    property int notificationTimeout: 5000

    // ── WEATHER ─────────────────────────────────────────────────────────

    // Empty: wttr.in guesses from the IP address.
    property string weatherPlace: ""

    // ── CHIPS ───────────────────────────────────────────────────────────

    // "icon" (glyph and figure) or "ring" (the module's gauge); see ChipFace.
    property string chipShape: "icon"

    // ── LOOK ────────────────────────────────────────────────────────────

    property string fontFamily: "Google Sans"
    property string fontMono: "Google Sans Code NF"
    property int motionScale: 100
    property string motionCurve: "OutCubic"

    // Read by Theme only; kept so it resolves.
    property bool notesHandwriting: false
    property int dockIconSize: 44

    // ── LOCK SCREEN ─────────────────────────────────────────────────────

    property string lockClock: "inline" // "inline" or "stacked"
    property real lockBlur: 48.0
    property string userName: ""
    property string userAvatar: ""

    function set(key: string, value: var): void {
        if (key in root)
            root[key] = value
        else
            console.warn("SettingsService: unknown key", key)
    }
}
