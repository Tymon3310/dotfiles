import QtQuick
import Quickshell
import Quickshell.Wayland

import "../services"

// The compositor's lock surface via ext-session-lock protocol.
WlSessionLock {
    id: root

    locked: LockService.locked

    onSecureStateChanged: LockService.secure = root.secure

    WlSessionLockSurface {
        id: surface

        LockSurface {
            anchors.fill: parent
            screenName: (surface.screen && surface.screen.name) ? surface.screen.name : ""

            Component.onCompleted: {
                if (isActive)
                    claim()
            }

            onSubmitted: password => LockService.submit(password)
        }
    }
}
