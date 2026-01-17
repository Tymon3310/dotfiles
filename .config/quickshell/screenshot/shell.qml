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

    // Computed selection rect (normalized)
    property real selectionX: Math.min(globalStartX, globalEndX)
    property real selectionY: Math.min(globalStartY, globalEndY)
    property real selectionWidth: Math.abs(globalEndX - globalStartX)
    property real selectionHeight: Math.abs(globalEndY - globalStartY)

    Component.onCompleted: {
        const timestamp = Date.now()
        tempPath = Quickshell.cachePath(`screenshot-${timestamp}.png`)
        // Capture all monitors into one image
        Quickshell.execDetached(["grim", tempPath])
        showTimer.start()
    }

    Timer {
        id: showTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: root.ready = true
    }

    function cleanup() {
        if (tempPath) Quickshell.execDetached(["rm", "-f", tempPath])
        if (cropPath) Quickshell.execDetached(["rm", "-f", cropPath])
    }

    Process {
        id: screenshotProcess
        running: false

        onExited: () => {
            Qt.quit()
        }

        stdout: StdioCollector {
            onStreamFinished: console.log(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: console.log(this.text)
        }
    }

    function processScreenshot(x, y, width, height, openEditor) {
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
                `magick "${tempPath}" -crop ${scaledWidth}x${scaledHeight}+${normalizedX}+${normalizedY} "${outputPath}" && ` +
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
            
            visible: root.ready
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
                    property real outlineThickness: 2.0

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

                        if (!root.isSelecting) {
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
            }

            WindowSelector {
                visible: root.mode === "window"
                anchors.fill: parent
                monitor: freezeWindow.hyprlandMonitor
                dimOpacity: 0.6
                borderRadius: 10.0
                outlineThickness: 2.0
                onRegionSelected: (x, y, width, height) => {
                    // Window coordinates are screen-local, add screen offset
                    root.processScreenshot(freezeWindow.screenX + x, freezeWindow.screenY + y, width, height, false)
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
            }

            // Control Bar (only on primary/first screen)
            WrapperRectangle {
                visible: freezeWindow.modelData === Quickshell.screens[0]
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

                            Text {
                                text: "Shift+click for editor"
                                color: Qt.rgba(1, 1, 1, 0.5)
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // OCR/Lens hint
                        Text {
                            opacity: (root.mode === "ocr" || root.mode === "lens") ? 1 : 0
                            visible: opacity > 0
                            text: root.mode === "ocr" ? "Select text to extract" : "Select area to search"
                            color: Qt.rgba(1, 1, 1, 0.6)
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on opacity { NumberAnimation { duration: 150 } }
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
