// ╭────────────────────────────────────────────────────────────────────────────╮
// │                                                                            │
// │   L O C K   S E R V I C E                                                  │
// │   session lock coordination, grim capture, PAM, biopass face auth          │
// │                                                                            │
// │   github.com/andreumassanet/impasto                                        │
// │                                                                            │
// ╰────────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

import "../theme"

// Coordinates the session lock: takes a blurred screenshot with grim and
// convert before showing the surface, runs PAM authentication, and holds the
// surface up for `Theme.durationMorph` while the unlock animation finishes.
Singleton {
    id: root

    property bool locked: false
    property bool secure: false
    property bool leaving: false

    property bool awake: true
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
        root.sleep.stop()
    }

    property string activeScreen: "DP-1"
    function setActiveScreen(name: string): void {
        if (name && name.length > 0)
            root.activeScreen = name
    }

    // ── SCREENSHOT ───────────────────────────────────────────────────────────

    readonly property string shotDirectory:
        `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/quickshell`
    property int shotSerial: 0
    property bool shotReady: false

    function shotSourceFor(screenName: string): string {
        if (!root.shotReady)
            return ""
        if (screenName && screenName.length > 0)
            return `file://${root.shotDirectory}/lock-${screenName}.jpg?v=${root.shotSerial}`
        return `file://${root.shotDirectory}/lock.jpg?v=${root.shotSerial}`
    }

    signal unlocked()
    signal prepareLock()

    // ── BIOPASS (FACE AUTHENTICATION) ────────────────────────────────────────

    property bool biopassAvailable: false
    property bool biopassRunning: false
    property bool biopassVerified: false
    property bool biopassFailed: false

    readonly property string currentUser: Quickshell.env("USER") || "tymon"

    readonly property Process biopassProbe: Process {
        command: ["which", "biopass-helper"]
        onExited: (code, status) => {
            root.biopassAvailable = (code === 0)
        }
    }

    Component.onCompleted: {
        biopassProbe.running = true
    }

    readonly property Process biopassAuth: Process {
        command: ["/usr/bin/biopass-helper", "auth", "-u", root.currentUser, "--service", "login"]

        onStarted: {
            root.biopassRunning = true
            root.biopassFailed = false
        }

        onExited: (code, status) => {
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
        if (root.biopassRunning || root.biopassVerified || root.authenticating)
            return
        root.biopassFailed = false
        biopassAuth.running = true
    }

    function cancelBiopass(): void {
        if (biopassAuth.running) {
            biopassAuth.running = false
        }
        root.biopassRunning = false
    }

    // ── LOCKING ──────────────────────────────────────────────────────────────

    // Wait for any open menus to finish retracting before capturing the screen
    readonly property Timer settleCaptureTimer: Timer {
        interval: Theme.durationIslandGone
        onTriggered: root.capture.running = true
    }

    function lock(): void {
        if (root.locked || root.settleCaptureTimer.running)
            return
        root.prepareLock()
        settleCaptureTimer.restart()
    }

    // Capture each monitor independently in parallel for crisp per-output resolution
    readonly property Process capture: Process {
        command: ["sh", "-c",
            `mkdir -p '${root.shotDirectory}' && timeout 2 grim -t jpeg -q 85 '${root.shotDirectory}/lock.jpg' & for s in $(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null); do timeout 2 grim -o "$s" -t jpeg -q 85 '${root.shotDirectory}/lock-'$s'.jpg' & done; wait`]

        onExited: (code, status) => {
            root.shotSerial += 1
            root.shotReady = code === 0
            root.locked = true
            root.begin()
            root.triggerBiopass()
        }
    }

    function forget(): void {
        root.shotReady = false
        root.eraser.running = true
        root.failed = false
        root.message = ""
    }

    readonly property Process eraser: Process {
        command: ["sh", "-c", `rm -f '${root.shotDirectory}'/lock*.jpg`]
    }

    // ── PAM AUTHENTICATION ───────────────────────────────────────────────────

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

        // Cancel background face unlock immediately when submitting password
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
        config: "login"

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

    // ── UNLOCKING ────────────────────────────────────────────────────────────

    function release(): void {
        if (root.leaving)
            return
        root.leaving = true
        root.cancelBiopass()
        root.leave.restart()
    }

    readonly property Timer leave: Timer {
        interval: Theme.durationMorph
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
