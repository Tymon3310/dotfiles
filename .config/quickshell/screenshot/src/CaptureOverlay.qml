import QtQuick
import Quickshell.Hyprland

// Per-screen selection and frozen image. Capture work stays in the coordinator.
FreezeScreen {
    id: freezeWindow
    required property var modelData
    required property var controller

    Connections {
        target: freezeWindow.controller
        function onRequestFlash() {
            freezeWindow.triggerFlash()
        }
    }

    visible: true
    targetScreen: modelData

    property real screenX: modelData.x
    property real screenY: modelData.y
    property var hyprlandMonitor: Hyprland.focusedMonitor

    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: true

        Component.onCompleted: keyScope.forceActiveFocus()

        Connections {
            target: freezeWindow
            function onFrozenChanged() {
                if (freezeWindow.frozen) keyScope.forceActiveFocus()
            }
            function onVisibleChanged() {
                if (freezeWindow.visible) keyScope.forceActiveFocus()
            }
        }

        Keys.onPressed: (event) => {
            if (freezeWindow.controller.promptFocused) {
                if (event.key === Qt.Key_Escape) {
                    freezeWindow.controller.promptFocused = false
                    keyScope.forceActiveFocus()
                    event.accepted = true
                }
                return
            }

            switch (event.key) {
            case Qt.Key_Escape:
                freezeWindow.controller.exitTool()
                event.accepted = true
                break
            case Qt.Key_1:
                freezeWindow.controller.mode = "region"
                event.accepted = true
                break
            case Qt.Key_2:
                freezeWindow.controller.mode = "window"
                event.accepted = true
                break
            case Qt.Key_3:
                freezeWindow.controller.mode = "screen"
                event.accepted = true
                break
            case Qt.Key_4:
                freezeWindow.controller.mode = "analyze"
                event.accepted = true
                break
            case Qt.Key_5:
                freezeWindow.controller.mode = "record"
                event.accepted = true
                break
            case Qt.Key_T:
                if (freezeWindow.controller.mode === "analyze") {
                    freezeWindow.controller.analyzeEngine = "text"
                    event.accepted = true
                }
                break
            case Qt.Key_A:
                if (freezeWindow.controller.mode === "analyze") {
                    freezeWindow.controller.analyzeEngine = "ai"
                    event.accepted = true
                }
                break
            case Qt.Key_L:
                if (freezeWindow.controller.mode === "analyze") {
                    freezeWindow.controller.analyzeEngine = "lens"
                    event.accepted = true
                }
                break
            case Qt.Key_Shift:
                freezeWindow.controller.shiftDown = true
                event.accepted = true
                break
            case Qt.Key_Control:
                freezeWindow.controller.ctrlDown = true
                event.accepted = true
                break
            case Qt.Key_S:
                freezeWindow.controller.saveToDisk = !freezeWindow.controller.saveToDisk
                event.accepted = true
                break
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                if (freezeWindow.controller.mode === "screen" || freezeWindow.controller.mode === "record") {
                    if (freezeWindow.controller.mode === "record") {
                        freezeWindow.controller.startRecording(freezeWindow.screenX, freezeWindow.screenY, freezeWindow.modelData.width, freezeWindow.modelData.height)
                    } else {
                        freezeWindow.controller.processScreenshot(freezeWindow.screenX, freezeWindow.screenY, freezeWindow.modelData.width, freezeWindow.modelData.height, false)
                    }
                    event.accepted = true
                }
                break
            }
        }

        Keys.onReleased: (event) => {
            if (event.key === Qt.Key_Shift)
                freezeWindow.controller.shiftDown = false
            else if (event.key === Qt.Key_Control)
                freezeWindow.controller.ctrlDown = false
        }



        RegionSelection {
            controller: freezeWindow.controller
            screenX: freezeWindow.screenX
            screenY: freezeWindow.screenY
        }

        WindowSelector {
            // Record mode: hold Shift for per-window picking.
            visible: freezeWindow.controller.mode === "window"
                || (freezeWindow.controller.mode === "record" && freezeWindow.controller.shiftDown)
            dimBackground: freezeWindow.controller.mode !== "record"
            multiSelect: freezeWindow.controller.mode !== "record"
            anchors.fill: parent
            monitor: freezeWindow.hyprlandMonitor
            screenX: freezeWindow.screenX
            screenY: freezeWindow.screenY
            dimOpacity: 0.6
            borderRadius: 10.0
            outlineThickness: 2.0

            // Pass root-level selection state
            globalSelectedWindows: freezeWindow.controller.selectedWindows

            onRegionSelected: (x, y, width, height, openEditor) => {
                // Clear multi-selection because user clicked a specific window to capture IT ONLY
                freezeWindow.controller.selectedWindows = []
                freezeWindow.controller.selectedScreens = []

                // Window coordinates are already global from WindowSelector
                if (freezeWindow.controller.mode === "record")
                    freezeWindow.controller.startRecording(x, y, width, height)
                else
                    freezeWindow.controller.processScreenshot(x, y, width, height, openEditor)
            }
            onCaptureRequested: (openEditor) => {
                // Capture all selected windows (stitching)
                freezeWindow.controller.processScreenshot(0, 0, 0, 0, openEditor)
            }
            onWindowToggled: (windowInfo) => {
                freezeWindow.controller.toggleWindowSelection(windowInfo)
            }
        }

        // Screen mode - click anywhere on this monitor to capture it.
        // Record mode: hold Ctrl to pick a monitor (the region layer already
        // dims, so this layer only highlights on hover).
        Item {
            id: screenSelector
            visible: freezeWindow.controller.mode === "screen"
                || (freezeWindow.controller.mode === "record"
                    && freezeWindow.controller.ctrlDown
                    && !freezeWindow.controller.shiftDown)
            anchors.fill: parent

            property bool isHovered: false
            property real pressX: 0
            property real pressY: 0
            readonly property bool recordMode: freezeWindow.controller.mode === "record"

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
                property real dimOpacity: (screenSelector.recordMode && !screenSelector.isHovered) ? 0 : Theme.captureWash.a
                property vector2d screenSize: Qt.vector2d(parent.width, parent.height)
                property real borderRadius: Theme.radiusLarge
                property real outlineThickness: screenSelector.isHovered ? 3.0 : 0.0
                property color outlineColor: Theme.accent

                fragmentShader: Qt.resolvedUrl("../shaders/dimming.frag.qsb")
            }

            // Monitor label
            Rectangle {
                visible: screenSelector.isHovered
                anchors.centerIn: parent
                width: monitorLabelColumn.width + 48
                height: monitorLabelColumn.height + 24
                radius: Theme.radiusLarge
                color: Theme.island
                border.color: Theme.islandBorder
                border.width: 1

                Column {
                    id: monitorLabelColumn
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: freezeWindow.modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: freezeWindow.modelData.width + " × " + freezeWindow.modelData.height
                        color: Theme.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeRegular
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: 3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: screenSelector.isHovered = true
                onExited: screenSelector.isHovered = false

                onPressed: (mouse) => {
                    screenSelector.pressX = mouse.x
                    screenSelector.pressY = mouse.y
                }

                onClicked: (mouse) => {
                    // Ignore drags ending here (region selection owns those)
                    if (Math.hypot(mouse.x - screenSelector.pressX, mouse.y - screenSelector.pressY) > 6)
                        return
                    // Record mode: Ctrl is only the picker modifier, record this monitor
                    if (screenSelector.recordMode) {
                        freezeWindow.controller.startRecording(
                            freezeWindow.screenX,
                            freezeWindow.screenY,
                            freezeWindow.modelData.width,
                            freezeWindow.modelData.height
                        )
                        return
                    }

                    // Multi-selection with Ctrl
                    if (mouse.modifiers & Qt.ControlModifier) {
                        freezeWindow.controller.toggleScreenSelection(freezeWindow.modelData.name)
                        return
                    }

                    // If clicking a selected screen, capture all selected screens
                    if (freezeWindow.controller.selectedScreens.indexOf(freezeWindow.modelData.name) !== -1 && freezeWindow.controller.selectedScreens.length > 0) {
                        freezeWindow.controller.processScreenshot(0, 0, 0, 0, false)
                        return
                    }

                    // Otherwise clear selection and capture just this screen
                    freezeWindow.controller.selectedWindows = []
                    freezeWindow.controller.selectedScreens = []

                    const openEditor = (mouse.modifiers & Qt.ShiftModifier)
                    freezeWindow.controller.processScreenshot(
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
                visible: freezeWindow.controller.selectedScreens.indexOf(freezeWindow.modelData.name) !== -1
                anchors.fill: parent
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                border.color: Theme.accent
                border.width: 3
                z: 5
            }
        }

        CaptureToolbar {
            id: bottomNotch
            controller: freezeWindow.controller
            frozen: freezeWindow.frozen
            primary: freezeWindow.modelData === freezeWindow.controller.primaryScreen
        }

        // Notch fillets where the bottom notch meets the bottom bezel
        NotchFillet {
            z: 10
            visible: bottomNotch.visible
            x: bottomNotch.x - width
            y: bottomNotch.y + bottomNotch.height - height
            mirrored: true
            atBottom: true
            color: Theme.island
        }

        NotchFillet {
            z: 10
            visible: bottomNotch.visible
            x: bottomNotch.x + bottomNotch.width
            y: bottomNotch.y + bottomNotch.height - height
            atBottom: true
            color: Theme.island
        }
    }
}
