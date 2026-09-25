pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

import "../theme"

// Session lock service: ext-session-lock with blurred per-monitor background,
// animated padlock, elegant clock, biopass face authentication, PAM password fallback, and power actions.
Singleton {
    id: root

    property bool locked: false
    property bool secure: false
    property bool authenticating: false
    property string message: ""
    property bool failed: false
    property bool leaving: false
    property bool awake: false

    // Which screen holds the active login input prompt (defaults to DP-1 or primary)
    property string activeScreen: "DP-1"

    readonly property int awakeFor: 30000

    function rouse(): void {
        if (!root.locked || root.leaving)
            return
        root.awake = true
        root.drowse.restart()
        if (root.biopassAvailable && !root.biopassRunning && !root.biopassVerified)
            root.triggerBiopass()
    }

    function setActiveScreen(name: string): void {
        if (name && name !== "")
            root.activeScreen = name
        root.rouse()
    }

    function rest(): void {
        root.drowse.stop()
        root.awake = false
        root.failed = false
        root.message = ""
    }

    readonly property Timer drowse: Timer {
        interval: root.awakeFor
        onTriggered: root.authenticating ? root.drowse.restart() : root.rest()
    }

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

    // ── BIOPASS (FACE AUTHENTICATION) ───────────────────────────────────────

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
                if (root.locked && !root.leaving) {
                    root.biopassFailed = true
                }
            }
        }
    }

    function triggerBiopass(): void {
        if (!root.locked || root.leaving || !root.biopassAvailable)
            return
        if (root.biopassRunning || root.biopassVerified)
            return
        root.biopassFailed = false
        biopassAuth.running = true
    }

    function cancelBiopass(): void {
        if (biopassAuth.running) {
            biopassAuth.kill()
        }
        root.biopassRunning = false
    }

    // ── LOCKING ─────────────────────────────────────────────────────────────

    // Wait for any open menus to finish retracting before capturing the screen
    readonly property Timer settleCaptureTimer: Timer {
        interval: Theme.durationIslandGone
        onTriggered: root.capture.running = true
    }

    function lock(): void {
        if (root.locked || root.settleCaptureTimer.running)
            return
        root.message = ""
        root.failed = false
        root.leaving = false
        root.biopassVerified = false
        root.biopassFailed = false
        root.rest()
        root.shotReady = false
        root.activeScreen = "DP-1"
        root.prepareLock()
        root.settleCaptureTimer.restart()
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
    }

    readonly property Process eraser: Process {
        command: ["sh", "-c", `rm -f '${root.shotDirectory}'/lock*.jpg`]
    }

    // ── AUTHENTICATING ──────────────────────────────────────────────────────

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

        root.failed = false
        root.message = ""

        if (!pam.responseRequired) {
            root.begin()
            root.message = "Not ready — press Enter again"
            return
        }

        root.authenticating = true
        pam.respond(password)
    }

    readonly property PamContext pam: PamContext {
        config: "login"

        onCompleted: result => {
            root.authenticating = false
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
            root.failed = true
            root.message = "Authentication unavailable"
            console.warn("PAM error:", error)
        }
    }

    // ── UNLOCKING ───────────────────────────────────────────────────────────

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
        }
    }
}
