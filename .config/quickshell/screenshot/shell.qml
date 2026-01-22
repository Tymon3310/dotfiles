import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io

import "src"

Scope {
    id: root

    property string tempPath: ""
    property string cropPath: ""
    property bool saveToDisk: true
    property string mode: "region"
    property bool ready: false
    property bool uiReady: false
    property var pendingAction: null
    property bool processing: false
    property var modes: [
        { mode: "region", icon: "region", label: "Region" },
        { mode: "window", icon: "window", label: "Window" },
        { mode: "screen", icon: "screen", label: "Screen" },
        { mode: "ocr", icon: "ocr", label: "OCR" },
        { mode: "lens", icon: "lens", label: "Lens" },
        { mode: "ai", icon: "ai", label: "AI" }
    ]
    property string aiPrompt: "Briefly describe this image in 2-3 sentences."
    property bool shiftHeld: false

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

    // Global selection state (for cross-screen selection)
    property bool isSelecting: false
    property real globalStartX: 0
    property real globalStartY: 0
    property real globalEndX: 0
    property real globalEndY: 0
    
    // Multi-selection state
    property var selectedWindows: [] // Array of window objects (address, x, y, width, height)
    property var selectedScreens: [] // Array of screen names
    property int windowMultiSelectCount: 0

    // Computed selection rect (normalized)
    property real selectionX: Math.min(globalStartX, globalEndX)
    property real selectionY: Math.min(globalStartY, globalEndY)
    property real selectionWidth: Math.abs(globalEndX - globalStartX)
    property real selectionHeight: Math.abs(globalEndY - globalStartY)

    Process {
        id: captureProcess
        running: false
        onExited: {
            root.ready = true
        }
    }

    Component.onCompleted: {
        root.uiReady = true
        const timestamp = Date.now()
        tempPath = Quickshell.cachePath(`screenshot-${timestamp}.png`)
        // Capture all monitors into one image
        captureProcess.command = ["grim", "-l", "0", tempPath]
        captureProcess.running = true
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
        windowMultiSelectCount = selectedWindows.length
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
        if (tempPath) Quickshell.execDetached(["rm", "-f", tempPath])
        if (cropPath) Quickshell.execDetached(["rm", "-f", cropPath])
    }

    Component.onDestruction: cleanup()

    Process {
        id: screenshotProcess
        running: false

        onExited: function() {
            root.cleanup()
            Qt.quit()
        }

        stdout: StdioCollector {
            onStreamFinished: console.log(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: console.log(this.text)
        }
    }

    // QR code detection process
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
                if (this.text.trim()) console.log("QR scan stderr:", this.text)
            }
        }
    }

    function startQRScan() {
        if (!tempPath) return
        var parserScript = Quickshell.shellPath("qr_parse.py")
        var cmd = "/usr/bin/zbarimg --set qrcode.enable=1 -q --xml '" + tempPath + "' | /usr/bin/python3 '" + parserScript + "'"
        qrScanProcess.command = ["sh", "-c", cmd]
        qrScanProcess.running = true
    }



    onReadyChanged: {
        if (ready) {
            if (pendingAction) {
                root.processing = true
                root.processScreenshot(
                    pendingAction.x,
                    pendingAction.y,
                    pendingAction.width,
                    pendingAction.height,
                    pendingAction.openEditor
                )
                root.pendingAction = null
                root.processing = false
            } else if (tempPath) {
                startQRScan()
            }
        }
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
            root.processing = true
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
                // If we are just saving/copying, use stitching. For AI/OCR/Lens, use bounding box.
                // Actually, stitching is better for visuals, bounding box better for context.
                // Let's implement stitching for standard save/copy mode
                if (mode !== "ai" && mode !== "ocr" && mode !== "lens") {
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
                    
                    cmd += `"${outputPath}" && wl-copy < "${outputPath}" && rm "${tempPath}"`
                    
                    // If editor requested
                     if (openEditor) {
                        const cropPath = Quickshell.cachePath(`screenshot-crop-${Date.now()}.png`)
                        // Rewrite command to output to cropPath instead
                        cmd = cmd.replace(`"${outputPath}" &&`, `"${cropPath}" && satty --filename "${cropPath}" &&`)
                    }
                    
                    root.ready = false
                    screenshotProcess.command = ["sh", "-c", cmd]
                    screenshotProcess.running = true
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
            screenshotProcess.command = ["sh", "-c", cmd]
            screenshotProcess.running = true
            return
        }

        if (mode === "ai") {
            const timestamp = Date.now()
            cropPath = Quickshell.cachePath(`screenshot-crop-${timestamp}.png`)
            const jsonPath = Quickshell.cachePath(`gemini-request-${timestamp}.json`)
            const b64Path = Quickshell.cachePath(`screenshot-b64-${timestamp}.txt`)
            const responsePath = Quickshell.cachePath(`gemini-response-${timestamp}.json`)
            const apiKey = Quickshell.env("GEMINI_API_KEY") || ""
            // Escape prompt for JSON
            const escapedPrompt = root.aiPrompt.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n')
            // Build JSON by concatenating parts - avoids passing huge base64 as argument
            const cmd = `exec 2>/tmp/screenshot-ai-error.log; ` +
                `magick "${tempPath}" -crop ${scaledWidth}x${scaledHeight}+${normalizedX}+${normalizedY} "${cropPath}" && ` +
                `base64 -w0 "${cropPath}" > "${b64Path}" && ` +
                `{ printf '{"contents":[{"parts":[{"text":"${escapedPrompt}"},{"inline_data":{"mime_type":"image/png","data":"'; cat "${b64Path}"; printf '"}}]}]}'; } > "${jsonPath}" && ` +
                `curl -s --max-time 120 "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" ` +
                `-H "x-goog-api-key: ${apiKey}" ` +
                `-H "Content-Type: application/json" ` +
                `-X POST -d @"${jsonPath}" -o "${responsePath}" && ` +
                `TEXT=$(jq -r '.candidates[0].content.parts[0].text // .error.message // "Error: No response"' "${responsePath}") && ` +
                `printf '%s' "$TEXT" | wl-copy && ` +
                `notify-send 'AI Analysis' "$TEXT" && ` +
                `rm -f "${tempPath}" "${cropPath}" "${jsonPath}" "${b64Path}" "${responsePath}"`
            screenshotProcess.command = ["sh", "-c", cmd]
            screenshotProcess.running = true
        } else if (mode === "ocr") {
            const cmd = `text=$(magick "${tempPath}" -crop ${scaledWidth}x${scaledHeight}+${normalizedX}+${normalizedY} - | tesseract - - -l eng) && echo -n "$text" | wl-copy && notify-send 'OCR Complete' "$text" && rm "${tempPath}"`
            screenshotProcess.command = ["sh", "-c", cmd]
            screenshotProcess.running = true
        } else if (mode === "lens") {
            const timestamp = Date.now()
            cropPath = Quickshell.cachePath(`screenshot-crop-${timestamp}.png`)
            const cmd = `magick "${tempPath}" -crop ${scaledWidth}x${scaledHeight}+${normalizedX}+${normalizedY} "${cropPath}" && ` +
                `imageLink=$(curl -sF files[]=@"${cropPath}" 'https://uguu.se/upload' | jq -r '.files[0].url') && ` +
                `xdg-open "https://lens.google.com/uploadbyurl?url=\${imageLink}" && ` +
                `rm "${tempPath}" "${cropPath}"`
            screenshotProcess.command = ["sh", "-c", cmd]
            screenshotProcess.running = true
        } else {
            const picturesDir = Quickshell.env("SCREENSHOT_DIR") || Quickshell.env("XDG_SCREENSHOTS_DIR") || Quickshell.env("XDG_PICTURES_DIR") || (Quickshell.env("HOME") + "/Pictures")
            const now = new Date()
            const timestamp = Qt.formatDateTime(now, "yyyy-MM-dd_hh-mm-ss")
            const outputPath = root.saveToDisk ? `${picturesDir}/screenshot-${timestamp}.png` : tempPath

            screenshotProcess.command = ["sh", "-c",
                `magick "${tempPath}" -define png:compression-level=1 -crop ${scaledWidth}x${scaledHeight}+${normalizedX}+${normalizedY} "${outputPath}" && ` +
                `wl-copy < "${outputPath}" && ` +
                `rm "${tempPath}"`
            ]
            screenshotProcess.running = true
        }
    }


    Variants {
        model: Quickshell.screens

        FreezeScreen {
            id: freezeWindow
            required property var modelData
            
            visible: root.uiReady
            targetScreen: modelData

            property real screenX: modelData.x
            property real screenY: modelData.y
            property var hyprlandMonitor: Hyprland.focusedMonitor

            Shortcut {
                sequence: "Escape"
                onActivated: () => {
                    root.cleanup()
                    Qt.quit()
                }
            }



            // Region/OCR/Lens/AI selector with cross-screen support
            Item {
                id: crossScreenSelector
                visible: root.mode === "region" || root.mode === "ocr" || root.mode === "lens" || root.mode === "ai"
                anchors.fill: parent

                // Calculate local selection rect for this screen
                property real localSelX: root.selectionX - freezeWindow.screenX
                property real localSelY: root.selectionY - freezeWindow.screenY
                property real localSelWidth: root.selectionWidth
                property real localSelHeight: root.selectionHeight

                // Clamp to screen bounds
                property real clampedX: Math.max(0, localSelX)
                property real clampedY: Math.max(0, localSelY)
                property real clampedRight: Math.min(freezeWindow.modelData.width, localSelX + localSelWidth)
                property real clampedBottom: Math.min(freezeWindow.modelData.height, localSelY + localSelHeight)
                property real clampedWidth: Math.max(0, clampedRight - clampedX)
                property real clampedHeight: Math.max(0, clampedBottom - clampedY)

                property real mouseX: 0
                property real mouseY: 0

                onClampedXChanged: canvas.requestPaint()
                onClampedYChanged: canvas.requestPaint()
                onClampedWidthChanged: canvas.requestPaint()
                onClampedHeightChanged: canvas.requestPaint()
                onMouseXChanged: canvas.requestPaint()
                onMouseYChanged: canvas.requestPaint()

                // Dimming shader
                ShaderEffect {
                    anchors.fill: parent
                    z: 0

                    property vector4d selectionRect: Qt.vector4d(
                        crossScreenSelector.clampedX,
                        crossScreenSelector.clampedY,
                        crossScreenSelector.clampedWidth,
                        crossScreenSelector.clampedHeight
                    )
                    property real dimOpacity: 0.6
                    property vector2d screenSize: Qt.vector2d(parent.width, parent.height)
                    property real borderRadius: 10.0
                    property real outlineThickness: (crossScreenSelector.clampedWidth > 1 && crossScreenSelector.clampedHeight > 1) ? 2.0 : 0.0

                    fragmentShader: Qt.resolvedUrl("shaders/dimming.frag.qsb")
                }

                // Crosshair / guides
                Canvas {
                    id: canvas
                    anchors.fill: parent
                    z: 2

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        ctx.beginPath();
                        ctx.strokeStyle = "rgba(255, 255, 255, 0.5)";
                        ctx.lineWidth = 1;
                        ctx.setLineDash([5, 5]);

                        if (!root.isSelecting && regionMouseArea.containsMouse) {
                            // Crosshair at mouse cursor
                            ctx.moveTo(crossScreenSelector.mouseX, 0);
                            ctx.lineTo(crossScreenSelector.mouseX, height);
                            ctx.moveTo(0, crossScreenSelector.mouseY);
                            ctx.lineTo(width, crossScreenSelector.mouseY);
                        } else {
                            // Guides around selection
                            const x = crossScreenSelector.clampedX
                            const y = crossScreenSelector.clampedY
                            const w = crossScreenSelector.clampedWidth
                            const h = crossScreenSelector.clampedHeight
                            if (w > 0 && h > 0) {
                                ctx.moveTo(x, 0); ctx.lineTo(x, height);
                                ctx.moveTo(x + w, 0); ctx.lineTo(x + w, height);
                                ctx.moveTo(0, y); ctx.lineTo(width, y);
                                ctx.moveTo(0, y + h); ctx.lineTo(width, y + h);
                            }
                        }
                        ctx.stroke();
                    }
                }

                MouseArea {
                    id: regionMouseArea
                    anchors.fill: parent
                    z: 3
                    hoverEnabled: true
                    cursorShape: Qt.CrossCursor
                    acceptedButtons: Qt.LeftButton

                    onPressed: (mouse) => {
                        root.shiftHeld = (mouse.modifiers & Qt.ShiftModifier)
                        root.isSelecting = true
                        const globalX = freezeWindow.screenX + mouse.x
                        const globalY = freezeWindow.screenY + mouse.y
                        root.globalStartX = globalX
                        root.globalStartY = globalY
                        root.globalEndX = globalX
                        root.globalEndY = globalY
                    }

                    onPositionChanged: (mouse) => {
                        crossScreenSelector.mouseX = mouse.x
                        crossScreenSelector.mouseY = mouse.y

                        if (pressed) {
                            root.globalEndX = freezeWindow.screenX + mouse.x
                            root.globalEndY = freezeWindow.screenY + mouse.y
                        }
                    }

                    onReleased: (mouse) => {
                        const openEditor = (mouse.modifiers & Qt.ShiftModifier) || root.shiftHeld
                        root.isSelecting = false
                        root.processScreenshot(
                            root.selectionX,
                            root.selectionY,
                            root.selectionWidth,
                            root.selectionHeight,
                            openEditor
                        )
                    }
                }

                // QR Code overlays - visible in lens mode
                Repeater {
                    model: root.mode === "lens" ? root.detectedQRCodes : []

                    Rectangle {
                        id: qrOverlay
                        required property var modelData
                        required property int index

                        // Convert image coordinates to local screen coordinates
                        property real imgX: modelData.x + root.minScreenX
                        property real imgY: modelData.y + root.minScreenY
                        property real localX: imgX - freezeWindow.screenX
                        property real localY: imgY - freezeWindow.screenY

                        // Only show if QR code is on this screen
                        visible: localX + modelData.width > 0 && localX < freezeWindow.modelData.width &&
                                 localY + modelData.height > 0 && localY < freezeWindow.modelData.height

                        x: localX - 8
                        y: localY - 8
                        width: modelData.width + 16
                        height: modelData.height + 16
                        radius: 8
                        color: qrMouseArea.containsMouse ? Qt.rgba(0.2, 0.6, 1.0, 0.3) : Qt.rgba(0.2, 0.6, 1.0, 0.15)
                        border.color: Qt.rgba(0.3, 0.7, 1.0, 0.9)
                        border.width: 2
                        z: 5

                        Behavior on color { ColorAnimation { duration: 100 } }

                        // QR icon badge
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: -6
                            width: 28
                            height: 28
                            radius: 14
                            color: Qt.rgba(0.2, 0.5, 0.9, 0.95)

                            Image {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                sourceSize: Qt.size(64, 64)
                                source: Quickshell.shellPath("icons/qr.svg")
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        // Data preview tooltip
                        Rectangle {
                            visible: qrMouseArea.containsMouse
                            anchors.top: parent.bottom
                            anchors.left: parent.left
                            anchors.topMargin: 8
                            width: qrDataColumn.width + 24
                            height: qrDataColumn.height + 12
                            radius: 6
                            color: Qt.rgba(0.1, 0.1, 0.1, 0.95)
                            z: 10

                            Column {
                                id: qrDataColumn
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: qrOverlay.modelData.data.length > 60 
                                        ? qrOverlay.modelData.data.substring(0, 60) + "..." 
                                        : qrOverlay.modelData.data
                                    color: "white"
                                    font.pixelSize: 12
                                }

                                Text {
                                    text: "Click to copy" + (qrOverlay.modelData.data.indexOf("http") === 0 ? " & open" : "")
                                    color: Qt.rgba(0.5, 0.8, 1.0, 0.7)
                                    font.pixelSize: 10
                                }
                            }
                        }

                        MouseArea {
                            id: qrMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 10

                            onClicked: {
                                var data = qrOverlay.modelData.data
                                var isUrl = data.indexOf("http://") === 0 || data.indexOf("https://") === 0
                                var cmd = isUrl
                                    ? "printf '%s' '" + data.replace(/'/g, "'\"'\"'") + "' | wl-copy && notify-send 'QR Code' 'Copied & opening...' && xdg-open '" + data.replace(/'/g, "'\"'\"'") + "'"
                                    : "printf '%s' '" + data.replace(/'/g, "'\"'\"'") + "' | wl-copy && notify-send 'QR Code' 'Copied to clipboard'"
                                cmd += " && rm '" + root.tempPath + "'"
                                root.ready = false
                                screenshotProcess.command = ["sh", "-c", cmd]
                                screenshotProcess.running = true
                            }
                        }
                    }
                }
            }

            WindowSelector {
                visible: root.mode === "window"
                anchors.fill: parent
                monitor: freezeWindow.hyprlandMonitor
                screenX: freezeWindow.screenX
                screenY: freezeWindow.screenY
                dimOpacity: 0.6
                borderRadius: 10.0
                outlineThickness: 2.0
                
                // Pass root-level selection state
                globalSelectedWindows: root.selectedWindows
                
                onRegionSelected: (x, y, width, height, openEditor) => {
                    // Clear multi-selection because user clicked a specific window to capture IT ONLY
                    root.selectedWindows = []
                    root.selectedScreens = []
                    root.windowMultiSelectCount = 0
                    
                    // Window coordinates are already global from WindowSelector
                    root.processScreenshot(x, y, width, height, openEditor)
                }
                onCaptureRequested: (openEditor) => {
                    // Capture all selected windows (stitching)
                    root.processScreenshot(0, 0, 0, 0, openEditor)
                }
                onWindowToggled: (windowInfo) => {
                    root.toggleWindowSelection(windowInfo)
                }
            }

            // Screen mode - click anywhere on this monitor to capture it
            Item {
                id: screenSelector
                visible: root.mode === "screen"
                anchors.fill: parent

                property bool isHovered: false

                // Dimming shader - highlight full screen when hovered
                ShaderEffect {
                    anchors.fill: parent
                    z: 0

                    property vector4d selectionRect: Qt.vector4d(
                        screenSelector.isHovered ? 0 : 0,
                        screenSelector.isHovered ? 0 : 0,
                        screenSelector.isHovered ? parent.width : 0,
                        screenSelector.isHovered ? parent.height : 0
                    )
                    property real dimOpacity: 0.6
                    property vector2d screenSize: Qt.vector2d(parent.width, parent.height)
                    property real borderRadius: 10.0
                    property real outlineThickness: 2.0

                    fragmentShader: Qt.resolvedUrl("shaders/dimming.frag.qsb")
                }

                // Monitor label
                Rectangle {
                    visible: screenSelector.isHovered
                    anchors.centerIn: parent
                    width: monitorLabel.width + 40
                    height: monitorLabel.height + 20
                    radius: 12
                    color: Qt.rgba(0.1, 0.1, 0.1, 0.8)

                    Text {
                        id: monitorLabel
                        anchors.centerIn: parent
                        text: freezeWindow.modelData.name + "\n" + freezeWindow.modelData.width + " × " + freezeWindow.modelData.height
                        color: "white"
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: 3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onEntered: screenSelector.isHovered = true
                    onExited: screenSelector.isHovered = false

                    onClicked: (mouse) => {
                        // Multi-selection with Ctrl
                        if (mouse.modifiers & Qt.ControlModifier) {
                            root.toggleScreenSelection(freezeWindow.modelData.name)
                            return
                        }

                        // If clicking a selected screen, capture all selected screens
                        if (root.selectedScreens.indexOf(freezeWindow.modelData.name) !== -1 && root.selectedScreens.length > 0) {
                            root.processScreenshot(0, 0, 0, 0, false)
                            return
                        }

                        // Otherwise clear selection and capture just this screen
                        root.selectedWindows = []
                        root.selectedScreens = []
                        root.windowMultiSelectCount = 0

                        const openEditor = (mouse.modifiers & Qt.ShiftModifier)
                        root.processScreenshot(
                            freezeWindow.screenX,
                            freezeWindow.screenY,
                            freezeWindow.modelData.width,
                            freezeWindow.modelData.height,
                            openEditor
                        )
                    }
                }

                // Selection indicator
                Rectangle {
                    visible: root.selectedScreens.indexOf(freezeWindow.modelData.name) !== -1
                    anchors.fill: parent
                    color: Qt.rgba(0.2, 0.6, 1.0, 0.3)
                    border.color: Qt.rgba(0.4, 0.8, 1.0, 0.8)
                    border.width: 4
                    z: 5
                }
            }

            // Control Bar (only on primary/first screen)
            WrapperRectangle {
                visible: freezeWindow.modelData.name === Hyprland.focusedMonitor.name
                z: 10
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40

                color: Qt.rgba(0.1, 0.1, 0.1, 0.85)
                radius: 16
                margin: 10

                Row {
                    id: mainRow
                    spacing: 16

                    Row {
                        id: buttonRow
                        spacing: 6

                        Repeater {
                            model: root.modes

                            Button {
                                id: modeButton
                                implicitWidth: 52
                                implicitHeight: 52

                                background: Rectangle {
                                    radius: 10
                                    color: {
                                        if (root.mode === modelData.mode) return Qt.rgba(0.3, 0.5, 0.8, 0.7)
                                        if (modeButton.hovered) return Qt.rgba(0.4, 0.4, 0.4, 0.5)
                                        return Qt.rgba(0.25, 0.25, 0.3, 0.5)
                                    }
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                contentItem: Column {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Image {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 24
                                        height: 24
                                        sourceSize: Qt.size(96, 96)
                                        source: Quickshell.shellPath(`icons/${modelData.icon}.svg`)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        antialiasing: true
                                        mipmap: true
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        color: "white"
                                        font.pixelSize: 9
                                        font.weight: root.mode === modelData.mode ? Font.DemiBold : Font.Normal
                                    }
                                }

                                onClicked: {
                                    root.mode = modelData.mode
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 40
                        color: Qt.rgba(1, 1, 1, 0.2)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Options panel with fixed width to prevent layout shifts
                    Item {
                        id: optionsPanel
                        width: 320
                        height: 40
                        anchors.verticalCenter: parent.verticalCenter

                        // Save toggle - for region/window/screen modes
                        Row {
                            id: saveRow
                            opacity: (root.mode === "region" || root.mode === "window" || root.mode === "screen") ? 1 : 0
                            visible: opacity > 0
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            Text {
                                text: "Save to disk"
                                color: "#ffffff"
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Switch {
                                id: saveSwitch
                                checked: root.saveToDisk
                                onCheckedChanged: root.saveToDisk = checked
                            }

                            Text {
                                text: "│"
                                color: Qt.rgba(1, 1, 1, 0.3)
                                font.pixelSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                // Stitch count hint
                                Text {
                                    visible: root.selectedScreens.length > 0 || root.windowMultiSelectCount > 0
                                    text: {
                                        if (root.selectedScreens.length > 0) return "Stitch: " + root.selectedScreens.length + " screens"
                                        if (root.windowMultiSelectCount > 0) return "Stitch: " + root.windowMultiSelectCount + " windows"
                                        return ""
                                    }
                                    color: Qt.rgba(0.5, 0.8, 1.0, 0.9)
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                }

                                // Shift+click hint
                                Text {
                                    text: "Shift+click for editor"
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                    font.pixelSize: 10
                                }

                                // Ctrl+click hint
                                Text {
                                    visible: root.mode === "window" || root.mode === "screen"
                                    text: "Ctrl+click to multi-select"
                                    color: Qt.rgba(1, 1, 1, 0.35)
                                    font.pixelSize: 9
                                }
                            }
                        }

                        // OCR/Lens hint
                        Column {
                            opacity: (root.mode === "ocr" || root.mode === "lens") ? 1 : 0
                            visible: opacity > 0
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            Text {
                                text: root.mode === "ocr" ? "Select text to extract" : "Select area to search"
                                color: Qt.rgba(1, 1, 1, 0.6)
                                font.pixelSize: 12
                            }

                            Text {
                                visible: root.mode === "lens"
                                text: root.detectedQRCodes.length > 0 
                                    ? root.detectedQRCodes.length + " QR code" + (root.detectedQRCodes.length > 1 ? "s" : "") + " detected"
                                    : "No QR codes detected"
                                color: root.detectedQRCodes.length > 0 ? Qt.rgba(0.4, 0.8, 1.0, 0.8) : Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 10
                            }
                        }

                        // AI Prompt input
                        Row {
                            opacity: root.mode === "ai" ? 1 : 0
                            visible: opacity > 0
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right

                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            Text {
                                text: "Prompt:"
                                color: "#ffffff"
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                id: promptBox
                                width: parent.width - 60
                                height: 36
                                radius: 8
                                color: promptInput.activeFocus ? Qt.rgba(0.15, 0.15, 0.2, 0.95) : Qt.rgba(0.2, 0.2, 0.25, 0.8)
                                border.color: promptInput.activeFocus ? Qt.rgba(0.4, 0.6, 1.0, 0.6) : Qt.rgba(1, 1, 1, 0.15)
                                border.width: promptInput.activeFocus ? 2 : 1

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                TextInput {
                                    id: promptInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: "#ffffff"
                                    font.pixelSize: 12
                                    text: root.aiPrompt
                                    clip: true
                                    selectByMouse: true
                                    selectedTextColor: "#ffffff"
                                    selectionColor: Qt.rgba(0.3, 0.5, 0.8, 0.6)
                                    onTextChanged: root.aiPrompt = text

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: "Describe what to analyze..."
                                        color: Qt.rgba(1, 1, 1, 0.35)
                                        font.pixelSize: 12
                                        visible: !promptInput.text && !promptInput.activeFocus
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
