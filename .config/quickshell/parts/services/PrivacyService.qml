pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // ── PIPEWIRE NODES TRACKER ──────────────────────────────────────────────
    readonly property PwObjectTracker tracker: PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    function prop(node: var, key: string): string {
        const value = node.properties ? node.properties[key] : undefined
        return value === undefined || value === null ? "" : `${value}`
    }

    readonly property var nodes: Pipewire.nodes.values

    // Mic streams recording from input
    readonly property var inStreams: root.nodes.filter(node =>
        node.type === PwNodeType.AudioInStream)

    readonly property var micListeners: root.inStreams.filter(node => {
        if (!node.ready) return false
        const props = node.properties ?? {}
        return props["stream.capture.sink"] !== "true"
            && props["stream.monitor"] !== "true"
            && props["application.name"] !== "cava"
    })

    readonly property bool micActive: root.micListeners.length > 0

    function nameOf(node: var): string {
        const raw = root.prop(node, "application.process.binary")
            || root.prop(node, "application.name") || node.name || ""
        const base = raw.replace(/\.(exe|bin)$/i, "")
        return base.charAt(0).toUpperCase() + base.slice(1)
    }

    readonly property string micSummary: {
        const names = root.micListeners.map(n => root.nameOf(n)).filter(n => n.length > 0)
        const unique = names.filter((v, i, a) => a.indexOf(v) === i)
        return unique.length > 0 ? unique.join(", ") : ""
    }

    readonly property string cameraSummary: {
        const names = root.cameraHolders.map(n => n.charAt(0).toUpperCase() + n.slice(1))
        return names.length > 0 ? names.join(", ") : ""
    }

    // Screen sharing through XDG desktop portal
    readonly property bool screenActive: root.nodes.some(node =>
        root.prop(node, "media.class") === "Video/Source"
            && /xdg-desktop-portal|xdph/.test(node.name))

    // ── CAMERA INOTIFY ──────────────────────────────────────────────────────
    property var cameraHolders: []
    readonly property bool cameraActive: root.cameraHolders.length > 0

    readonly property Process cameraProcess: Process {
        command: ["python3", "-u", Quickshell.shellPath("parts/scripts/privacy_monitor.py")]
        running: true

        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (data.camera !== undefined) {
                        root.cameraHolders = data.camera
                    }
                } catch (_) {}
            }
        }
    }

    readonly property bool active: root.cameraActive || root.micActive || root.screenActive
}
