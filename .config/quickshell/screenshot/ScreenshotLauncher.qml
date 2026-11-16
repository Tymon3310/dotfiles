import QtQuick
import Quickshell
import Quickshell.Io

import "../services"

// One entry point for the screenshot IPC interface. Every request starts with
// fresh state, including geometry and instant mode from the previous capture.
Scope {
    id: root

    function request(timestamp: string, mode: string, instant: string, geometry: string, engine: string): void {
        const validModes = ["region", "window", "screen", "analyze", "record"]
        const effMode = validModes.includes(mode) ? mode : "region"
        const effEngine = ["text", "ai", "lens"].includes(engine) ? engine : "text"
        loader.active = false
        loader.setSource(Qt.resolvedUrl("shell.qml"), {
            isLoadedDynamically: true,
            externalTimestamp: timestamp || "",
            mode: effMode,
            analyzeEngine: effEngine,
            instantCapture: instant === "1",
            externalGeom: geometry || ""
        })
        loader.active = true
    }

    Loader {
        id: loader
        active: false
        onLoaded: item.initializeCapture()
        onStatusChanged: {
            if (status === Loader.Error) {
                console.warn("[Screenshot] Failed to load capture tool")
                active = false
            }
        }
    }

    Connections {
        target: loader.item
        function onFinished(): void { loader.active = false }
    }

    IpcHandler {
        target: "screenshot"

        function trigger(envId: string, mode: string, instant: string): void {
            root.request(envId, mode, instant, "", "")
        }
        function open(): void { root.request("", "region", "0", "", "") }
        function instant(geometry: string): void { root.request("", "region", "1", geometry, "") }
        function window(): void { root.request("", "window", "0", "", "") }
        function screen(): void { root.request("", "screen", "0", "", "") }
        function ocr(): void { root.request("", "analyze", "0", "", "text") }
        function lens(): void { root.request("", "analyze", "0", "", "lens") }
        function ai(): void { root.request("", "analyze", "0", "", "ai") }
        function analyze(): void { root.request("", "analyze", "0", "", "") }
        // Toggle: a second press stops the running recording.
        function record(): void {
            if (ScreenRecorderService.recording)
                ScreenRecorderService.stop()
            else
                root.request("", "record", "0", "", "")
        }
    }
}
