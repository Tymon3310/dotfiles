// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S P E C T R U M                                                        │
// │   audio spectrum bars                                                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"
import "../services"

// Audio spectrum bars driven by CavaService.
// Bars grow from the centre line like a waveform, with a subtle floor at silence.
Item {
    id: root

    // False flattens the bars to their minimum floor.
    property bool active: true

    property color barColor: Theme.accent
    property real barWidth: 3
    property real minimum: 2
    property real curve: 0.55
    property real barSpacing: 2

    readonly property int barCount: CavaService.values.length

    implicitWidth: root.barCount > 0
        ? root.barCount * root.barWidth + (root.barCount - 1) * root.barSpacing
        : 0
    implicitHeight: 16
    width: implicitWidth
    height: implicitHeight

    property bool subscribed: false

    function updateSubscription(): void {
        const shouldSub = root.active && root.visible
        if (shouldSub && !root.subscribed) {
            CavaService.subscribe()
            root.subscribed = true
        } else if (!shouldSub && root.subscribed) {
            CavaService.release()
            root.subscribed = false
        }
    }

    Component.onCompleted: updateSubscription()
    Component.onDestruction: {
        if (root.subscribed) {
            CavaService.release()
            root.subscribed = false
        }
    }
    onActiveChanged: updateSubscription()
    onVisibleChanged: updateSubscription()

    Row {
        anchors.centerIn: parent
        spacing: root.barSpacing

        Repeater {
            model: CavaService.values

            Rectangle {
                required property real modelData

                width: root.barWidth
                height: root.active
                    ? Math.max(root.minimum,
                        root.height * Math.pow(Math.max(0, modelData), root.curve))
                    : root.minimum
                anchors.verticalCenter: parent.verticalCenter
                radius: width / 2
                color: root.barColor

                Behavior on height {
                    NumberAnimation { duration: 70; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
