pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// MPRIS supplies playback state. This worker supplies only Spotify's next tracks.
Singleton {
    id: root

    property var queue: []
    property int restartAttempts: 0

    readonly property Timer restartTimer: Timer {
        interval: Math.min(30000, 2500 * Math.pow(2, Math.min(root.restartAttempts, 5)))
        onTriggered: root.worker.running = true
    }

    readonly property Process worker: Process {
        command: ["python3", "-u", Quickshell.shellPath("scripts/spotify_queue.py")]
        running: true
        onExited: (code, status) => {
            root.restartAttempts++
            root.queue = []
            console.warn("[SpotifyQueue] Worker exited:", code, "retrying in", root.restartTimer.interval, "ms")
            root.restartTimer.restart()
        }
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (Array.isArray(data.queue)) {
                        root.queue = data.queue
                        root.restartAttempts = 0
                    }
                } catch (error) {
                    console.warn("[SpotifyQueue] Invalid worker response:", error)
                }
            }
        }
        stderr: SplitParser {
            onRead: line => console.warn("[SpotifyQueue]", line)
        }
    }
}
