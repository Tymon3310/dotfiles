import Quickshell
import Quickshell.Io
import QtQuick
import "island"
import "components"
import "screenshot"
import "services"
import "lock"

ShellRoot {
    // The notification daemon is services/NotificationService,
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
