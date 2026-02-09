import Quickshell
import Quickshell.Io
import QtQuick

import "src"

Scope {
    id: root

    // Application State
    property bool isVisible: false

    // Snapshot Service (Global)
    SnapshotService {
        id: snapshotService
    }
    
    // IPC Control Pipe
    // IPC Control (File Semaphores & Exit Codes)
    Process {
        id: ipcReader
        // Check for command files, remove them, and exit with specific code to signal intention.
        // 10=show, 11=hide, 12=toggle, 13=quit
        command: ["sh", "-c", `
            while true; do 
                if [ -f /tmp/screenpicker_cmd_show ]; then rm /tmp/screenpicker_cmd_show; exit 10; fi
                if [ -f /tmp/screenpicker_cmd_hide ]; then rm /tmp/screenpicker_cmd_hide; exit 11; fi
                if [ -f /tmp/screenpicker_cmd_toggle ]; then rm /tmp/screenpicker_cmd_toggle; exit 12; fi
                if [ -f /tmp/screenpicker_cmd_quit ]; then rm /tmp/screenpicker_cmd_quit; exit 13; fi
                sleep 0.1
            done
        `]
        running: true
        
        onExited: (exitCode) => {
            console.log(`IPC Debug: exitCode=${exitCode}`)
             
            if (exitCode === 10) root.isVisible = true
            if (exitCode === 11) root.cancel()
            if (exitCode === 12) root.isVisible = !root.isVisible
            if (exitCode === 13) Qt.quit()
            
            // Restart loop immediately
            ipcReader.running = true
        }
    }
    
    // Output handling (for selection)
    Process {
        id: outputProcess
        command: ["sh", "-c", "echo -n ''"] 
        onExited: (exitCode) => {
             // Hide instead of quit on success
             root.isVisible = false
        }
    }

    function submit(type, content) {
        const output = `[SELECTION]/${type}:${content}`
        console.log(output) 
        // Write to response pipe (blocking until reader connects)
        // Using a background process for this prevents UI freeze if no reader?
        // Actually echo > fifo blocks. 'sh -c' makes sh block.
        // If no one is reading, it hangs.
        // We generally assume a client is waiting?
        // But if user just toggles via `echo show` manually, no one is reading `_out`.
        // So we should only write if we have a request? Or use non-blocking write?
        // Or write to a file and client reads file?
        // Fifo is tricky if no reader.
        // Use timeout? `timeout 1s echo ... > ...`
        
        outputProcess.command = ["sh", "-c", `timeout 0.5s echo "${output}" > /tmp/screenpicker_out`] 
        outputProcess.running = true
    }

    // View State: "popup" or "region"
    property string viewMode: "popup"

    function close() {
        root.cancel()
    }

    // Main Popup Window
    Popup {
        visible: root.isVisible && root.viewMode === "popup"
        snapshotService: snapshotService
        
        onRequestRegionSelect: root.viewMode = "region"
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
            visible: root.isVisible && root.viewMode === "region"
            
            onRegionSelected: (monitorName, x, y, w, h) => {
                const regionStr = `${monitorName}@${Math.round(x)},${Math.round(y)},${Math.round(w)},${Math.round(h)}`
                root.submit("region", regionStr)
            }
            onCancelled: root.viewMode = "popup" // Return to popup
        }
    }
}
