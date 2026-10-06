pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Owns screen recording via gpu-screen-recorder and exposes the state
// (recording / paused / elapsed) to the island indicator.
Singleton {
    id: root

    property bool recording: false
    property bool paused: false
    property int elapsed: 0
    property string outputPath: ""
    // Audio sources of the current recording (fixed at launch by gsr).
    property bool audioSystem: true
    property bool audioMic: false
    property bool starting: false
    property var pendingStart: null

    readonly property string elapsedText: {
        const s = root.elapsed
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const sec = s % 60
        const mm = h > 0 ? String(m).padStart(2, "0") : String(m)
        const ss = String(sec).padStart(2, "0")
        return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`
    }

    readonly property string videosDir: (Quickshell.env("HOME") || "/tmp") + "/Videos"
    readonly property string pathFile: "/tmp/qs-screenrecording-path"
    readonly property string saveHook: Quickshell.shellPath("parts/scripts/recording-saved.sh")

    function start(region: string, systemAudio: string, mic: string): void {
        if (root.recording || root.starting) {
            Quickshell.execDetached(["notify-send", "Screen Recorder", "Already recording", "-a", "Screen Recorder"])
            return
        }
        const m = (region || "").trim().match(/^(\d+)x(\d+)\+(-?\d+)\+(-?\d+)$/)
        if (!m) {
            console.warn("[Recorder] Invalid region:", region)
            return
        }
        // Physical single-instance guard: confirm no recorder process exists
        // before launching (in-memory state is lost across shell reloads).
        root.pendingStart = { region: `${m[1]}x${m[2]}+${m[3]}+${m[4]}`, systemAudio: systemAudio, mic: mic }
        root.starting = true
        if (!root.check.running)
            root.check.running = true
    }

    function finishStartCheck(found: bool): void {
        const p = root.pendingStart
        root.pendingStart = null
        root.starting = false
        if (found) {
            // Adopt the running recording instead of doubling it.
            root.recording = true
            Quickshell.execDetached(["notify-send", "Screen Recorder", "Already recording", "-a", "Screen Recorder"])
            return
        }
        if (!p)
            return
        const now = new Date()
        const stamp = Qt.formatDateTime(now, "yyyy-MM-dd_hh-mm-ss")
        const out = `${root.videosDir}/recording-${stamp}.mp4`

        let audio = ""
        if (p.systemAudio === "1")
            audio += " -a default_output"
        if (p.mic === "1")
            audio += " -a default_input"

        const cmd = `mkdir -p "${root.videosDir}" && printf '%s' "${out}" > "${root.pathFile}" && ` +
            `exec setsid gpu-screen-recorder -w "${p.region}" -f 60 -c mp4 -k h264${audio} -sc "${root.saveHook}" -o "${out}" ` +
            `< /dev/null > /tmp/quickshell-gsr.log 2>&1`

        root.outputPath = out
        root.elapsed = 0
        root.paused = false
        root.audioSystem = p.systemAudio === "1"
        root.audioMic = p.mic === "1"
        root.recording = true
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    function togglePause(): void {
        if (!root.recording)
            return
        Quickshell.execDetached(["sh", "-c", "pkill -SIGUSR2 -f '^gpu-screen-recorder'"])
        root.paused = !root.paused
    }

    function stop(): void {
        if (!root.recording)
            return
        Quickshell.execDetached(["sh", "-c", "pkill -SIGINT -f '^gpu-screen-recorder'"])
    }

    function status(): string {
        if (root.starting)
            return "starting"
        if (!root.recording)
            return "idle"
        return (root.paused ? "paused " : "recording ") + root.elapsedText + " " + root.outputPath
    }

    function applyPoll(active: bool): void {
        if (active) {
            root.recording = true
            return
        }
        if (!root.recording)
            return
        // Process is gone: clean up. The -sc hook notifies on save;
        // only nag when no video file appeared (crash / empty recording).
        const out = root.outputPath
        root.recording = false
        root.paused = false
        root.elapsed = 0
        root.outputPath = ""
        if (out !== "") {
            Quickshell.execDetached(["sh", "-c",
                `sleep 2; if [ ! -f "${out}" ]; then notify-send "Screen Recorder" "Recording stopped · no video saved" -a "Screen Recorder"; fi; rm -f "${root.pathFile}"`])
        }
    }

    readonly property Process poll: Process {
        running: false
        // NOTE: comm truncates at 15 chars, so -x never matches; use -f.
        command: ["pgrep", "-f", "^gpu-screen-recorder"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    root.applyPoll(true)
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.applyPoll(false)
        }
    }

    // One-shot pre-launch guard for start().
    readonly property Process check: Process {
        running: false
        command: ["pgrep", "-f", "^gpu-screen-recorder"]
        onExited: exitCode => root.finishStartCheck(exitCode === 0)
    }

    readonly property Timer pollTimer: Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.poll.running)
                root.poll.running = true
        }
    }

    readonly property Timer elapsedTimer: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (root.recording && !root.paused)
                root.elapsed++
        }
    }

    IpcHandler {
        target: "recorder"
        function start(region: string, systemAudio: string, mic: string): void {
            root.start(region, systemAudio, mic)
        }
        function stop(): void { root.stop() }
        function togglePause(): void { root.togglePause() }
        function status(): string { return root.status() }
    }
}
