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
                console.info("[lock-t] main-thread stall " + Math.round(now - last) + "ms at "
                    + Qt.formatTime(new Date(last), "hh:mm:ss.zzz"))
            last = now
        }
    }

    // Kill swaync so NotificationService can own org.freedesktop.Notifications
    Process {
        command: ["pkill", "-x", "swaync"]
        running: true
    }

    // The notification daemon is impasto's NotificationService (parts/),
    // shown in the island by IslandBar. Singletons are built on first use, so
    // it is touched here to own the name from startup.
    Component.onCompleted: void NotificationService.server

    Variants {
        model: Quickshell.screens
        delegate: IslandBar {}
    }

    Variants {
        model: Quickshell.screens
        delegate: NotificationHeadsUp {}
    }

    Variants {
        model: Quickshell.screens
        delegate: SessionFadeWindow {}
    }

    LockScreen {}

    IpcHandler {
        target: "lock"
        function trigger(): void {
            LockService.lock()
        }
    }

    ScreenshotLauncher {}
}
