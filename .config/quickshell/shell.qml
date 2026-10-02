import Quickshell
import Quickshell.Io
import QtQuick
import "components"
import "parts/services"
import "parts/lock"

ShellRoot {
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
