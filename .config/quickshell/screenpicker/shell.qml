import Quickshell
import Quickshell.Io
import QtQuick

import "src"

Scope {
    id: root

    // Application State
    enum State {
        Popup,
        RegionSelect
    }

    property int appState: Root.State.Popup
    
    // Output handling
    Process {
        id: outputProcess
        // Redirect to the parent process's stdout
        command: ["sh", "-c", "echo -n ''"] 
        onExited: Qt.quit()
    }

    function submit(type, content) {
        const output = `[SELECTION]/${type}:${content}`
        // Write to /proc/self/fd/1 which is stdout
        outputProcess.command = ["sh", "-c", `echo "${output}" > /proc/self/fd/1`]
        outputProcess.running = true
    }

    function close() {
        Qt.quit()
    }

    // Main Popup Window
    Popup {
        visible: root.appState === Root.State.Popup
        
        onRequestRegionSelect: root.appState = Root.State.RegionSelect
        onScreenSelected: (name) => root.submit("screen", name)
        onWindowSelected: (address) => root.submit("window", address)
        onCancelled: root.close()
    }

    // Region Selection Overlay (one per screen)
    Variants {
        model: Quickshell.screens

        RegionOverlay {
            required property var modelData
            targetScreen: modelData
            visible: root.appState === Root.State.RegionSelect
            
            onRegionSelected: (monitorName, x, y, w, h) => {
                const regionStr = `${monitorName}@${Math.round(x)},${Math.round(y)},${Math.round(w)},${Math.round(h)}`
                root.submit("region", regionStr)
            }
            onCancelled: root.appState = Root.State.Popup // Go back to popup on cancel
        }
    }
}
