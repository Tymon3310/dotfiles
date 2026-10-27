// github.com/andreumassanet/impasto

pragma Singleton

import QtQuick
import Quickshell

// Stand-in for impasto's SettingsService: only the keys the parts under
// `parts/` read, as plain properties. Nothing is saved; assign a property
// (`SettingsService.barHeight = 30`) or call `set()` to change it for this run.
Singleton {
    id: root


    property int barHeight: 30
    property int barMargin: 4


    property string clockFormat: "HH:mm"


    // Dots always shown; the ones past it appear while occupied.
    property int workspaceCount: 5
    property int workspaceMax: 20

    // Workspaces each monitor owns, in order: 1–20 on the first monitor,
    // 21–40 on the second. The bar on each screen shows its own block.
    property int workspacesPerMonitor: 20


    property int notificationTimeout: 5000
    // "fullscreen" (default: show sleek heads-up overlay banner when on fullscreen)
    // "always"     (always show heads-up overlay banner for all notifications)
    // "never"      (never show heads-up banner, only classic island notch)
    property string notificationHeadsUpMode: "fullscreen"


    // Empty: wttr.in guesses from the IP address.
    property string weatherPlace: ""


    property string fontFamily: "Google Sans"
    property string fontMono: "Google Sans Code NF"
    property int motionScale: 100
    property string motionCurve: "OutCubic"


    property string lockClock: "inline" // "inline" or "stacked"
    property real lockBlur: 48.0
    property string userName: ""
    property string userAvatar: ""


    // Global lyrics offset in milliseconds (+ shifts lyrics earlier, - shifts lyrics later).
    property int lyricsOffset: 0

    property bool mediaPreferQueue: false

    function set(key: string, value: var): void {
        if (key in root)
            root[key] = value
        else
            console.warn("SettingsService: unknown key", key)
    }
}
