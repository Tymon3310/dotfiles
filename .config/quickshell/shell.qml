// pragma UseQApplication - Reloading bar config
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import "components"
import "parts/services"
import "parts/lock"
import "screenshot/src"

ShellRoot {
    id: shellRoot

    // Global system metrics data (updated by sys_monitor.py)
    property var sysData: ({
        "cpu": 0.0,
        "ram": 0.0,
        "gpu": 0.0,
        "vram_used_gib": 0.0,
        "vram_total_gib": 0.0,
        "net_rx": "0 B/s",
        "net_tx": "0 B/s",
        "cpu_cores": [],
        "cpu_ghz": 0.0,
        "cpu_procs": [],
        "mem_procs": [],
        "gpu_procs": [],
        "gpu_sclk": 0,
        "gpu_mclk": 0,
        "gpu_temp": 0.0,
        "gpu_temp_junction": 0.0,
        "gpu_temp_mem": 0.0,
        "cpu_temp": 0.0,
        "ping_gateway": -1.0,
        "ping_cloudflare": -1.0,
        "ping_google": -1.0
    })

    // Global media track data (updated by media_status.py)
    property var spotifyData: ({
        "title": "",
        "artist": "",
        "album": "",
        "artUrl": "",
        "position": 0,
        "length": 0,
        "status": "Stopped",
        "loop": "Off",
        "shuffle": false,
        "volume": 0.5,
        "playerName": "",
        "queue": [],
        "isrc": "",
        "contextName": ""
    })

    // Global Hyprland status data per monitor (updated by hypr_monitor.py)
    property var hyprlandData: ({})

    // ── Active Window Filter ─────────────────────────────────────────────
    // List of app class / title fragments to hide from the active window display.
    // Matching is case-insensitive; any partial match on class OR title hides the entry.
    // Examples: "firefox", "code", "kitty", "steam"
    property var windowTitleBlocklist: [
        "Private Browsing", "Incognito", "porn"
    ]

    // ── Notification Daemon ──────────────────────────────────────────────
    // Kill swaync so NotificationService can own org.freedesktop.Notifications
    Process {
        id: killSwaync
        command: ["pkill", "-x", "swaync"]
        running: true
    }

    // The notification daemon is impasto's NotificationService (parts/),
    // shown in the island by IslandBar. Singletons are built on first use, so
    // it is touched here to own the name from startup.
    Component.onCompleted: void NotificationService.server

    // "Up next" in the island's player, from media_status.py's Spotify Web
    // API queue (MPRIS has none).
    Binding {
        target: MediaService
        property: "queue"
        value: shellRoot.spotifyData.queue ?? []
    }

    // Process to run system stats daemon
    Process {
        id: sysMonitorProcess
        command: ["/home/tymon/dotfiles/.config/quickshell/scripts/sys_monitor.py"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    var data = JSON.parse(line);
                    if (data && !data.error) {
                        shellRoot.sysData = data;
                    }
                } catch (e) {
                    console.log("SysMonitor JSON parse error: " + e + " for line: " + line);
                }
            }
        }
        stderr: SplitParser {
            onRead: (line) => {
                console.log("SysMonitor STDERR: " + line);
            }
        }
    }

    // Process to run media status listener daemon (Spotify + Radio Eska)
    Process {
        id: mediaListenerProcess
        command: ["/home/tymon/dotfiles/.config/quickshell/scripts/media_status.py"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    var data = JSON.parse(line);
                    if (data && !data.error) {
                        shellRoot.spotifyData = data;
                    }
                } catch (e) {
                    console.log("MediaListener JSON parse error: " + e + " for line: " + line);
                }
            }
        }
        stderr: SplitParser {
            onRead: (line) => {
                console.log("MediaListener STDERR: " + line);
            }
        }
    }

    // Process to run Hyprland IPC monitor daemon
    Process {
        id: hyprMonitorProcess
        command: ["/home/tymon/dotfiles/.config/quickshell/scripts/hypr_monitor.py"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    var data = JSON.parse(line);
                    if (data && !data.error) {
                        shellRoot.hyprlandData = data;
                    }
                } catch (e) {
                    console.log("HyprMonitor JSON parse error: " + e + " for line: " + line);
                }
            }
        }
        stderr: SplitParser {
            onRead: (line) => {
                console.log("HyprMonitor STDERR: " + line);
            }
        }
    }

    // Render the panel on all connected monitors dynamically.
    // One island in the middle (IslandBar.qml). The old bar is still in
    // Bar.qml, but it needs the NotificationServer and NotificationHistory
    // this file used to have (see git history).
    Variants {
        model: Quickshell.screens
        delegate: IslandBar {}
    }

    // ── Session Lock Screen ──────────────────────────────────────────────
    LockScreen {}

    IpcHandler {
        target: "lock"
        function trigger(): void {
            LockService.lock()
        }
    }

    // ── Screenshot Tool Dynamic Loader ───────────────────────────────────
    Loader {
        id: screenshotLoader
        active: false

        property string envId: ""
        property string modeOverride: ""
        property string instantOverride: ""

        source: Qt.resolvedUrl("screenshot/shell.qml")

        onLoaded: {
            console.log("[MainShell] Screenshot tool QML loaded dynamically")
            item.isLoadedDynamically = true
            if (envId) {
                item.externalTimestamp = envId
            }
            if (modeOverride) {
                item.mode = modeOverride
            }
            if (instantOverride === "1") {
                item.instantCapture = true
            }
            item.initializeCapture()
        }
    }

    Connections {
        target: screenshotLoader.item
        ignoreUnknownSignals: true
        function onFinished() {
            console.log("[MainShell] Screenshot tool finished, unloading component")
            screenshotLoader.active = false
            // Clear properties
            screenshotLoader.envId = ""
            screenshotLoader.modeOverride = ""
            screenshotLoader.instantOverride = ""
        }
    }

    IpcHandler {
        target: "screenshot"

        function trigger(envId: string, mode: string, instant: string): void {
            console.log("[MainShell] IPC call received: screenshot trigger")
            // Set properties first, then activate the loader
            screenshotLoader.envId = envId
            screenshotLoader.modeOverride = mode
            screenshotLoader.instantOverride = instant
            screenshotLoader.active = true
        }
    }
}
