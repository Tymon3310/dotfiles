import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    property var monitor: Hyprland.focusedMonitor
    property var windows: []
    property int _activeWsId: -1

    // Screen position for coordinate conversion
    property real screenX: 0
    property real screenY: 0

    // Global selected windows from parent (in global coords)
    property var globalSelectedWindows: []

    signal checkHover(real mouseX, real mouseY)
    signal regionSelected(real x, real y, real width, real height, bool openEditor)
    signal windowToggled(var windowInfo)  // Emit when ctrl+click to toggle
    signal captureRequested(bool openEditor)  // Emit when clicking on selected window

    // Shader customization properties
    property real dimOpacity: 0.6
    property real borderRadius: 10.0
    property real outlineThickness: 2.0
    property url fragmentShader: Qt.resolvedUrl("../shaders/dimming.frag.qsb")

    // Hover state (screen-local coords for display)
    property real selectionX: 0
    property real selectionY: 0
    property real selectionWidth: 0
    property real selectionHeight: 0
    property bool hasSelection: false
    property string windowTitle: ""
    property string windowClass: ""
    property var hoveredWindow: null  // In GLOBAL coords



    // Removed SpringAnimations for instant responsiveness

    function refreshWindows() {
        if (root.visible) {
            _wsQuery.running = true
        }
    }

    Process {
        id: _wsQuery
        running: false
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root._activeWsId = JSON.parse(this.text).id
                    _clientsQuery.running = true
                } catch (e) {
                    console.log("WindowSelector: failed to parse active workspace:", e)
                }
            }
        }
    }

    Process {
        id: _clientsQuery
        running: false
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var clients = JSON.parse(this.text)
                    var windows = []
                    for (var i = 0; i < clients.length; i++) {
                        var c = clients[i]
                        if (c.workspace && c.workspace.id === root._activeWsId) {
                            windows.push({ lastIpcObject: c })
                        }
                    }
                    root.windows = windows
                } catch (e) {
                    console.log("WindowSelector: failed to parse clients:", e)
                }
            }
        }
    }

    Timer {
        id: _refreshTimer
        interval: 200
        running: root.visible
        repeat: true
        onTriggered: root.refreshWindows()
    }

    onVisibleChanged: if (visible) refreshWindows()

    Component.onCompleted: refreshWindows()

    // Check if a window (in global coords) is selected
    function isWindowSelectedGlobal(windowInfo) {
        if (!windowInfo) return false
        for (var i = 0; i < globalSelectedWindows.length; i++) {
            if (windowInfo.address && globalSelectedWindows[i].address === windowInfo.address) {
                return true
            }
            // Fallback for older objects without address
            if (globalSelectedWindows[i].x === windowInfo.x && 
                globalSelectedWindows[i].y === windowInfo.y &&
                globalSelectedWindows[i].width === windowInfo.width &&
                globalSelectedWindows[i].height === windowInfo.height) {
                return true
            }
        }
        return false
    }

    // Dimming overlay (dims everything)
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, root.dimOpacity)
        z: 0
    }

    // Highlight for hovered window (not yet selected)
    Rectangle {
        visible: root.hasSelection && !isWindowSelectedGlobal(root.hoveredWindow)
        x: root.selectionX
        y: root.selectionY
        width: root.selectionWidth
        height: root.selectionHeight
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.6)
        border.width: 2
        radius: root.borderRadius
        z: 1

        // Clear cutout effect
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: root.borderRadius - 2
            color: Qt.rgba(1, 1, 1, 0.1)
        }
    }

    // Repeater for selected windows highlights (convert global to local)
    Repeater {
        model: root.globalSelectedWindows

        Rectangle {
            // Convert global coords to local screen coords
            property real localX: modelData.x - root.screenX
            property real localY: modelData.y - root.screenY
            
            // Only show if this window is on this screen
            visible: localX >= -modelData.width && localX < root.width &&
                     localY >= -modelData.height && localY < root.height

            x: localX
            y: localY
            width: modelData.width
            height: modelData.height
            color: "transparent"
            border.color: Qt.rgba(0.3, 0.6, 1.0, 0.9)
            border.width: 3
            radius: root.borderRadius
            z: 2

            // Bright highlight for selected
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: root.borderRadius - 3
                color: Qt.rgba(0.3, 0.5, 0.8, 0.15)
            }

            // Selection badge
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                width: 24
                height: 24
                radius: 12
                color: Qt.rgba(0.3, 0.6, 1.0, 0.9)

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    color: "white"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }
            }
        }
    }

    // Window title label for hovered window
    Rectangle {
        visible: root.hasSelection && root.windowTitle
        x: root.selectionX + (root.selectionWidth - width) / 2
        y: root.selectionY + (root.selectionHeight - height) / 2
        width: windowLabelColumn.width + 32
        height: windowLabelColumn.height + 16
        radius: 10
        color: Qt.rgba(0.1, 0.1, 0.1, 0.85)
        z: 3

        Column {
            id: windowLabelColumn
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.windowTitle
                color: "white"
                font.pixelSize: 14
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                width: Math.min(implicitWidth, root.selectionWidth - 48)
            }

            Text {
                visible: root.windowClass && root.windowClass !== root.windowTitle
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.windowClass
                color: Qt.rgba(1, 1, 1, 0.5)
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(root.selectionWidth) + " × " + Math.round(root.selectionHeight)
                color: Qt.rgba(1, 1, 1, 0.4)
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Selection count indicator
    Rectangle {
        visible: root.globalSelectedWindows.length > 1
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 150
        width: selectionInfoColumn.width + 32
        height: selectionInfoColumn.height + 16
        radius: 8
        color: Qt.rgba(0.1, 0.1, 0.1, 0.9)
        z: 4

        Column {
            id: selectionInfoColumn
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.globalSelectedWindows.length + " windows selected • Click to capture"
                color: Qt.rgba(0.5, 0.8, 1.0, 1.0)
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }

    Repeater {
        model: root.windows

        Item {
            required property var modelData

            Connections {
                target: root

                function onCheckHover(mouseX, mouseY) {
                    if (!modelData || !modelData.lastIpcObject || !modelData.lastIpcObject.at || !modelData.lastIpcObject.size) return

                    // mouseX, mouseY are in screen-local coordinates from MouseArea
                    // Get window position in screen-local coords
                    const monitorX = root.screenX
                    const monitorY = root.screenY

                    // Screen-local coords for display
                    const windowX = modelData.lastIpcObject.at[0] - monitorX
                    const windowY = modelData.lastIpcObject.at[1] - monitorY

                    const width = modelData.lastIpcObject.size[0]
                    const height = modelData.lastIpcObject.size[1]

                    if (mouseX >= windowX && mouseX <= windowX + width && mouseY >= windowY && mouseY <= windowY + height) {
                        selectionX = windowX
                        selectionY = windowY
                        selectionWidth = width
                        selectionHeight = height
                        hasSelection = true
                        windowTitle = modelData.lastIpcObject.title || ""
                        windowClass = modelData.lastIpcObject.class || ""
                        
                        // Store in GLOBAL coords for selection tracking
                        hoveredWindow = {
                            address: modelData.lastIpcObject.address,
                            x: modelData.lastIpcObject.at[0],
                            y: modelData.lastIpcObject.at[1],
                            width: width,
                            height: height,
                            title: windowTitle,
                            class: windowClass
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        z: 5
        hoverEnabled: true

        onPositionChanged: (mouse) => {
            // Reset hover before checking - will be set if hovering over a window
            root.hasSelection = false
            root.windowTitle = ""
            root.windowClass = ""
            root.hoveredWindow = null
            root.checkHover(mouse.x, mouse.y)
        }

        onExited: {
            // Clear hover when mouse leaves this screen
            root.hasSelection = false
            root.windowTitle = ""
            root.windowClass = ""
            root.hoveredWindow = null
        }

        onClicked: (mouse) => {
            const ctrlHeld = (mouse.modifiers & Qt.ControlModifier)
            const shiftHeld = (mouse.modifiers & Qt.ShiftModifier)

            // Find topmost window at click position (last in list = on top)
            var bestWindow = null
            for (var i = root.windows.length - 1; i >= 0; i--) {
                var w = root.windows[i]
                if (!w || !w.lastIpcObject || !w.lastIpcObject.at || !w.lastIpcObject.size) continue
                var windowX = w.lastIpcObject.at[0] - root.screenX
                var windowY = w.lastIpcObject.at[1] - root.screenY
                var width = w.lastIpcObject.size[0]
                var height = w.lastIpcObject.size[1]
                if (mouse.x >= windowX && mouse.x <= windowX + width && mouse.y >= windowY && mouse.y <= windowY + height) {
                    bestWindow = w
                    break
                }
            }

            if (!bestWindow) return

            const windowInfo = {
                address: bestWindow.lastIpcObject.address,
                x: bestWindow.lastIpcObject.at[0],
                y: bestWindow.lastIpcObject.at[1],
                width: bestWindow.lastIpcObject.size[0],
                height: bestWindow.lastIpcObject.size[1],
                title: bestWindow.lastIpcObject.title || "",
                class: bestWindow.lastIpcObject.class || ""
            }

            if (ctrlHeld) {
                root.windowToggled(windowInfo)
            } else {
                if (globalSelectedWindows.length > 0) {
                    if (isWindowSelectedGlobal(windowInfo)) {
                        root.captureRequested(shiftHeld)
                    } else {
                        root.regionSelected(windowInfo.x, windowInfo.y, windowInfo.width, windowInfo.height, shiftHeld)
                    }
                } else {
                    root.regionSelected(windowInfo.x, windowInfo.y, windowInfo.width, windowInfo.height, shiftHeld)
                }
            }
        }
    }
}
