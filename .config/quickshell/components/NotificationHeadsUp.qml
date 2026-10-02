import QtQuick
import Quickshell
import Quickshell.Wayland

import "../parts/theme"
import "../parts/services"
import "../parts/bar/island"

// Heads-up notification overlay shown over fullscreen applications on WlrLayer.Overlay.
// When an application is fullscreen, the top bar is covered, so this floating pill
// drops down from the ceiling to present the notification stack.
PanelWindow {
    id: root

    property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.namespace: "quickshell-heads-up-notification"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property string screenName: root.screen ? root.screen.name : ""
    readonly property bool isFullscreen: HyprlandService.isFullscreenOn(root.screenName)
    readonly property bool headsUpActive: (SettingsService.notificationHeadsUpMode === "always")
        || (SettingsService.notificationHeadsUpMode === "fullscreen" && root.isFullscreen)

    readonly property bool shouldShow: NotificationService.active
        && root.headsUpActive
        && !LockService.locked

    property bool windowVisible: false
    property real cardY: -220
    property real cardOpacity: 0.0

    visible: windowVisible

    onShouldShowChanged: {
        if (shouldShow) {
            root.windowVisible = true
            exitAnim.stop()
            entryAnim.restart()
        } else {
            entryAnim.stop()
            exitAnim.restart()
        }
    }

    ParallelAnimation {
        id: entryAnim
        NumberAnimation {
            target: root
            property: "cardY"
            from: -cardBox.height - 24
            to: 18
            duration: 380
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }
        NumberAnimation {
            target: root
            property: "cardOpacity"
            from: 0.0
            to: 1.0
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: exitAnim
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "cardY"
                to: -cardBox.height - 24
                duration: 240
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root
                property: "cardOpacity"
                to: 0.0
                duration: 180
                easing.type: Easing.InCubic
            }
        }
        ScriptAction {
            script: {
                root.windowVisible = false
                NotificationService.held = false
            }
        }
    }

    Component.onDestruction: NotificationService.held = false

    // Only the card area intercepts mouse clicks; the rest of the screen passes straight through
    mask: Region {
        item: (root.windowVisible && root.cardOpacity > 0.05) ? cardBox : null
    }

    Rectangle {
        id: cardBox
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.cardY
        opacity: root.cardOpacity

        width: Math.min(root.width - 24, notificationStack.wantWidth + 24)
        height: notificationStack.wantHeight + 24
        radius: Theme.radiusLarge + 2
        color: "#0a0a0c"
        border.width: 1
        border.color: NotificationService.critical ? Theme.red : Theme.hairline

        Behavior on height {
            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
        }

        // Render every timed entry, just as the island does. A single-card
        // preview lets older entries expire without ever being displayed.
        NotificationLayer {
            id: notificationStack
            anchors.fill: parent
            anchors.margins: 12
        }
    }
}
