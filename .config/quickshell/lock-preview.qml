// Shows the lock screen on one monitor without locking the session, for
// working on its design. A separate Quickshell instance:
//
//   qs -p ~/.config/quickshell/lock-preview.qml
//
// Env: LOCK_PREVIEW_SCREEN (default DP-2), LOCK_PREVIEW_ACTIVE (the screen
// you unlock from, default the previewed one), LOCK_PREVIEW_AWAKE=1 to show the
// password field, LOCK_PREVIEW_LOOP=1 to play the lock and unlock
// transitions over and over. Closes on a right click, or by itself after a
// minute.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "parts/lock"
import "parts/services"

ShellRoot {
    id: root

    readonly property string screenName: Quickshell.env("LOCK_PREVIEW_SCREEN") || "DP-2"
    readonly property bool startAwake: Quickshell.env("LOCK_PREVIEW_AWAKE") === "1"
    readonly property bool loop: Quickshell.env("LOCK_PREVIEW_LOOP") === "1"

    // The lock draws a screenshot of the desktop under it.
    Process {
        running: true
        command: ["sh", "-c", `mkdir -p '${LockService.shotDirectory}' && grim -o '${root.screenName}' -t jpeg -q 85 '${LockService.shotDirectory}/lock-${root.screenName}.jpg'`]
        onExited: {
            // LOCK_PREVIEW_ACTIVE: another screen is the one you unlock
            // from, to see this one's side part (stage or info).
            LockService.setActiveScreen(Quickshell.env("LOCK_PREVIEW_ACTIVE") || root.screenName)
            LockService.shotSerial += 1
            LockService.shotReady = true
            window.visible = true
            surface.active = true
            if (root.startAwake)
                awakeLater.start()
            if (root.loop)
                cycle.start()
        }
    }

    Timer {
        id: awakeLater
        interval: 600
        onTriggered: LockService.rouse()
    }

    // Locked for a while, then the unlock (LockSurface follows
    // LockService.leaving), then a fresh lock.
    SequentialAnimation {
        id: cycle
        loops: Animation.Infinite
        PauseAnimation { duration: 2500 }
        ScriptAction { script: LockService.leaving = true }
        PauseAnimation { duration: 900 }
        ScriptAction {
            script: {
                surface.active = false
                LockService.leaving = false
                surface.active = true
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        onTriggered: Qt.quit()
    }

    PanelWindow {
        id: window

        visible: false
        screen: Quickshell.screens.find(s => s.name === root.screenName) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        // Like the real lock surface: the unlock fades out onto the desktop.
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-lock-preview"
        // Takes the keyboard only when asked to show the password field, so
        // typing elsewhere doesn't land here (and move the active screen).
        WlrLayershell.keyboardFocus: root.startAwake ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        // Built once the screenshot is ready and the window is up, so the
        // entry animation plays on screen.
        Loader {
            id: surface
            anchors.fill: parent
            active: false
            sourceComponent: LockSurface {
                screenName: root.screenName
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: Qt.quit()
        }
    }
}
