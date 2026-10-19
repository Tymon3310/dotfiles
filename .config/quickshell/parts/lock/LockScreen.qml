import QtQuick
import Quickshell
import Quickshell.Wayland

import "../services"

Scope {
    id: lockScope

    // Immediate input blocker overlay while island is retracting and grim is capturing
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            property var modelData
            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: LockService.preparingLock
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            visible: LockService.preparingLock
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.AllButtons
                onPressed: (mouse) => mouse.accepted = true
            }
        }
    }

    // The compositor's lock surface via ext-session-lock protocol.
    WlSessionLock {
        id: root

        locked: LockService.locked

        onSecureStateChanged: LockService.secure = root.secure

        WlSessionLockSurface {
            id: surface

            // The default is white. The unlock fades the frozen frame out
            // onto the live desktop (session_lock_xray), so whatever is left
            // behind it must be see-through, or it flashes white at the end.
            // While locked, LockSurface's own opaque base covers everything.
            color: "transparent"

            LockSurface {
                anchors.fill: parent
                screenName: (surface.screen && surface.screen.name) ? surface.screen.name : ""

                Component.onCompleted: {
                    if (isActive && LockService.awake)
                        claim()
                }

                onSubmitted: password => LockService.submit(password)
            }
        }
    }
}
