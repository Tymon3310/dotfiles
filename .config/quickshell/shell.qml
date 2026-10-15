import Quickshell
import Quickshell.Io
import QtQuick
import "components"
import "parts/services"
import "parts/lock"

ShellRoot {
    // Main-thread stall watchdog: logs event-loop gaps (quiet otherwise).
    // Used to hunt hitches in the lock transition; useful anywhere.
    Timer {
        interval: 10
        repeat: true
        running: true
        property real last: 0
        onTriggered: {
            const now = Date.now()
            if (last > 0 && now - last > 75)
                console.info("[lock-t] main-thread stall " + Math.round(now - last) + "ms")
            last = now
        }
    }

    // ── Notification Daemon ──────────────────────────────────────────
    // Kill swaync so NotificationService can own org.freedesktop.Notifications
    Process {
        command: ["pkill", "-x", "swaync"]
        running: true
    }

    // The notification daemon is impasto's NotificationService (parts/),
    // shown in the island by IslandBar. Singletons are built on first use, so
    // it is touched here to own the name from startup.
    Component.onCompleted: void NotificationService.server

    // Render the panel on all connected monitors dynamically (IslandBar)
    Variants {
        model: Quickshell.screens
        delegate: IslandBar {}
    }

    // Fullscreen heads-up notification overlay on all connected monitors
    Variants {
        model: Quickshell.screens
        delegate: NotificationHeadsUp {}
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

    ScreenshotLauncher {}
}
