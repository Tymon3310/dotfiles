// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E S S I O N   S E R V I C E                                          │
// │   lock, suspend, log out, reboot, shut down                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Session actions as data, rendered from one list. `destructive` marks the
// ones that end the session; PowerRow asks for confirmation, not this service.
Singleton {
    id: root

    readonly property var actions: [
        { id: "lock",     icon: "󰌾", label: "Lock",      destructive: false },
        { id: "suspend",  icon: "󰤄", label: "Suspend",   destructive: false },
        { id: "logout",   icon: "󰗽", label: "Log out",   destructive: true },
        { id: "reboot",   icon: "󰜉", label: "Restart",   destructive: true },
        { id: "shutdown", icon: "󰐥", label: "Shut down", destructive: true }
    ]

    // Suspend waits for the compositor to confirm the lock covers the screen,
    // so the machine never wakes showing the desktop. Asking hypridle's
    // before_sleep hook to lock instead races the suspend: the lock first
    // retracts the island and takes a screenshot. No confirmation within
    // eight seconds means no suspend.
    property bool suspendWhenLocked: false

    readonly property Timer suspendGiveUp: Timer {
        interval: 8000
        onTriggered: {
            if (!root.suspendWhenLocked)
                return
            root.suspendWhenLocked = false
            console.warn("The session did not lock; not suspending.")
        }
    }

    readonly property Connections lockWatch: Connections {
        target: LockService

        function onSecureChanged(): void {
            if (!LockService.secure || !root.suspendWhenLocked)
                return
            root.suspendWhenLocked = false
            root.suspendGiveUp.stop()
            root.exec(["systemctl", "suspend"])
        }
    }

    function run(actionId: string): void {
        switch (actionId) {
        case "lock":
            LockService.lock()
            break
        case "suspend":
            // Already covered (locked by hand or by idle): straight to sleep.
            if (LockService.secure) {
                root.exec(["systemctl", "suspend"])
                break
            }
            root.suspendWhenLocked = true
            root.suspendGiveUp.restart()
            LockService.lock()
            break
        case "logout":
            Hyprland.dispatch("hl.dsp.exit()")
            break
        case "reboot":
            root.exec(["systemctl", "reboot"])
            break
        case "shutdown":
            root.exec(["systemctl", "--ignore-inhibitors", "poweroff"])
            break
        default:
            console.warn("Unknown session action:", actionId)
        }
    }

    // Detached, so a reboot outlives a shell reload.
    function exec(command: var): void {
        Quickshell.execDetached(command)
    }
}
