
import QtQuick

import "../theme"

// Scales `item` up from Theme.enterScale and fades it in, `order` steps of
// Theme.durationStagger after creation. An animation, not an Item, so it can
// sit inside a layout without taking a cell:
//
//   CalendarCard { id: calendar }
//   Entrance { item: calendar; order: 0 }
//
// `fade: false` leaves opacity alone, for items whose opacity is bound.
SequentialAnimation {
    id: root

    property Item item: null
    property int order: 0
    property bool fade: true

    Component.onCompleted: {
        if (!root.item || Theme.motion <= 0)
            return
        if (root.fade)
            root.item.opacity = 0
        root.item.scale = Theme.enterScale
        root.start()
    }

    PauseAnimation { duration: root.order * Theme.durationStagger }

    ParallelAnimation {
        NumberAnimation {
            target: root.item
            property: "scale"
            to: 1
            duration: Theme.durationEnter
            easing.type: Theme.easingSpring
            easing.overshoot: Theme.springOvershoot
        }

        NumberAnimation {
            // No target, no effect: keeps a bound opacity intact.
            target: root.fade ? root.item : null
            property: "opacity"
            to: 1
            duration: Math.round(Theme.durationEnter * 0.7)
            easing.type: Easing.OutCubic
        }
    }
}
