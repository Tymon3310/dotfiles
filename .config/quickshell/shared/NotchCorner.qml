// Concave bezel corner, derived from impasto (GPL-3.0; see parts/LICENSE).
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property color color: "#000000"
    property bool mirrored: false
    property bool atBottom: false

    implicitWidth: 16
    implicitHeight: 16

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        transform: Scale {
            xScale: root.mirrored ? -1 : 1
            yScale: root.atBottom ? -1 : 1
            origin.x: root.width / 2
            origin.y: root.height / 2
        }

        ShapePath {
            strokeWidth: 0
            fillColor: root.color
            startX: 0
            startY: 0

            PathLine { x: root.width; y: 0 }
            PathAngleArc {
                centerX: root.width
                centerY: root.height
                radiusX: root.width
                radiusY: root.height
                startAngle: -90
                sweepAngle: -90
            }
            PathLine { x: 0; y: 0 }
        }
    }
}
