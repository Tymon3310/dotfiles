import QtQuick

Item {
    id: root

    signal regionSelected(real x, real y, real width, real height)

    // Shader customization properties
    property real dimOpacity: 0.6
    property real borderRadius: 10.0
    property real outlineThickness: 2.0
    property url fragmentShader: Qt.resolvedUrl("../shaders/dimming.frag.qsb")

    property point startPos
    property real selectionX: 0
    property real selectionY: 0
    property real selectionWidth: 0
    property real selectionHeight: 0

    // Mouse Tracking for Crosshair
    property real mouseX: 0
    property real mouseY: 0

    // Redraw guides when anything moves
    onSelectionXChanged: guides.requestPaint()
    onSelectionYChanged: guides.requestPaint()
    onSelectionWidthChanged: guides.requestPaint()
    onSelectionHeightChanged: guides.requestPaint()
    onMouseXChanged: guides.requestPaint()
    onMouseYChanged: guides.requestPaint()

    // Shader overlay
    ShaderEffect {
        anchors.fill: parent
        z: 0

        property vector4d selectionRect: Qt.vector4d(
            root.selectionX,
            root.selectionY,
            root.selectionWidth,
            root.selectionHeight
        )
        property real dimOpacity: root.dimOpacity
        property vector2d screenSize: Qt.vector2d(root.width, root.height)
        property real borderRadius: root.borderRadius
        property real outlineThickness: root.outlineThickness

        fragmentShader: root.fragmentShader
    }

    // Alignment Guides (Canvas)
    Canvas {
        id: guides
        anchors.fill: parent
        z: 2

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            ctx.beginPath();
            ctx.strokeStyle = "rgba(255, 255, 255, 0.5)";
            ctx.lineWidth = 1;
            ctx.setLineDash([5, 5]);

            if (!mouseArea.pressed) {
                // Crosshair at mouse cursor (Before clicking)
                ctx.moveTo(root.mouseX, 0);
                ctx.lineTo(root.mouseX, root.height);
                ctx.moveTo(0, root.mouseY);
                ctx.lineTo(root.width, root.mouseY);
            } else {
                // Guides around the selection box (While dragging)
                ctx.moveTo(root.selectionX, 0);
                ctx.lineTo(root.selectionX, root.height);
                ctx.moveTo(root.selectionX + root.selectionWidth, 0);
                ctx.lineTo(root.selectionX + root.selectionWidth, root.height);
                ctx.moveTo(0, root.selectionY);
                ctx.lineTo(root.width, root.selectionY);
                ctx.moveTo(0, root.selectionY + root.selectionHeight);
                ctx.lineTo(root.width, root.selectionY + root.selectionHeight);
            }
            ctx.stroke();
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        z: 3
        hoverEnabled: true
        cursorShape: Qt.CrossCursor

        onPressed: (mouse) => {
            root.startPos = Qt.point(mouse.x, mouse.y)
            root.selectionX = mouse.x
            root.selectionY = mouse.y
            root.selectionWidth = 0
            root.selectionHeight = 0
        }

        onPositionChanged: (mouse) => {
            root.mouseX = mouse.x
            root.mouseY = mouse.y

            if (pressed) {
                root.selectionX = Math.min(root.startPos.x, mouse.x)
                root.selectionY = Math.min(root.startPos.y, mouse.y)
                root.selectionWidth = Math.abs(mouse.x - root.startPos.x)
                root.selectionHeight = Math.abs(mouse.y - root.startPos.y)
            }
        }

        onReleased: {
            root.regionSelected(
                Math.round(root.selectionX),
                Math.round(root.selectionY),
                Math.round(root.selectionWidth),
                Math.round(root.selectionHeight)
            )
        }
    }
}
