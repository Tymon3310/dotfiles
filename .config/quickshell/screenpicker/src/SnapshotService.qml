import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Item {
    id: root

    // Signal when a window snapshot is updated
    signal windowSnapshotted(string address)

    readonly property string cacheDir: "/tmp/quickshell_snapshots"

    // Create cache dir
    Process {
        command: ["mkdir", "-p", root.cacheDir]
        running: true
    }

    // Timer to throttle updates and wait for animations
    Timer {
        id: updateTimer
        interval: 2000 // Check every 2 seconds
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: snapshotParams.schedulNext()
    }
    
    // Logic to iterate windows
    QtObject {
        id: snapshotParams
        property int index: 0
        property var windows: []
        property bool busy: false
        property string lastWorkspaceStr: ""

        function schedulNext() {
            if (busy) return
            
            // Gather visible windows
            let visibleWins = []
            
            // Collect visible workspaces
            const activeWorkspaceIds = []
            if (Hyprland.monitors) {
                for (let i = 0; i < Hyprland.monitors.values.length; i++) {
                    const mon = Hyprland.monitors.values[i]
                    if (mon.activeWorkspace) {
                        activeWorkspaceIds.push(mon.activeWorkspace.id)
                    }
                }
            }
            
            // Stability Check: If workspaces changed since last check, skip this cycle
            // to allow animations to finish.
            // Sort to ensure order doesn't matter (though monitor order usually stable)
            const currentStr = JSON.stringify(activeWorkspaceIds.sort())
            if (currentStr !== lastWorkspaceStr) {
                console.log("SnapshotService: Workspaces changed, waiting for stability...")
                lastWorkspaceStr = currentStr
                busy = false
                return
            }
            
            // Collect visible windows
            if (Hyprland.workspaces) {
                for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
                    const ws = Hyprland.workspaces.values[i]
                    if (activeWorkspaceIds.includes(ws.id) && ws.toplevels) {
                        for (let j = 0; j < ws.toplevels.values.length; j++) {
                            visibleWins.push(ws.toplevels.values[j])
                        }
                    }
                }
            }
            
            windows = visibleWins
            index = 0
            processNext()
        }
        
        function processNext() {
            if (index >= windows.length) {
                busy = false
                return
            }
            
            busy = true
            const win = windows[index]
            index++
            
            if (!win.lastIpcObject || !win.lastIpcObject.at || !win.lastIpcObject.size) {
                processNext()
                return
            }
            
            const x = win.lastIpcObject.at[0]
            const y = win.lastIpcObject.at[1]
            const w = win.lastIpcObject.size[0]
            const h = win.lastIpcObject.size[1]
            
            if (w <= 1 || h <= 1) {
                processNext()
                return
            }
            
            const finalPath = `${root.cacheDir}/${win.address}.png`
            const tempPath = `${root.cacheDir}/temp_${win.address}.png`
            
            // Execute grim
            snapshotProc.windowAddress = win.address
            snapshotProc.command = ["sh", "-c", `grim -g "${x},${y} ${w}x${h}" "${tempPath}" && mv "${tempPath}" "${finalPath}"`]
            // 500ms delay handled by the fact we run this periodically, but if we wanted per-window delay we'd use a timer.
            // For now, the 2s loop interval + the fact windows are likely stable is "good enough" for background.
            // If user switches, they might see old preview for 2s. 
            // Better: use Hyprland.activeWindow to trigger immediate snapshot after delay.
            
            snapshotProc.running = true
        }
    }

    Process {
        id: snapshotProc
        property string windowAddress
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log(`Snapshotted ${windowAddress}`)
                root.windowSnapshotted(windowAddress)
            }
            // Move to next
            snapshotParams.processNext()
        }
    }
    

}
