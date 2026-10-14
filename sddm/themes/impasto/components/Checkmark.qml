// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C H E C K M A R K                                                      │
// │   vector tick · draws itself on as progress goes 0 → 1                   │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import "."

Item {
    id: root

    property real progress: 1
    property color color: Theme.text
    property real thickness: 2.4

    implicitWidth: 18
    implicitHeight: 18

    // Unit-space path: short leg a → b, then long leg b → c
    readonly property point a: Qt.point(0.18, 0.54)
    readonly property point b: Qt.point(0.41, 0.76)
    readonly property point c: Qt.point(0.84, 0.28)

    readonly property real leg1: Math.hypot((b.x - a.x) * width, (b.y - a.y) * height)
    readonly property real leg2: Math.hypot((c.x - b.x) * width, (c.y - b.y) * height)
    readonly property real split: leg1 / Math.max(leg1 + leg2, 0.001)
    readonly property real t1: Math.max(0, Math.min(1, progress / split))
    readonly property real t2: Math.max(0, Math.min(1, (progress - split) / (1 - split)))

    // End of the first leg, then of the second (which stays put until the
    // first leg is complete, so no stray segment is drawn back to b)
    readonly property point p1: Qt.point(a.x + (b.x - a.x) * t1, a.y + (b.y - a.y) * t1)
    readonly property point p2: t2 > 0
        ? Qt.point(b.x + (c.x - b.x) * t2, b.y + (c.y - b.y) * t2)
        : p1

    Shape {
        anchors.fill: parent
        visible: root.progress > 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.thickness
            strokeColor: root.color
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            startX: root.a.x * root.width
            startY: root.a.y * root.height
            PathLine { x: root.p1.x * root.width; y: root.p1.y * root.height }
            PathLine { x: root.p2.x * root.width; y: root.p2.y * root.height }
        }
    }
}
