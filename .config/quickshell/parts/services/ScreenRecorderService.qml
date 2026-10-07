pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Owns screen recording via gpu-screen-recorder and exposes the state
// (recording / paused / elapsed) to the island indicator.
//
// Only the recorder we launched is tracked: it is found by its output path,
// which lives in stateFile together with the timing/pause bookkeeping, so a
// shell reload re-adopts it as-is and foreign gsr processes are left alone.
// stateFile lines: output, startedAt, audioSystem, audioMic, pausedTotal, pausedSince
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

    // Wall-clock bookkeeping (epoch seconds) so elapsed survives reloads.
    property real startedAt: 0
    property real pausedTotal: 0
    property real pausedSince: 0
    // Empty polls right after launch are ignored until gsr is up.
    property real launchedAt: 0
    readonly property int launchGrace: 5

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
    readonly property string stateFile: "/tmp/qs-screenrecording-path"
    readonly property string saveHook: Quickshell.shellPath("parts/scripts/recording-saved.sh")

    // $1 = state file. Prints "<pid>" then the state file for our recorder,
    // exits 1 when there is none.
    readonly property string probeScript:
        `f="$1"; [ -s "$f" ] || exit 1; out=$(head -n1 "$f"); ` +
        `pid=$(pgrep -af '^gpu-screen-recorder' | grep -F -- " -o $out" | head -n1 | cut -d' ' -f1); ` +
        `[ -n "$pid" ] || exit 1; echo "$pid"; cat "$f"`

    // $1 = signal, $2 = probe script, $3 = state file.
    readonly property string signalScript:
        `pid=$(sh -c "$2" sh "$3" | head -n1) && [ -n "$pid" ] && kill -"$1" "$pid"`

    function now(): real {
        return Date.now() / 1000
    }

    function updateElapsed(): void {
        if (!root.recording) {
            root.elapsed = 0
            return
        }
        const end = root.pausedSince > 0 ? root.pausedSince : root.now()
        root.elapsed = Math.max(0, Math.floor(end - root.startedAt - root.pausedTotal))
    }

    function writeState(): void {
        Quickshell.execDetached(["sh", "-c", `printf '%s\\n' "$@" > "$0.tmp" && mv "$0.tmp" "$0"`,
            root.stateFile,
            root.outputPath,
            String(root.startedAt),
            root.audioSystem ? "1" : "0",
            root.audioMic ? "1" : "0",
            String(root.pausedTotal),
            String(root.pausedSince)])
    }

    // Take over state from a probe result ("<pid>\n<state file>").
    function adopt(text: string): void {
        const lines = text.trim().split("\n")
        const out = lines[1] || ""
        if (out === "")
            return
        if (out !== root.outputPath) {
            // A recording we don't know about yet (e.g. after a shell reload).
            root.outputPath = out
            root.startedAt = parseFloat(lines[2]) || root.now()
            root.audioSystem = lines[3] === "1"
            root.audioMic = lines[4] === "1"
            root.pausedTotal = parseFloat(lines[5]) || 0
            root.pausedSince = parseFloat(lines[6]) || 0
            root.paused = root.pausedSince > 0
        }
        root.recording = true
        root.updateElapsed()
    }

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
        // Physical single-instance guard: confirm our recorder isn't already
        // running before launching (in-memory state is lost across reloads).
        root.pendingStart = { region: `${m[1]}x${m[2]}+${m[3]}+${m[4]}`, systemAudio: systemAudio, mic: mic }
        root.starting = true
        if (!root.check.running)
            root.check.running = true
    }

    function finishStartCheck(found: bool, text: string): void {
        const p = root.pendingStart
        root.pendingStart = null
        root.starting = false
        if (found) {
            // Adopt the running recording instead of doubling it.
            root.adopt(text)
            Quickshell.execDetached(["notify-send", "Screen Recorder", "Already recording", "-a", "Screen Recorder"])
            return
        }
        if (!p)
            return
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss")
        const out = `${root.videosDir}/recording-${stamp}.mp4`

        let audio = ""
        if (p.systemAudio === "1")
            audio += " -a default_output"
        if (p.mic === "1")
            audio += " -a default_input"

        root.outputPath = out
        root.startedAt = root.now()
        root.launchedAt = root.startedAt
        root.pausedTotal = 0
        root.pausedSince = 0
        root.paused = false
        root.audioSystem = p.systemAudio === "1"
        root.audioMic = p.mic === "1"
        root.recording = true
        root.updateElapsed()

        const sys = root.audioSystem ? "1" : "0"
        const micFlag = root.audioMic ? "1" : "0"
        const cmd = `mkdir -p "${root.videosDir}" && ` +
            `printf '%s\\n' "${out}" "${root.startedAt}" ${sys} ${micFlag} 0 0 > "${root.stateFile}" && ` +
            `exec setsid gpu-screen-recorder -w region -region "${p.region}" -f 60 -c mp4 -k h264${audio} ` +
            `-sc "${root.saveHook}" -o "${out}" < /dev/null > /tmp/quickshell-gsr.log 2>&1`
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    function togglePause(): void {
        if (!root.recording || root.pauseProc.running)
            return
        root.pauseProc.running = true
    }

    // Flip local pause state only once gsr actually got the signal.
    function applyPauseToggle(): void {
        const t = root.now()
        if (root.paused) {
            root.pausedTotal += t - root.pausedSince
            root.pausedSince = 0
            root.paused = false
        } else {
            root.pausedSince = t
            root.paused = true
        }
        root.updateElapsed()
        root.writeState()
    }

    function stop(): void {
        if (!root.recording)
            return
        Quickshell.execDetached(["sh", "-c", root.signalScript, "sh", "INT", root.probeScript, root.stateFile])
    }

    function status(): string {
        if (root.starting)
            return "starting"
        if (!root.recording)
            return "idle"
        return (root.paused ? "paused " : "recording ") + root.elapsedText + " " + root.outputPath
    }

    function applyPoll(active: bool, text: string): void {
        if (active) {
            root.adopt(text)
            return
        }
        if (!root.recording)
            return
        if (root.now() - root.launchedAt < root.launchGrace)
            return
        // Process is gone: clean up. The -sc hook notifies on save;
        // only nag when no video file appeared (crash / empty recording).
        const out = root.outputPath
        root.recording = false
        root.paused = false
        root.pausedSince = 0
        root.pausedTotal = 0
        root.outputPath = ""
        root.updateElapsed()
        if (out !== "") {
            // Only drop the state file if a newer recording hasn't replaced it.
            Quickshell.execDetached(["sh", "-c",
                `sleep 2; if [ ! -f "$1" ]; then notify-send "Screen Recorder" "Recording stopped · no video saved" -a "Screen Recorder"; fi; ` +
                `[ "$(head -n1 "$2" 2>/dev/null)" = "$1" ] && rm -f "$2"`,
                "sh", out, root.stateFile])
        }
    }

    readonly property Process poll: Process {
        running: false
        command: ["sh", "-c", root.probeScript, "sh", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    root.applyPoll(true, this.text)
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.applyPoll(false, "")
        }
    }

    // One-shot pre-launch guard for start().
    readonly property Process check: Process {
        running: false
        command: ["sh", "-c", root.probeScript, "sh", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    root.finishStartCheck(true, this.text)
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.finishStartCheck(false, "")
        }
    }

    readonly property Process pauseProc: Process {
        running: false
        command: ["sh", "-c", root.signalScript, "sh", "USR2", root.probeScript, root.stateFile]
        onExited: exitCode => {
            if (exitCode === 0)
                root.applyPauseToggle()
            else
                console.warn("[Recorder] Pause signal failed")
        }
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
        interval: 500
        running: root.recording && !root.paused
        repeat: true
        onTriggered: root.updateElapsed()
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
