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

    // The dotfiles' own commands (nwg-bar, hypridle) rather than impasto's
    // lock screen: hypridle locks before sleeping, so suspend needs no wait.
    function run(actionId: string): void {
        switch (actionId) {
        case "lock":
            root.exec(["sh", "-c", "pidof hyprlock || hyprlock"])
            break
        case "suspend":
            root.exec(["systemctl", "suspend"])
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

    // Detached, so the lock or a reboot outlives a shell reload.
    function exec(command: var): void {
        Quickshell.execDetached(command)
    }
}
