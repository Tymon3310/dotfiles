// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M E D I A   S E R V I C E                                              │
// │   the player worth showing · mpris over d-bus                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

import "."

// Picks one MPRIS player and exposes it flatly: the one that is playing,
// otherwise the first controllable one, so a paused track stays on the island.
//
// Spotify only (the desktop client, spotify_player, spotifyd): browsers and
// other players are ignored. playerctld is skipped too: it mirrors whichever
// player is active, so it would let the others back in.
Singleton {
    id: root

    readonly property var players: Mpris.players.values.filter(player =>
        !player.dbusName.includes("playerctld")
        && `${player.dbusName} ${player.identity} ${player.desktopEntry}`.toLowerCase().includes("spotify"))

    readonly property MprisPlayer active: {
        const playing = root.players.find(player => player.isPlaying)
        if (playing)
            return playing
        return root.players.find(player => player.canControl) ?? null
    }

    readonly property bool available: root.active !== null
    readonly property bool playing: root.available && root.active.isPlaying

    // ── VISUALIZER INACTIVITY TIMEOUT ─────────────────────────────
    // After 20 seconds without Spotify playing, visualizerActive becomes false.
    property bool visualizerTimeout: false

    readonly property Timer visualizerTimeoutTimer: Timer {
        interval: 20000
        repeat: false
        running: root.available && !root.playing
        onTriggered: root.visualizerTimeout = true
    }

    onPlayingChanged: {
        if (root.playing) {
            root.visualizerTimeout = false
            root.visualizerTimeoutTimer.stop()
        }
    }

    onAvailableChanged: {
        if (!root.available) {
            root.visualizerTimeout = true
            root.visualizerTimeoutTimer.stop()
        } else if (root.playing) {
            root.visualizerTimeout = false
        }
    }

    readonly property bool visualizerActive: root.available && !root.visualizerTimeout

    readonly property string title: root.available ? (root.active.trackTitle ?? "") : ""
    readonly property string artist: root.available ? (root.active.trackArtist ?? "") : ""
    readonly property string album: root.available ? (root.active.trackAlbum ?? "") : ""
    readonly property string artUrl: root.available ? (root.active.trackArtUrl ?? "") : ""
    readonly property string identity: root.available ? (root.active.identity ?? "") : ""

    readonly property bool canNext: root.available && root.active.canGoNext
    readonly property bool canPrevious: root.available && root.active.canGoPrevious
    readonly property bool canToggle: root.available && root.active.canTogglePlaying
    readonly property bool canSeek: root.available && root.active.canSeek && root.length > 0

    // Seconds. Streams report no length, so `progress` stays at 0.
    readonly property real length: root.available ? (root.active.length ?? 0) : 0
    readonly property real position: root.available ? (root.active.position ?? 0) : 0
    readonly property bool seekable: root.length > 0
    readonly property real progress: root.seekable
        ? Math.max(0, Math.min(1, root.position / root.length))
        : 0

    // MPRIS does not push position, so it is polled only while something on
    // screen holds a subscribe().
    property int watchers: 0

    // Holders that need the position to the frame, not the second (synced
    // lyrics): the poll runs at 30 ms while any is held.
    property int preciseWatchers: 0

    readonly property Timer positionTimer: Timer {
        interval: root.preciseWatchers > 0 ? 30 : 1000
        repeat: true
        running: root.watchers > 0 && root.playing && root.seekable
        onTriggered: {
            if (root.available)
                root.active.positionChanged()
        }
    }

    function subscribe(): void {
        root.watchers += 1
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function subscribePrecise(): void {
        root.watchers += 1
        root.preciseWatchers += 1
    }

    function releasePrecise(): void {
        root.watchers = Math.max(0, root.watchers - 1)
        root.preciseWatchers = Math.max(0, root.preciseWatchers - 1)
    }

    // The next tracks, [{ title, artist, artUrl }], from the Spotify Web API.
    // MPRIS has no queue, so the host fills this in: the dotfiles' shell.qml
    // binds it to media_status.py's `queue` logic.
    property var queue: []

    function toggle(): void {
        if (root.canToggle)
            root.active.togglePlaying()
    }

    function next(): void {
        if (root.canNext)
            root.active.next()
    }

    // `fraction` of the track's length.
    function seek(fraction: real): void {
        if (!root.canSeek)
            return
        root.active.position = Math.max(0, Math.min(1, fraction)) * root.length
    }

    function previous(): void {
        if (root.canPrevious)
            root.active.previous()
    }

    // ── SPOTIFY'S OWN VOLUME ──────────────────────────────────────────────
    //
    // Set on Spotify's PipeWire streams and MPRIS interface.
    // Quickshell connects to PipeWire lazily, on the first read of a default
    // device; reading the node list alone leaves it empty.
    readonly property var pipewireWake: Pipewire.defaultAudioSink

    // `name` is PipeWire's node.name; `properties` stays empty until a node is
    // tracked, so it cannot be used to find one.
    readonly property var spotifyStreams: Pipewire.nodes.values.filter(node =>
        node.isStream && (node.name ?? "").toLowerCase() === "spotify")

    readonly property PwObjectTracker streamTracker: PwObjectTracker {
        objects: root.spotifyStreams
    }

    readonly property bool volumeAvailable: root.spotifyStreams.some(node => node.audio) || root.available

    // Volume level 0.0 – 1.0
    readonly property real volume: {
        const node = root.spotifyStreams.find(node => node.audio)
        if (node && node.audio && node.audio.volume !== undefined)
            return node.audio.volume
        if (root.available && root.active.volume !== undefined && root.active.volume >= 0)
            return root.active.volume
        return 1.0
    }

    readonly property bool muted: root.spotifyStreams.some(node => node.audio?.muted ?? false)

    // True for a moment after a change, so the bar / osd can show the level.
    property bool volumeShown: false

    readonly property Timer volumeFlash: Timer {
        interval: 1200
        onTriggered: root.volumeShown = false
    }

    function setVolume(value: real): void {
        const norm = value > 1.0 ? value / 100.0 : value
        const level = Math.max(0, Math.min(1, norm))

        for (const node of root.spotifyStreams) {
            if (node.audio)
                node.audio.volume = level
        }
        if (root.available && root.active.volume !== undefined) {
            root.active.volume = level
        }
        Quickshell.execDetached(["playerctl", "-p", "spotify", "volume", level.toFixed(2)])

        root.volumeShown = true
        root.volumeFlash.restart()

        const icon = (level <= 0 || root.muted) ? "󰝟" : (level < 0.33 ? "󰕿" : (level < 0.66 ? "󰖀" : "󰕾"))
        OsdService.requested(
            icon,
            `Spotify ${Math.round(level * 100)}%`,
            level
        )
    }

    function nudgeVolume(delta: real): void {
        const current = root.volume
        root.setVolume(Math.round((current + delta) * 100) / 100)
    }

    function toggleMute(): void {
        const target = !root.muted
        for (const node of root.spotifyStreams) {
            if (node.audio)
                node.audio.muted = target
        }
    }
}
