// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E S S I O N   S E R V I C E                                          │
// │   lock, log out, reboot, shut down                                       │
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
        { id: "logout",   icon: "󰗽", label: "Log out",   destructive: true },
        { id: "reboot",   icon: "󰜉", label: "Restart",   destructive: true },
        { id: "shutdown", icon: "󰐥", label: "Shut down", destructive: true }
    ]

    property bool fadingOut: false
    property string pendingAction: ""
    readonly property int fadeDuration: 600

    readonly property Timer commitActionTimer: Timer {
        interval: root.fadeDuration
        repeat: false
        onTriggered: {
            root.commitPendingAction()
        }
    }

    // Safety watchdog: if polkit denies or action fails, restore screen after 15 seconds
    readonly property Timer fadeSafetyTimer: Timer {
        interval: 15000
        repeat: false
        onTriggered: {
            if (root.fadingOut) {
                console.warn("Session action timed out or failed; restoring screen.")
                root.fadingOut = false
                root.pendingAction = ""
            }
        }
    }

    function cancel(): void {
        root.commitActionTimer.stop()
        root.fadeSafetyTimer.stop()
        root.pendingAction = ""
        root.fadingOut = false
    }

    function run(actionId: string): void {
        switch (actionId) {
        case "lock":
            LockService.lock()
            break
        case "logout":
        case "reboot":
        case "reboot-uefi":
        case "shutdown":
            root.pendingAction = actionId
            root.fadingOut = true
            root.commitActionTimer.restart()
            root.fadeSafetyTimer.restart()
            break
        default:
            console.warn("Unknown session action:", actionId)
        }
    }

    function commitPendingAction(): void {
        const action = root.pendingAction
        root.pendingAction = ""
        switch (action) {
        case "logout":
            Hyprland.dispatch("hl.dsp.exit()")
            break
        case "reboot":
            root.exec(["sh", "-c", "busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager SetRebootToFirmwareSetup b false 2>/dev/null; systemctl reboot"])
            break
        case "reboot-uefi":
            root.exec(["systemctl", "reboot", "--firmware-setup"])
            break
        case "shutdown":
            root.exec(["sh", "-c", "busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager SetRebootToFirmwareSetup b false 2>/dev/null; systemctl --ignore-inhibitors poweroff"])
            break
        default:
            break
        }
    }

    // Detached, so a reboot outlives a shell reload.
    function exec(command: var): void {
        Quickshell.execDetached(command)
    }
}
