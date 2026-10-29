import Quickshell
import Quickshell.Io
import QtQuick
import "components"
import "parts/services"
import "parts/lock"

ShellRoot {
    // The notification daemon is parts/services/NotificationService,
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
