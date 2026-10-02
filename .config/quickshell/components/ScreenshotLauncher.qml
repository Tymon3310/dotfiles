import QtQuick
import Quickshell
import Quickshell.Io

// One entry point for the screenshot IPC interface. Every request starts with
// fresh state, including geometry and instant mode from the previous capture.
Scope {
    id: root

    function request(timestamp: string, mode: string, instant: string, geometry: string): void {
        const validModes = ["region", "window", "screen", "ocr", "lens", "ai"]
        loader.active = false
        loader.setSource(Qt.resolvedUrl("../screenshot/shell.qml"), {
            isLoadedDynamically: true,
            externalTimestamp: timestamp || "",
            mode: validModes.includes(mode) ? mode : "region",
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
            root.request(envId, mode, instant, "")
        }
        function open(): void { root.request("", "region", "0", "") }
        function instant(geometry: string): void { root.request("", "region", "1", geometry) }
        function window(): void { root.request("", "window", "0", "") }
        function screen(): void { root.request("", "screen", "0", "") }
        function ocr(): void { root.request("", "ocr", "0", "") }
        function lens(): void { root.request("", "lens", "0", "") }
        function ai(): void { root.request("", "ai", "0", "") }
    }
}
