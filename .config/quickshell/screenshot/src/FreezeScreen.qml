import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property var targetScreen: Quickshell.screens[0]
    property alias contentItem: root.contentItem
    property bool frozen: false

    Timer {
        interval: 20
        running: true
        repeat: false
        onTriggered: {
            console.log("FreezeScreen: Freezing capture")
            root.frozen = true
        }
    }

    screen: targetScreen

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    WlrLayershell.exclusiveZone: -1
    WlrLayershell.namespace: "screenshot"

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    // exclusionMode: ExclusionMode.Exclude // Causes undefined warning, handled by visibility race for now

    Item {
        id: contentContainer
        anchors.fill: parent
        opacity: 0

        OpacityAnimator {
            target: contentContainer
            from: 0
            to: 1
            duration: 150
            running: true
        }

        ScreencopyView {
            captureSource: root.targetScreen
            enabled: !root.frozen
            anchors.fill: parent
            z: -1
        }
    }

    Rectangle {
        id: flash
        anchors.fill: parent
        color: "white"
        opacity: 0
        z: 999
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    function triggerFlash() {
        flash.opacity = 0.8
        flashTimer.restart()
    }

    Timer {
        id: flashTimer
        interval: 50
        onTriggered: flash.opacity = 0
    }
}
