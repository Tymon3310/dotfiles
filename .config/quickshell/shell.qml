//@ pragma UseQApplication - Reloading bar config
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import "components"

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

    // Global Spotify track data (updated by spotify_status.py)
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

    // ── Active Window Filter ──────────────────────────────────────────────────
    // List of app class / title fragments to hide from the active window display.
    // Matching is case-insensitive; any partial match on class OR title hides the entry.
    // Examples: "firefox", "code", "kitty", "steam"
    property var windowTitleBlocklist: [
        "Private Browsing", "Incognito", "porn"
    ]

    // ── Native Notification Daemon ────────────────────────────────────────────
    // Kill swaync so we can own the org.freedesktop.Notifications D-Bus name
    Process {
        id: killSwaync
        command: ["pkill", "-x", "swaync"]
        running: true
    }

    NotificationServer {
        id: globalNotifServer
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        bodyMarkupSupported: true
        persistenceSupported: true

        onNotification: (notification) => {
            console.log("[NotificationServer] received notification: ID=" + notification.id + ", appName=" + notification.appName + ", summary=" + notification.summary);
            notification.tracked = true;
        }
    }

    NotificationHistory {
        id: globalNotifHistory
        notifServer: globalNotifServer
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

    // Process to run Spotify MPRIS listener daemon
    Process {
        id: spotifyListenerProcess
        command: ["/home/tymon/dotfiles/.config/quickshell/scripts/spotify_status.py"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    var data = JSON.parse(line);
                    if (data && !data.error) {
                        shellRoot.spotifyData = data;
                    }
                } catch (e) {
                    console.log("SpotifyListener JSON parse error: " + e + " for line: " + line);
                }
            }
        }
        stderr: SplitParser {
            onRead: (line) => {
                console.log("SpotifyListener STDERR: " + line);
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

    // Render the panel on all connected monitors dynamically
    Variants {
        model: Quickshell.screens
        delegate: Bar {
            // Pass global state explicitly to the delegate
            sysData: shellRoot.sysData
            spotifyData: shellRoot.spotifyData
            hyprlandData: shellRoot.hyprlandData
            windowTitleBlocklist: shellRoot.windowTitleBlocklist
            notifServer: globalNotifServer
            notifHistory: globalNotifHistory
        }
    }
}
