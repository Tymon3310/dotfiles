
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

import "."

Singleton {
    id: root

    readonly property var players: Mpris.players.values.filter(player =>
        !player.dbusName.includes("playerctld")
        && (`${player.dbusName} ${player.identity} ${player.desktopEntry}`.toLowerCase().includes("spotify")
            || player.dbusName.toLowerCase().includes("mpv")))

    readonly property MprisPlayer active: {
        const playing = root.players.find(player => player.isPlaying)
        if (playing)
            return playing
        return root.players.find(player => player.canControl) ?? null
    }

    readonly property bool available: root.active !== null
    readonly property bool playing: root.available && root.active.isPlaying
    readonly property bool activeIsSpotify: root.available
        && `${root.active.dbusName} ${root.active.identity} ${root.active.desktopEntry}`
            .toLowerCase().includes("spotify")

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
    // Remote cover art is fetched by curl into a local cache and shown from
    // there: Qt's own HTTP loader drops requests to Spotify's image host
    // ("sendRequest() called without QHttpNetworkReply"), leaving art blank.
    readonly property string remoteArtUrl: root.available ? (root.active.trackArtUrl ?? "") : ""
    readonly property string artCacheDir: (Quickshell.env("XDG_CACHE_HOME")
        || `${Quickshell.env("HOME")}/.cache`) + "/quickshell/art"
    property string artUrl: ""

    onRemoteArtUrlChanged: root.fetchArt()
    Component.onCompleted: root.fetchArt()

    function fetchArt(): void {
        const url = root.remoteArtUrl
        if (!/^https?:\/\//.test(url)) {
            root.artUrl = url
            return
        }
        const path = `${root.artCacheDir}/${Qt.md5(url)}.img`
        root.artUrl = ""
        root.artFetcher.running = false
        root.artFetcher.url = url
        root.artFetcher.path = path
        root.artFetcher.command = ["sh", "-c",
            'test -s "$2" || { mkdir -p "$(dirname "$2")" && curl -sfL --max-time 15 -o "$2.part" "$1" && mv "$2.part" "$2"; }',
            "fetch-art", url, path]
        root.artFetcher.running = true
    }

    readonly property Process artFetcher: Process {
        property string url: ""
        property string path: ""

        onExited: code => {
            // A newer track may have started a fetch since.
            if (code === 0 && root.artFetcher.url === root.remoteArtUrl)
                root.artUrl = `file://${root.artFetcher.path}`
        }
    }
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
    // lyrics): the poll runs at 50 ms while any is held.
    property int preciseWatchers: 0

    readonly property Timer positionTimer: Timer {
        interval: root.preciseWatchers > 0 ? 50 : 1000
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
    // MPRIS has no queue; the Web API worker supplies it only for Spotify.
    readonly property var queue: root.activeIsSpotify ? SpotifyQueueService.queue : []

    function toggle(): void {
        if (root.canToggle)
            root.active.togglePlaying()
    }

    function next(): void {
        if (root.canNext)
            root.active.next()
    }

    function seek(fraction: real): void {
        if (!root.canSeek)
            return
        root.active.position = Math.max(0, Math.min(1, fraction)) * root.length
    }

    function previous(): void {
        if (root.canPrevious)
            root.active.previous()
    }

    //
    // Spotify uses PipeWire streams; other players use their MPRIS volume.
    // Quickshell connects to PipeWire lazily, on the first read of a default
    // device; reading the node list alone leaves it empty.
    readonly property var pipewireWake: Pipewire.defaultAudioSink

    // `name` is PipeWire's node.name; `properties` stays empty until a node is
    // tracked, so it cannot be used to find one.
    readonly property var spotifyStreams: Pipewire.nodes.values.filter(node =>
        node.isStream && (node.name ?? "").toLowerCase() === "spotify")

    readonly property var volumeStreams: root.activeIsSpotify ? root.spotifyStreams : []

    readonly property PwObjectTracker streamTracker: PwObjectTracker {
        objects: root.spotifyStreams
    }

    readonly property bool mprisVolumeAvailable: root.available
        && root.active.canControl && root.active.volumeSupported
    readonly property bool volumeAvailable: root.volumeStreams.some(node => node.audio)
        || root.mprisVolumeAvailable

    readonly property real volume: {
        const node = root.volumeStreams.find(node => node.audio)
        if (node && node.audio && node.audio.volume !== undefined)
            return node.audio.volume
        if (root.mprisVolumeAvailable)
            return root.active.volume
        return 1.0
    }

    readonly property bool muted: root.volumeStreams.some(node => node.audio)
        ? root.volumeStreams.some(node => node.audio?.muted ?? false)
        : (root.mprisVolumeAvailable && root.active.volume === 0)
    property real volumeBeforeMute: 1.0
    onActiveChanged: root.volumeBeforeMute = 1.0

    // True for a moment after a change, so the bar / osd can show the level.
    property bool volumeShown: false

    readonly property Timer volumeFlash: Timer {
        interval: 1200
        onTriggered: root.volumeShown = false
    }

    function setVolume(value: real): void {
        if (!root.volumeAvailable)
            return
        const level = Math.max(0, Math.min(1, value))

        let pipewireUpdated = false
        for (const node of root.volumeStreams) {
            if (node.audio) {
                node.audio.volume = level
                pipewireUpdated = true
            }
        }
        if (!pipewireUpdated && root.mprisVolumeAvailable) {
            root.active.volume = level
        }

        root.volumeShown = true
        root.volumeFlash.restart()
    }

    function nudgeVolume(delta: real): void {
        const current = root.volume
        root.setVolume(Math.round((current + delta) * 100) / 100)
    }

    function toggleMute(): void {
        if (!root.volumeAvailable)
            return
        const target = !root.muted
        if (root.volumeStreams.some(node => node.audio)) {
            for (const node of root.volumeStreams) {
                if (node.audio)
                    node.audio.muted = target
            }
        } else if (root.mprisVolumeAvailable) {
            if (target)
                root.volumeBeforeMute = root.volume
            root.setVolume(target ? 0 : root.volumeBeforeMute)
        }
    }
}
