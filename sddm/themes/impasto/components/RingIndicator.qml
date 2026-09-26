// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   R I N G   I N D I C A T O R                                            │
// │   circular progress arc · used for scanning animation                    │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "."

Item {
    id: root

    property real progress: 0.28
    property real thickness: 2
    property color trackColor: "transparent"
    property color fillColor: Theme.accent

    readonly property real clamped: Math.max(0, Math.min(1, root.progress))
    readonly property real radius: (Math.min(root.width, root.height) - root.thickness) / 2

    implicitWidth: 32
    implicitHeight: 32

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.thickness
            strokeColor: root.trackColor
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeWidth: root.thickness
            strokeColor: root.fillColor
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: 360 * root.clamped
            }
        }
    }
}
