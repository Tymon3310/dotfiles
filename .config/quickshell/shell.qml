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

    // ── Notification Daemon ──────────────────────────────────────────
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

    property int mediaRestartAttempts: 0

    Timer {
        id: mediaRestartTimer
        interval: Math.min(30000, 2500 * Math.pow(2, Math.min(shellRoot.mediaRestartAttempts, 5)))
        repeat: false
        onTriggered: mediaListenerProcess.running = true
    }

    // Process to run media status listener daemon (Spotify + Radio Eska)
    Process {
        id: mediaListenerProcess
        command: ["python3", "-u", Quickshell.shellPath("scripts/media_status.py")]
        running: true
        onExited: (code, status) => {
            shellRoot.mediaRestartAttempts++
            console.log("MediaListener exited, restarting in " + (mediaRestartTimer.interval / 1000) + "s...")
            mediaRestartTimer.restart()
        }
        stdout: SplitParser {
            onRead: (line) => {
                shellRoot.mediaRestartAttempts = 0
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

    // Render the panel on all connected monitors dynamically (IslandBar)
    Variants {
        model: Quickshell.screens
        delegate: IslandBar {}
    }

    // Fullscreen cinematic fade-to-black on all monitors during logout / reboot / shutdown
    Variants {
        model: Quickshell.screens
        delegate: SessionFadeWindow {}
    }

    // ── Session Lock Screen ──────────────────────────────────────────
    LockScreen {}

    IpcHandler {
        target: "lock"
        function trigger(): void {
            LockService.lock()
        }
    }

    // ── Screenshot Tool Dynamic Loader ───────────────────────────────
    Loader {
        id: screenshotLoader
        active: false

        property string envId: ""
        property string modeOverride: ""
        property string instantOverride: ""
        property string geomOverride: ""

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
            if (geomOverride) {
                item.externalGeom = geomOverride
            }
            item.initializeCapture()
        }
    }

    // Connect screenshot finished signal
    Connections {
        target: screenshotLoader.item
        ignoreUnknownSignals: true
        function onFinished() {
            console.log("[MainShell] Screenshot finished signal received, unloading")
            screenshotLoader.active = false
            screenshotLoader.envId = ""
            screenshotLoader.modeOverride = ""
            screenshotLoader.instantOverride = ""
            screenshotLoader.geomOverride = ""
        }
    }

    IpcHandler {
        target: "screenshot"

        function trigger(envId: string, mode: string, instant: string): void {
            console.log("[MainShell] Screenshot IPC triggered:", envId, mode, instant)
            screenshotLoader.envId = envId
            screenshotLoader.modeOverride = mode
            screenshotLoader.instantOverride = instant
            if (!screenshotLoader.active) {
                screenshotLoader.active = true
            } else if (screenshotLoader.item) {
                if (envId) screenshotLoader.item.externalTimestamp = envId
                if (mode) screenshotLoader.item.mode = mode
                screenshotLoader.item.instantCapture = (instant === "1")
                screenshotLoader.item.initializeCapture()
            }
        }

        function open(): void {
            trigger("", "region", "0")
        }

        function instant(geomStr: string): void {
            console.log("[MainShell] Instant Screenshot IPC triggered with geom:", geomStr)
            screenshotLoader.modeOverride = "region"
            screenshotLoader.instantOverride = "1"
            screenshotLoader.geomOverride = geomStr || ""
            if (!screenshotLoader.active) {
                screenshotLoader.active = true
            } else if (screenshotLoader.item) {
                if (geomStr) screenshotLoader.item.externalGeom = geomStr
                screenshotLoader.item.instantCapture = true
                screenshotLoader.item.initializeCapture()
            }
        }

        function window(): void {
            console.log("[MainShell] Window Screenshot IPC triggered")
            screenshotLoader.modeOverride = "window"
            screenshotLoader.instantOverride = "0"
            if (!screenshotLoader.active) {
                screenshotLoader.active = true
            } else if (screenshotLoader.item) {
                screenshotLoader.item.mode = "window"
                screenshotLoader.item.instantCapture = false
                screenshotLoader.item.initializeCapture()
            }
        }

        function screen(): void {
            console.log("[MainShell] Screen Screenshot IPC triggered")
            screenshotLoader.modeOverride = "screen"
            screenshotLoader.instantOverride = "0"
            if (!screenshotLoader.active) {
                screenshotLoader.active = true
            } else if (screenshotLoader.item) {
                screenshotLoader.item.mode = "screen"
                screenshotLoader.item.instantCapture = false
                screenshotLoader.item.initializeCapture()
            }
        }

        function ocr(): void {
            console.log("[MainShell] OCR Screenshot IPC triggered")
            screenshotLoader.modeOverride = "ocr"
            screenshotLoader.instantOverride = "0"
            if (!screenshotLoader.active) {
                screenshotLoader.active = true
            } else if (screenshotLoader.item) {
                screenshotLoader.item.mode = "ocr"
                screenshotLoader.item.instantCapture = false
                screenshotLoader.item.initializeCapture()
            }
        }

        function lens(): void {
            console.log("[MainShell] Lens Screenshot IPC triggered")
            screenshotLoader.modeOverride = "lens"
            screenshotLoader.instantOverride = "0"
            if (!screenshotLoader.active) {
                screenshotLoader.active = true
            } else if (screenshotLoader.item) {
                screenshotLoader.item.mode = "lens"
                screenshotLoader.item.instantCapture = false
                screenshotLoader.item.initializeCapture()
            }
        }

        function ai(): void {
            console.log("[MainShell] AI Screenshot IPC triggered")
            screenshotLoader.modeOverride = "ai"
            screenshotLoader.instantOverride = "0"
            if (!screenshotLoader.active) {
                screenshotLoader.active = true
            } else if (screenshotLoader.item) {
                screenshotLoader.item.mode = "ai"
                screenshotLoader.item.instantCapture = false
                screenshotLoader.item.initializeCapture()
            }
        }
    }
}
