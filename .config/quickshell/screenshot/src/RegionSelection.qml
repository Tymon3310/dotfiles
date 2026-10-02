import QtQuick
import Quickshell

// Cross-screen region selection and QR overlays share the coordinator's state.
Item {
    id: crossScreenSelector

    required property var controller
    required property real screenX
    required property real screenY
    visible: crossScreenSelector.controller.mode === "region" || crossScreenSelector.controller.mode === "ocr" || crossScreenSelector.controller.mode === "lens" || crossScreenSelector.controller.mode === "ai"
    anchors.fill: parent

    // Calculate local selection rect for this screen
    property real localSelX: crossScreenSelector.controller.selectionX - crossScreenSelector.screenX
    property real localSelY: crossScreenSelector.controller.selectionY - crossScreenSelector.screenY
    property real localSelWidth: crossScreenSelector.controller.selectionWidth
    property real localSelHeight: crossScreenSelector.controller.selectionHeight

    // Clamp to screen bounds
    property real clampedX: Math.max(0, localSelX)
    property real clampedY: Math.max(0, localSelY)
    property real clampedRight: Math.min(crossScreenSelector.width, localSelX + localSelWidth)
    property real clampedBottom: Math.min(crossScreenSelector.height, localSelY + localSelHeight)
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
        property real dimOpacity: Theme.captureWash.a
        property vector2d screenSize: Qt.vector2d(parent.width, parent.height)
        property real borderRadius: Theme.radiusMedium
        property real outlineThickness: (crossScreenSelector.clampedWidth > 1 && crossScreenSelector.clampedHeight > 1) ? 2.0 : 0.0
        property color outlineColor: Theme.accent

        fragmentShader: Qt.resolvedUrl("../shaders/dimming.frag.qsb")
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
            ctx.strokeStyle = "rgba(255, 255, 255, 0.35)";
            ctx.lineWidth = 1;
            ctx.setLineDash([4, 4]);

            if (!crossScreenSelector.controller.isSelecting && regionMouseArea.containsMouse) {
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

    // Dimension reading pill badge
    Rectangle {
        visible: crossScreenSelector.controller.isSelecting && crossScreenSelector.clampedWidth > 20 && crossScreenSelector.clampedHeight > 20
        x: Math.min(Math.max(10, crossScreenSelector.clampedX + (crossScreenSelector.clampedWidth - width) / 2),
                    parent.width - width - 10)
        y: crossScreenSelector.clampedY > height + 10
            ? crossScreenSelector.clampedY - height - 8
            : crossScreenSelector.clampedY + 8
        width: readingLabel.implicitWidth + 20
        height: 28
        radius: height / 2
        color: Theme.island
        border.color: Theme.islandBorder
        border.width: 1
        z: 4

        Text {
            id: readingLabel
            anchors.centerIn: parent
            text: Math.round(crossScreenSelector.controller.selectionWidth) + " × " + Math.round(crossScreenSelector.controller.selectionHeight)
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.text
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
            crossScreenSelector.controller.shiftHeld = (mouse.modifiers & Qt.ShiftModifier)
            crossScreenSelector.controller.isSelecting = true
            const globalX = crossScreenSelector.screenX + mouse.x
            const globalY = crossScreenSelector.screenY + mouse.y
            crossScreenSelector.controller.globalStartX = globalX
            crossScreenSelector.controller.globalStartY = globalY
            crossScreenSelector.controller.globalEndX = globalX
            crossScreenSelector.controller.globalEndY = globalY
        }

        onPositionChanged: (mouse) => {
            crossScreenSelector.mouseX = mouse.x
            crossScreenSelector.mouseY = mouse.y

            if (pressed) {
                crossScreenSelector.controller.globalEndX = crossScreenSelector.screenX + mouse.x
                crossScreenSelector.controller.globalEndY = crossScreenSelector.screenY + mouse.y
            }
        }

        onReleased: (mouse) => {
            const openEditor = (mouse.modifiers & Qt.ShiftModifier) || crossScreenSelector.controller.shiftHeld
            crossScreenSelector.controller.isSelecting = false
            crossScreenSelector.controller.processScreenshot(
                crossScreenSelector.controller.selectionX,
                crossScreenSelector.controller.selectionY,
                crossScreenSelector.controller.selectionWidth,
                crossScreenSelector.controller.selectionHeight,
                openEditor
            )
        }
    }

    // QR Code overlays - visible in lens mode
    Repeater {
        model: crossScreenSelector.controller.mode === "lens" ? crossScreenSelector.controller.detectedQRCodes : []

        Rectangle {
            id: qrOverlay
            required property var modelData
            required property int index

            // Convert image coordinates to local screen coordinates
            property real imgX: modelData.x + crossScreenSelector.controller.minScreenX
            property real imgY: modelData.y + crossScreenSelector.controller.minScreenY
            property real localX: imgX - crossScreenSelector.screenX
            property real localY: imgY - crossScreenSelector.screenY

            // Only show if QR code is on this screen
            visible: localX + modelData.width > 0 && localX < crossScreenSelector.width &&
                     localY + modelData.height > 0 && localY < crossScreenSelector.height

            x: localX - 8
            y: localY - 8
            width: modelData.width + 16
            height: modelData.height + 16
            radius: Theme.radiusSmall
            color: qrMouseArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
            border.color: Theme.accent
            border.width: 2
            z: 5

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            // QR icon badge
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: -6
                width: 28
                height: 28
                radius: 14
                color: Theme.accent

                Image {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    sourceSize: Qt.size(64, 64)
                    source: Qt.resolvedUrl("../icons/qr.svg")
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
                height: qrDataColumn.height + 14
                radius: Theme.radiusSmall
                color: Theme.island
                border.color: Theme.islandBorder
                border.width: 1
                z: 10

                Column {
                    id: qrDataColumn
                    anchors.centerIn: parent
                    spacing: 3

                    Text {
                        text: qrOverlay.modelData.data.length > 60
                            ? qrOverlay.modelData.data.substring(0, 60) + "..."
                            : qrOverlay.modelData.data
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Text {
                        text: "Click to copy" + (qrOverlay.modelData.data.indexOf("http") === 0 ? " & open" : "")
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        font.weight: Font.DemiBold
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
                    cmd += " && rm -f '" + crossScreenSelector.controller.tempPath + "'"
                    crossScreenSelector.controller.ready = false
                    Quickshell.execDetached(["sh", "-c", cmd])
                    crossScreenSelector.controller.tempPath = ""
                    crossScreenSelector.controller.requestFlash()
                    crossScreenSelector.controller.scheduleExit()
                }
            }
        }
    }
}
