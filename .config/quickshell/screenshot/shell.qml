import QtQuick
import Quickshell
import Quickshell.Io

import "./src"

Scope {
    id: root

    property string externalTimestamp: ""
    property bool isLoadedDynamically: false
    signal finished()

    function exitTool() {
        const standalone = !root.isLoadedDynamically
        root.cleanup()
        root.finished()
        if (standalone) {
            Qt.quit()
        }
    }

    property string tempPath: ""
    property string cropPath: ""
    property bool saveToDisk: true
    property bool recordSystemAudio: true
    property bool recordMic: false
    property string mode: "region"
    property string externalGeom: ""
    property bool ready: false
    property var pendingAction: null
    property bool instantCapture: false
    signal requestFlash()
    property var modes: [
        { mode: "region", icon: "region", label: "Region" },
        { mode: "window", icon: "window", label: "Window" },
        { mode: "screen", icon: "screen", label: "Screen" },
        { mode: "analyze", icon: "analyze", label: "Analyze" },
        { mode: "record", icon: "record", label: "Record" }
    ]
    // Analyze engine radio: "text" (OCR) | "ai" (Gemini) | "lens" (upload)
    property string analyzeEngine: "text"
    property string aiPrompt: "Briefly describe this image in 2-3 sentences."
    property bool shiftHeld: false
    property bool promptFocused: false
    // Live modifier state for record-mode pick layers (Ctrl = monitors, Shift = window)
    property bool shiftDown: false
    property bool ctrlDown: false

    // Application-wide shortcut: Escape always closes the screenshot tool
    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: root.exitTool()
    }

    // QR code detection for lens mode
    property var detectedQRCodes: []  // Array of {x, y, width, height, data} in image coords

    // Calculate the minimum x/y offset across all screens
    // grim's combined output starts at (0,0) for the top-left of the bounding box
    property real minScreenX: {
        var minX = Infinity
        for (var i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].x < minX) minX = Quickshell.screens[i].x
        }
        return minX
    }
    property real minScreenY: {
        var minY = Infinity
        for (var i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].y < minY) minY = Quickshell.screens[i].y
        }
        return minY
    }

    // Heuristic for primary screen: Largest area
    property var primaryScreen: {
        var maxArea = 0
        var bestScreen = Quickshell.screens[0]
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var s = Quickshell.screens[i]
            var area = s.width * s.height
            if (area > maxArea) {
                maxArea = area
                bestScreen = s
            }
        }
        return bestScreen
    }

    // Global selection state (for cross-screen selection)
    property bool isSelecting: false
    property real globalStartX: 0
    property real globalStartY: 0
    property real globalEndX: 0
    property real globalEndY: 0

    // Multi-selection state
    property var selectedWindows: [] // Array of window objects (address, x, y, width, height)
    property var selectedScreens: [] // Array of screen names
    readonly property int windowMultiSelectCount: root.selectedWindows.length

    // Computed selection rect (normalized)
    property real selectionX: Math.min(globalStartX, globalEndX)
    property real selectionY: Math.min(globalStartY, globalEndY)
    property real selectionWidth: Math.abs(globalEndX - globalStartX)
    property real selectionHeight: Math.abs(globalEndY - globalStartY)

    // Hyprland 0.54 fix: track frozen state separately from ready,
    // so FreezeScreens survive when ready is toggled during save
    property bool screensFrozen: false

    Timer {
        id: startupTimer
        interval: 0
        running: false
        repeat: false
        onTriggered: {
            if (!root.isLoadedDynamically) {
                root.initializeCapture()
            }
        }
    }

    Component.onCompleted: startupTimer.start()

    function initializeCapture() {

        // CLI args via env vars
        const envMode = root.isLoadedDynamically ? "" : (Quickshell.env("QS_MODE") || "")
        const envInstant = root.isLoadedDynamically ? "" : (Quickshell.env("QS_INSTANT") || "")
        const envId = root.isLoadedDynamically ? "" : (Quickshell.env("QS_ID") || "")
        const validModes = ["region", "window", "screen", "analyze", "record"]
        const legacyEngines = { ocr: "text", lens: "lens", ai: "ai" }
        if (envMode && validModes.includes(envMode)) {
            root.mode = envMode
        } else if (envMode && envMode in legacyEngines) {
            root.mode = "analyze"
            root.analyzeEngine = legacyEngines[envMode]
        }
        const envEngine = root.isLoadedDynamically ? "" : (Quickshell.env("QS_ENGINE") || "")
        if (root.mode === "analyze" && ["text", "ai", "lens"].includes(envEngine)) {
            root.analyzeEngine = envEngine
        }
        root.instantCapture = root.instantCapture || envInstant === "1"
        if (root.instantCapture && !root.externalGeom && (root.mode === "screen" || root.mode === "window")) {
            // Fetch geometry upfront via hyprctl (Hyprland QML API isn't available yet)
            if (root.mode === "screen") {
                instantGeoProcess.command = ["sh", "-c", "hyprctl monitors -j | jq -r '[.[] | select(.focused)][0] | [.x, .y, .width, .height] | @tsv'"]
            } else {
                instantGeoProcess.command = ["sh", "-c", "hyprctl activewindow -j | jq -r '[.at[0], .at[1], .size[0], .size[1]] | @tsv'"]
            }
            instantGeoProcess.running = true
        } else if (root.instantCapture && !root.externalGeom) {
            root.instantCapture = false
        }

        if (root.externalGeom) {
            const m = root.externalGeom.trim().match(/^(-?\d+),(-?\d+)\s+(\d+)x(\d+)$/)
                   || root.externalGeom.trim().match(/^(-?\d+)[\s,]+(-?\d+)[\s,]+(\d+)[\s,]+(\d+)$/)
            if (m) {
                const w = parseInt(m[3])
                const h = parseInt(m[4])
                if (w > 0 && h > 0) {
                    root._instantGeo = {
                        x: parseInt(m[1]),
                        y: parseInt(m[2]),
                        w: w,
                        h: h
                    }
                    root.instantCapture = true
                } else {
                    console.warn("[Screenshot] Invalid dimensions in external geometry:", root.externalGeom)
                    root.instantCapture = false
                }
            } else {
                console.warn("[Screenshot] Failed to parse external geometry:", root.externalGeom)
                root.instantCapture = false
            }
        }

        const timestamp = root.externalTimestamp ? root.externalTimestamp : (envId ? envId : Date.now())
        tempPath = `/tmp/quickshell-screenshot-${timestamp}.png`

        // Hyprland 0.54 + grim 1.5.0: full multi-output grim hangs.
        // Fix: capture each output in parallel, then stitch with magick.
        const screens = Quickshell.screens
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i]
            if (s.x < minX) minX = s.x
            if (s.y < minY) minY = s.y
            if (s.x + s.width > maxX) maxX = s.x + s.width
            if (s.y + s.height > maxY) maxY = s.y + s.height
        }
        const totalW = maxX - minX
        const totalH = maxY - minY

        root._stitchTmpFiles = []
        let compositeArgs = ""
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i]
            const tmpFile = `/tmp/quickshell-screenshot-${timestamp}-${s.name}.ppm`
            root._stitchTmpFiles.push(tmpFile)
            const offsetX = s.x - minX
            const offsetY = s.y - minY
            compositeArgs += ` "${tmpFile}" -geometry +${offsetX}+${offsetY} -composite`
        }

        // Stage 2 cmd (runs in background after UI shows)
        root._stitchCmd = `magick -size ${totalW}x${totalH} canvas:black${compositeArgs} -define png:compression-level=1 "${tempPath}" && rm -f ${root._stitchTmpFiles.map(f => `"${f}"`).join(" ")}`

        if (root.externalTimestamp || envId) {
            // Under wrapper script: grim is already running/finished in background.
            // Wait for the done file touched by the wrapper script.
            const doneFile = `/tmp/quickshell-screenshot-${timestamp}.done`
            captureProcess.command = ["timeout", "4", "sh", "-c", `while [ ! -f "${doneFile}" ]; do sleep 0.005; done && rm -f "${doneFile}"`]
        } else {
            // Fallback: run grim capture itself if launched directly.
            let grabCmd = "pkill -9 -x grim 2>/dev/null; "
            for (let i = 0; i < screens.length; i++) {
                const s = screens[i]
                const tmpFile = `/tmp/quickshell-screenshot-${timestamp}-${s.name}.ppm`
                grabCmd += `timeout 3 grim -t ppm -o "${s.name}" "${tmpFile}" & `
            }
            grabCmd += "wait"
            captureProcess.command = ["sh", "-c", grabCmd]
        }
        captureProcess.running = true
    }

    // Temp storage for stitch command
    property var _stitchTmpFiles: []
    property string _stitchCmd: ""
    // Instant capture geometry: [x, y, w, h]
    property var _instantGeo: null

    Process {
        id: instantGeoProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("\t")
                if (parts.length === 4) {
                    root._instantGeo = {
                        x: parseInt(parts[0]),
                        y: parseInt(parts[1]),
                        w: parseInt(parts[2]),
                        h: parseInt(parts[3])
                    }
                    root.tryInstantCapture()
                } else {
                    console.warn("Failed to parse instant geometry:", this.text)
                    root.instantCapture = false
                    root.screensFrozen = root.ready
                }
            }
        }
    }

    Process {
        id: captureProcess
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                console.warn("Grim capture failed with exit code:", exitCode)
                Quickshell.execDetached(["notify-send", "Screenshot Failed", "grim capture failed. Try restarting Hyprland.", "-u", "critical"])
                root.exitTool()
                return
            }
            // Grim is done — show UI only for interactive captures
            if (!root.instantCapture) {
                root.screensFrozen = true
            }
            // Start stitch in background — root.ready = true when done
            stitchProcess.command = ["sh", "-c", root._stitchCmd]
            stitchProcess.running = true
        }
    }

    Process {
        id: stitchProcess
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                console.warn("[Screenshot] Stitch failed:", exitCode)
                root.exitTool()
                return
            }
            root.ready = true

            if (!root.instantCapture) {
                root.screensFrozen = true
            }
            root.tryInstantCapture()
        }
    }

    Process {
        id: qrScanProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim()
                if (!output) {
                    root.detectedQRCodes = []
                    return
                }
                var codes = []
                var lines = output.split('\n')
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (!line) continue
                    if (line.startsWith("[ WARN")) continue // Skip OpenCV warnings
                    var parts = line.split('|')
                    if (parts.length >= 5) {
                        codes.push({
                            x: parseInt(parts[0]),
                            y: parseInt(parts[1]),
                            width: parseInt(parts[2]),
                            height: parseInt(parts[3]),
                            data: parts.slice(4).join('|')
                        })
                    }
                }
                root.detectedQRCodes = codes
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim()) console.warn("QR scan stderr:", this.text)
            }
        }
    }

    function startQRScan() {
        if (!tempPath) {
            console.warn("startQRScan: No tempPath")
            return
        }
        var scanScript = Qt.resolvedUrl("src/qr.py").toString().replace("file://", "")
        var cmd = "/usr/bin/python3 '" + scanScript + "' '" + tempPath + "'"
        qrScanProcess.command = ["sh", "-c", cmd]
        qrScanProcess.running = true
    }

    function toggleWindowSelection(win) {
        let index = -1
        for (let i = 0; i < selectedWindows.length; i++) {
            if (selectedWindows[i].address === win.address) {
                index = i
                break
            }
        }

        // Create a copy of the array to ensure change detection works
        let newSelection = []
        for (let i = 0; i < selectedWindows.length; i++) {
            newSelection.push(selectedWindows[i])
        }

        if (index !== -1) {
            newSelection.splice(index, 1)
        } else {
            newSelection.push(win)
        }

        selectedWindows = newSelection
    }

    function toggleScreenSelection(screenName) {
        let index = selectedScreens.indexOf(screenName)

        // Copy array
        let newSelection = []
        for (let i = 0; i < selectedScreens.length; i++) {
            newSelection.push(selectedScreens[i])
        }

        if (index !== -1) {
            newSelection.splice(index, 1)
        } else {
            newSelection.push(screenName)
        }

        selectedScreens = newSelection
    }

    function cleanup() {
        // Release ScreencopyView handles before exit
        root.screensFrozen = false
        if (qrScanProcess.running) qrScanProcess.running = false
        if (tempPath) Quickshell.execDetached(["rm", "-f", tempPath])
        if (cropPath) Quickshell.execDetached(["rm", "-f", cropPath])

        // Clean up raw PPM files if any remain (e.g. if cancelled before stitch)
        if (root._stitchTmpFiles && root._stitchTmpFiles.length > 0) {
            for (var i = 0; i < root._stitchTmpFiles.length; i++) {
                Quickshell.execDetached(["rm", "-f", root._stitchTmpFiles[i]])
            }
        }

        // Clean up the .done file if it exists
        const envId = root.externalTimestamp || (root.isLoadedDynamically ? "" : Quickshell.env("QS_ID")) || ""
        if (envId) {
            Quickshell.execDetached(["rm", "-f", `/tmp/quickshell-screenshot-${envId}.done`])
        }
    }

    Timer {
        id: quitTimer
        interval: 250
        onTriggered: {
            root.exitTool()
        }
    }

    function tryInstantCapture(): void {
        if (!root.instantCapture || !root.ready || !root._instantGeo)
            return
        root.instantCapture = false
        const geometry = root._instantGeo
        root.processScreenshot(geometry.x, geometry.y, geometry.w, geometry.h, false)
    }

    function scheduleExit(): void { quitTimer.restart() }

    Component.onDestruction: cleanup()

    onReadyChanged: {
        if (ready) {
            if (pendingAction) {
                root.processScreenshot(
                    pendingAction.x,
                    pendingAction.y,
                    pendingAction.width,
                    pendingAction.height,
                    pendingAction.openEditor
                )
                root.pendingAction = null
            } else if (!root.instantCapture && tempPath) {
                startQRScan()
            }
        }
    }

    // Screen recording: region (or bounding box of a multi-selection) is
    // handed to ScreenRecorderService in the main shell via IPC. Coords are
    // global compositor coords, matching `slurp` output for gsr -w.
    function startRecording(x, y, width, height) {
        if (selectedWindows.length > 0 || selectedScreens.length > 0) {
            var items = []
            if (selectedWindows.length > 0) {
                for (var i = 0; i < selectedWindows.length; i++) {
                    var w = selectedWindows[i]
                    items.push({
                        x: w.x, y: w.y, width: w.width, height: w.height
                    })
                }
            } else if (selectedScreens.length > 0) {
                for (var j = 0; j < selectedScreens.length; j++) {
                    var name = selectedScreens[j]
                    for (var s = 0; s < Quickshell.screens.length; s++) {
                        if (Quickshell.screens[s].name === name) {
                            var scr = Quickshell.screens[s]
                            items.push({
                                x: scr.x, y: scr.y, width: scr.width, height: scr.height
                            })
                            break
                        }
                    }
                }
            }
            if (items.length > 0) {
                var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
                for (var k = 0; k < items.length; k++) {
                    minX = Math.min(minX, items[k].x)
                    minY = Math.min(minY, items[k].y)
                    maxX = Math.max(maxX, items[k].x + items[k].width)
                    maxY = Math.max(maxY, items[k].y + items[k].height)
                }
                x = minX
                y = minY
                width = maxX - minX
                height = maxY - minY
            }
        }
        if (width < 10 || height < 10) return
        const region = `${Math.round(width)}x${Math.round(height)}+${Math.round(x)}+${Math.round(y)}`
        const sys = root.recordSystemAudio ? "1" : "0"
        const mic = root.recordMic ? "1" : "0"
        Quickshell.execDetached(["quickshell", "ipc", "call", "recorder", "start", region, sys, mic])
        root.scheduleExit()
    }

    function processScreenshot(x, y, width, height, openEditor) {
        if (!root.ready) {
            root.pendingAction = {
                x: x,
                y: y,
                width: width,
                height: height,
                openEditor: openEditor
            }
            return
        }
        // Handle stitching if multiple items selected
        if (selectedWindows.length > 0 || selectedScreens.length > 0) {
            var items = []

            // Collect all regions to stitch
            if (selectedWindows.length > 0) {
                for (var i = 0; i < selectedWindows.length; i++) {
                    var w = selectedWindows[i]
                    items.push({
                        x: w.x, y: w.y, width: w.width, height: w.height
                    })
                }
            } else if (selectedScreens.length > 0) {
                for (var i = 0; i < selectedScreens.length; i++) {
                    var name = selectedScreens[i]
                    for (var s = 0; s < Quickshell.screens.length; s++) {
                        if (Quickshell.screens[s].name === name) {
                            var scr = Quickshell.screens[s]
                            items.push({
                                x: scr.x, y: scr.y, width: scr.width, height: scr.height
                            })
                            break
                        }
                    }
                }
            }

            if (items.length > 0) {
                // Calculate bounding box of all items
                var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
                for (var i = 0; i < items.length; i++) {
                    minX = Math.min(minX, items[i].x)
                    minY = Math.min(minY, items[i].y)
                    maxX = Math.max(maxX, items[i].x + items[i].width)
                    maxY = Math.max(maxY, items[i].y + items[i].height)
                }

                // override input arguments with bounding box
                x = minX
                y = minY
                width = maxX - minX
                height = maxY - minY
                // If we are just saving/copying, use stitching. For analyze, use bounding box.
                if (mode !== "analyze") {
                     const picturesDir = Quickshell.env("SCREENSHOT_DIR") || Quickshell.env("XDG_SCREENSHOTS_DIR") || Quickshell.env("XDG_PICTURES_DIR") || (Quickshell.env("HOME") + "/Pictures")
                    const now = new Date()
                    const timestamp = Qt.formatDateTime(now, "yyyy-MM-dd_hh-mm-ss")
                    const outputPath = root.saveToDisk ? `${picturesDir}/screenshot-${timestamp}.png` : tempPath

                    // Build magick command
                    // Start with empty canvas
                    var cmd = `magick -size ${width}x${height} xc:none `

                    for (var i = 0; i < items.length; i++) {
                        var item = items[i]
                        var cropX = Math.round(item.x - root.minScreenX)
                        var cropY = Math.round(item.y - root.minScreenY)
                        var destX = Math.round(item.x - minX)
                        var destY = Math.round(item.y - minY)

                        cmd += `\\( "${tempPath}" -crop ${item.width}x${item.height}+${cropX}+${cropY} +repage \\) -geometry +${destX}+${destY} -composite `
                    }


                    // Add fast compression to output
                    // Note: -define applies to the write.

                    // Logic reuse: If editor, construct edit command. Else construct save command.
                     if (openEditor) {
                        const cropPath = Quickshell.cachePath(`screenshot-crop-${Date.now()}.png`)
                        // Inject cropPath into the command
                         cmd += `"${cropPath}" && satty --filename "${cropPath}" && rm "${tempPath}"`
                    } else {
                        cmd += `-define png:compression-level=1 "${outputPath}" && ` +
                               `wl-copy < "${outputPath}" && ` +
                               `( if [ "$(notify-send "Screenshot saved" "$(basename "${outputPath}") · copied" -a "Screenshot" -h "string:image-path:${outputPath}" --action=default=Open --wait)" = "default" ]; then xdg-open "${outputPath}"; fi ) & ` +
                               `paplay /usr/share/sounds/freedesktop/stereo/camera-shutter.oga && ` +
                               `rm "${tempPath}"`
                    }

                    Quickshell.execDetached(["sh", "-c", cmd])

                    tempPath = ""
                    root.requestFlash()
                    quitTimer.start()
                    return

                }
            }
        }

        // Standard single region logic below...
        // Ignore tiny accidental drags
        if (width < 10 || height < 10) return

        // Normalize coordinates: subtract the minimum screen offset
        // grim's output image starts at (0,0) for the bounding box of all monitors
        const normalizedX = Math.round(x - root.minScreenX)
        const normalizedY = Math.round(y - root.minScreenY)
        const scaledWidth = Math.round(width)
        const scaledHeight = Math.round(height)

        root.ready = false

        // If shift is held and mode supports editing, open in Satty editor
        const editableModes = ["region", "window", "screen"]
        if (openEditor && editableModes.includes(mode)) {
            const timestamp = Date.now()
            cropPath = Quickshell.cachePath(`screenshot-crop-${timestamp}.png`)
            const cmd = `magick "${tempPath}" -crop ${scaledWidth}x${scaledHeight}+${normalizedX}+${normalizedY} "${cropPath}" && satty --filename "${cropPath}" && rm "${tempPath}"`

            Quickshell.execDetached(["sh", "-c", cmd])

            tempPath = ""
            // Satty handles UI, so maybe no flash? Or flash before?
            // Flash + Quit
            root.requestFlash()
            quitTimer.start()
            return
        }

        if (mode === "analyze" && analyzeEngine === "ai") {
            const timestamp = Date.now()
            cropPath = Quickshell.cachePath(`screenshot-crop-${timestamp}.png`)
            const jsonPath = Quickshell.cachePath(`gemini-request-${timestamp}.json`)
            const b64Path = Quickshell.cachePath(`screenshot-b64-${timestamp}.txt`)
            const responsePath = Quickshell.cachePath(`gemini-response-${timestamp}.json`)
            const apiKey = Quickshell.env("GEMINI_API_KEY") || ""
            // Escape prompt for JSON
            const escapedPrompt = root.aiPrompt.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n')

            const cmd = `magick "${tempPath}" -crop ${scaledWidth}x${scaledHeight}+${normalizedX}+${normalizedY} "${cropPath}" && ` +
                `base64 -w0 "${cropPath}" > "${b64Path}" && ` +
                `{ printf '{"contents":[{"parts":[{"text":"${escapedPrompt}"},{"inline_data":{"mime_type":"image/png","data":"'; cat "${b64Path}"; printf '"}}]}],"generationConfig":{"thinkingConfig":{"thinkingLevel":"low"}}}'; } > "${jsonPath}" && ` +
                `curl -s --max-time 120 "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent" ` +
                `-H "x-goog-api-key: ${apiKey}" ` +
                `-H "Content-Type: application/json" ` +
                `-X POST -d @"${jsonPath}" -o "${responsePath}" && ` +
                `TEXT=$(jq -r '.candidates[0].content.parts[0].text // .error.message // "Error: No response"' "${responsePath}") && ` +
                `printf '%s' "$TEXT" | wl-copy && ` +
                `( if [ "$(notify-send 'AI Analysis' "$TEXT" --action=default=Open --wait)" = "default" ]; then printf '%s' "$TEXT" > /tmp/qs-ai.txt && xdg-open /tmp/qs-ai.txt; fi ) & ` +
                `paplay /usr/share/sounds/freedesktop/stereo/camera-shutter.oga && ` +
                `rm -f "${tempPath}" "${cropPath}" "${jsonPath}" "${b64Path}" "${responsePath}"`

            Quickshell.execDetached(["sh", "-c", cmd])

            // Protect tempPath from cleanup
            tempPath = ""

            root.requestFlash()
            quitTimer.start()

        } else if (mode === "analyze" && analyzeEngine === "text") {
            const cmd = `text=$(magick "${tempPath}" -crop ${scaledWidth}x${scaledHeight}+${normalizedX}+${normalizedY} - | tesseract - - -l eng) && echo -n "$text" | wl-copy && ( if [ "$(notify-send 'OCR Complete' "$text" --action=default=Open --wait)" = "default" ]; then printf '%s' "$text" > /tmp/qs-ocr.txt && xdg-open /tmp/qs-ocr.txt; fi ) & paplay /usr/share/sounds/freedesktop/stereo/camera-shutter.oga && rm "${tempPath}"`
            Quickshell.execDetached(["sh", "-c", cmd])

            tempPath = ""
            root.requestFlash()
            quitTimer.start()

        } else if (mode === "analyze" && analyzeEngine === "lens") {
            const timestamp = Date.now()
            cropPath = Quickshell.cachePath(`screenshot-crop-${timestamp}.png`)
            const cmd = `magick "${tempPath}" -crop ${scaledWidth}x${scaledHeight}+${normalizedX}+${normalizedY} "${cropPath}" && ` +
                `imageLink=$(curl -sF files[]=@"${cropPath}" 'https://uguu.se/upload' | jq -r '.files[0].url') && ` +
                `xdg-open "https://lens.google.com/uploadbyurl?url=\${imageLink}" && ` +
                `rm "${tempPath}" "${cropPath}"`

            Quickshell.execDetached(["sh", "-c", cmd])

            tempPath = ""
            // No flash for Lens usually, but let's add it for consistency or user feedback? keeping as is (sync? no, detached)
            // Original code didn't flash Lens in previous step, but user asked for flash. adding it.
            root.requestFlash()
            quitTimer.start()

        } else {
            const picturesDir = Quickshell.env("SCREENSHOT_DIR") || Quickshell.env("XDG_SCREENSHOTS_DIR") || Quickshell.env("XDG_PICTURES_DIR") || (Quickshell.env("HOME") + "/Pictures")
            const now = new Date()
            const timestamp = Qt.formatDateTime(now, "yyyy-MM-dd_hh-mm-ss")
            const outputPath = root.saveToDisk ? `${picturesDir}/screenshot-${timestamp}.png` : tempPath

            const cmd = `magick "${tempPath}" -define png:compression-level=1 -crop ${scaledWidth}x${scaledHeight}+${normalizedX}+${normalizedY} "${outputPath}" && ` +
                `wl-copy < "${outputPath}" && ` +
                `( if [ "$(notify-send "Screenshot saved" "$(basename "${outputPath}") · copied" -a "Screenshot" -h "string:image-path:${outputPath}" --action=default=Open --wait)" = "default" ]; then xdg-open "${outputPath}"; fi ) & ` +
                `paplay /usr/share/sounds/freedesktop/stereo/camera-shutter.oga && ` +
                `rm "${tempPath}"`

            Quickshell.execDetached(["sh", "-c", cmd])

            tempPath = ""

            // Visual Flash
            root.requestFlash()
            quitTimer.start()
        }
    }

    // Flash removed from here (moved to FreezeScreen)

    Variants {
        // Wait until grim releases screencopy before creating frozen overlays.
        model: root.screensFrozen ? Quickshell.screens : []

        CaptureOverlay {
            controller: root
        }
    }
}
