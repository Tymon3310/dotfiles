import Quickshell
import Quickshell.Io
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
        "net_tx": "0 B/s"
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
        "playerName": ""
    })

    // Global Hyprland status data per monitor (updated by hypr_monitor.py)
    property var hyprlandData: ({})

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
        }
    }
}
