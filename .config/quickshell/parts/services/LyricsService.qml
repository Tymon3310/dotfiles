// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L Y R I C S   S E R V I C E                                            │
// │   the playing track's lyrics, and the line being sung                    │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Lyrics for MediaService's track, from `scripts/lyrics.py` (lrclib.net,
// cached on disk). Fetched only while something holds a subscribe(), and
// again whenever the track changes while it is held.
//
// `kind` is "synced", "plain", "instrumental", "none" or "" while loading.
// `index` is the line being sung (synced only, -1 before the first), `wordIndex`
// the word within it when the lyrics time each word.
Singleton {
    id: root

    property string kind: ""
    property var lines: []
    readonly property bool loading: root.kind === ""
    readonly property bool synced: root.kind === "synced" && root.lines.length > 0
    readonly property bool shown: root.synced || (root.kind === "plain" && root.lines.length > 0)

    property int watchers: 0

    function subscribe(): void {
        root.watchers += 1
        MediaService.subscribePrecise()
        root.fetch()
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
        MediaService.releasePrecise()
    }

    // ── TRACK ─────────────────────────────────────────────────────────────

    readonly property string track: MediaService.available
        ? `${MediaService.artist}\n${MediaService.title}\n${Math.round(MediaService.length)}` : ""

    // What the lines on hand belong to.
    property string loaded: ""

    onTrackChanged: {
        if (root.watchers > 0)
            root.fetch()
    }

    function fetch(): void {
        if (root.track === root.loaded && root.kind !== "")
            return
        root.kind = ""
        root.lines = []
        root.loaded = root.track
        if (!MediaService.available || MediaService.title === "") {
            root.kind = "none"
            return
        }
        // A new request replaces one still running for the previous track.
        fetcher.running = false
        fetcher.command = [Quickshell.shellPath("parts/scripts/lyrics.py"),
            "--artist", MediaService.artist,
            "--title", MediaService.title,
            "--album", MediaService.album,
            "--duration", `${Math.round(MediaService.length)}`]
        fetcher.forTrack = root.track
        fetcher.running = true
    }

    Process {
        id: fetcher

        property string forTrack: ""

        stdout: StdioCollector {
            onStreamFinished: {
                // Answers for a track that has since changed are dropped.
                if (fetcher.forTrack !== root.track)
                    return
                try {
                    const data = JSON.parse(text)
                    root.lines = data.lines ?? []
                    root.kind = data.kind ?? "none"
                } catch (error) {
                    root.lines = []
                    root.kind = "none"
                }
            }
        }
    }

    // ── POSITION ──────────────────────────────────────────────────────────

    // Milliseconds with user offset from SettingsService (+ shifts earlier, - shifts later).
    readonly property real now: MediaService.position * 1000 + SettingsService.lyricsOffset

    readonly property int index: {
        if (!root.synced)
            return -1
        const lines = root.lines
        let low = 0
        let high = lines.length - 1
        let found = -1
        while (low <= high) {
            const middle = (low + high) >> 1
            if (lines[middle].t <= root.now) {
                found = middle
                low = middle + 1
            } else {
                high = middle - 1
            }
        }
        return found
    }

    readonly property int wordIndex: {
        if (root.index < 0)
            return -1
        const words = root.lines[root.index].words ?? []
        let found = -1
        for (let i = 0; i < words.length; i++) {
            if (words[i].t <= root.now)
                found = i
            else
                break
        }
        return found
    }
}
