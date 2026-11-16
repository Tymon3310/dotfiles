
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

import "../theme"

Singleton {
    id: root

    property bool locked: false
    property bool secure: false
    property bool leaving: false

    property bool awake: false
    readonly property Timer sleep: Timer {
        interval: 10000
        onTriggered: root.awake = false
    }

    function rouse(): void {
        root.awake = true
        root.sleep.restart()
        if (root.locked && !root.leaving && !root.biopassRunning && !root.biopassVerified && !root.authenticating) {
            root.triggerBiopass()
        }
    }

    function rest(): void {
        root.awake = false
        root.cancelBiopass()
        root.biopassFailed = false
        root.sleep.stop()
    }

    property string activeScreen: (Quickshell.screens.length > 0 && Quickshell.screens[0]) ? Quickshell.screens[0].name : "DP-1"
    function setActiveScreen(name: string): void {
        if (name && name.length > 0)
            root.activeScreen = name
    }


    readonly property string shotDirectory:
        `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/quickshell`
    property int shotSerial: 0
    property bool shotReady: false

    function shotSourceFor(screenName: string): string {
        if (!root.shotReady)
            return ""
        // Only per-output shots are taken; an unnamed surface borrows the
        // first screen's.
        const name = (screenName && screenName.length > 0) ? screenName
            : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")
        return `file://${root.shotDirectory}/lock-${name}.jpg?v=${root.shotSerial}`
    }

    // Hyprland keeps drawing the live desktop under the lock surface
    // (misc:session_lock_xray). When it does, the unlock fades the frozen
    // screenshot out onto the live desktop instead of cutting from it, so
    // nothing jumps when the surface lifts. Without it, fading would reveal
    // black, so the screenshot stays opaque until the cut. Read on every
    // lock, so a config change is picked up.
    property bool xray: false

    function loadXray(): void {
        HyprlandService.query("j/getoption misc:session_lock_xray", text => {
            try {
                const option = JSON.parse(text)
                root.xray = option.bool === true || option.int === 1
            } catch (error) {
                root.xray = false
            }
        })
    }

    signal unlocked()
    signal prepareLock()


    property bool biopassAvailable: false
    property bool biopassRunning: false
    property bool biopassVerified: false
    property bool biopassFailed: false
    property bool biopassStarting: false

    readonly property string currentUser: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""

    readonly property Process biopassProbe: Process {
        command: ["which", "biopass-helper"]
        onExited: (code, status) => {
            root.biopassAvailable = (code === 0)
        }
    }

    Component.onCompleted: {
        biopassProbe.running = true
        root.loadXray()
    }

    readonly property Process biopassAuth: Process {
        command: ["/usr/bin/biopass-helper", "auth", "-u", root.currentUser, "--service", "login"]

        onStarted: {
            root.biopassStarting = false
            root.biopassRunning = true
            root.biopassFailed = false
        }

        onExited: (code, status) => {
            root.biopassStarting = false
            root.biopassRunning = false
            if (code === 0) {
                root.biopassVerified = true
                root.biopassFailed = false
                root.release()
            } else {
                if (root.locked && !root.leaving && !root.authenticating) {
                    root.biopassFailed = true
                }
            }
        }
    }

    function triggerBiopass(): void {
        if (!root.locked || root.leaving || !root.biopassAvailable)
            return
        if (root.biopassStarting || root.biopassRunning || root.biopassVerified || root.authenticating)
            return
        // Set now, not in onStarted: a keypress triggers this twice in one
        // tick (rouse + the Space handler), and the second `running = true`
        // queued a fresh helper that started right as the unlock began —
        // a process spawn (UI stall) mid-animation, and the camera again.
        root.biopassStarting = true
        root.biopassFailed = false
        biopassAuth.running = true
    }

    function cancelBiopass(): void {
        if (biopassAuth.running) {
            biopassAuth.running = false
        }
        root.biopassRunning = false
        root.biopassStarting = false
    }


    // Wait for any open menus to finish retracting before capturing the screen
    readonly property Timer settleCaptureTimer: Timer {
        interval: Theme.durationIslandGone
        onTriggered: root.capture.running = true
    }

    property bool preparingLock: false

    function lock(): void {
        if (root.locked || root.settleCaptureTimer.running || root.preparingLock)
            return
        root.loadXray()
        root.rest()
        root.preparingLock = true
        root.prepareLock()
        settleCaptureTimer.restart()
    }

    // Screens known to the shell: avoids hyprctl+jq round-trips on the
    // latency-sensitive lock path.
    readonly property string perOutputCmds: Quickshell.screens.map(s => "timeout 2 grim -o '" + s.name + "' -t jpeg -q 85 '" + root.shotDirectory + "/lock-" + s.name + ".jpg' &").join(" ")

    // Capture each monitor in parallel, at its own resolution. The directory
    // is made (and stale shots cleared) first, so no grim races the mkdir.
    // No whole-desktop shot: nothing draws it, and it cost 20-50 ms a lock.
    readonly property Process capture: Process {
        command: ["sh", "-c",
            `mkdir -p '${root.shotDirectory}' && rm -f '${root.shotDirectory}'/lock*.jpg; `
            + `${root.perOutputCmds} wait; ls '${root.shotDirectory}'/lock-*.jpg >/dev/null 2>&1`]

        onExited: (code, status) => {
            root.shotSerial += 1
            root.shotReady = (code === 0)
            root.preparingLock = false
            root.locked = true
            root.begin()
        }
    }

    function forget(): void {
        root.shotReady = false
        // Spawning rm forks the shell (a UI stall); doing it at the cut froze
        // the unlock animations for ~120 ms. Wait until they have finished.
        root.eraseLater.restart()
        root.failed = false
        root.message = ""
    }

    readonly property Timer eraseLater: Timer {
        interval: 1500
        onTriggered: {
            if (!root.locked && !root.preparingLock)
                root.eraser.running = true
        }
    }

    readonly property Process eraser: Process {
        command: ["sh", "-c", `rm -f '${root.shotDirectory}'/lock*.jpg`]
    }


    property bool authenticating: false
    property bool failed: false
    property string message: ""
    property string pendingPassword: ""

    function begin(): void {
        if (pam.active)
            pam.abort()
        root.authenticating = false
        pam.start()
    }

    function submit(password: string): void {
        if (root.authenticating || root.leaving)
            return
        if (password === "")
            return

        root.cancelBiopass()

        root.failed = false
        root.message = ""

        if (!pam.active || !pam.responseRequired) {
            root.pendingPassword = password
            root.begin()
            return
        }

        root.authenticating = true
        pam.respond(password)
    }

    readonly property PamContext pam: PamContext {
        config: "system-auth"

        onResponseRequiredChanged: {
            if (pam.responseRequired && root.pendingPassword !== "") {
                const pass = root.pendingPassword
                root.pendingPassword = ""
                root.authenticating = true
                pam.respond(pass)
            }
        }

        onCompleted: result => {
            root.authenticating = false
            root.pendingPassword = ""
            if (result === PamResult.Success) {
                root.release()
                return
            }
            if (root.leaving)
                return
            root.failed = true
            root.message = (result === PamResult.MaxTries)
                ? "Too many attempts"
                : "Wrong password"
            root.begin()
        }

        onError: error => {
            root.authenticating = false
            root.pendingPassword = ""
            root.failed = true
            root.message = "Authentication unavailable"
            console.warn("PAM error:", error)
        }
    }


    function release(): void {
        if (root.leaving)
            return
        root.leaving = true
        root.cancelBiopass()
        root.leave.restart()
    }

    readonly property Timer leave: Timer {
        // The release runs OutCubic over durationMorph (LockSurface `held`),
        // which is visually done by 80% of it (under 1% left). Lifting the
        // surface there hands input back ~120 ms sooner, with nothing to see.
        interval: Math.round(Theme.durationMorph * 0.8)
        onTriggered: {
            if (root.pam.active)
                root.pam.abort()
            root.cancelBiopass()
            root.locked = false
            root.biopassVerified = false
            root.biopassFailed = false
            root.rest()
            root.forget()
            root.unlocked()
            root.leaving = false
        }
    }
}
