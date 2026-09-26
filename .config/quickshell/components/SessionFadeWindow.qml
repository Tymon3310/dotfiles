import QtQuick
import Quickshell
import Quickshell.Wayland

import "../parts/theme"
import "../parts/services"

// Fullscreen overlay on all monitors that creates an expanding wave
// radiating outwards from the dynamic island to dissolve the screen into black.
PanelWindow {
    id: root

    property var modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.namespace: "session-fade"
    WlrLayershell.keyboardFocus: (SessionService.fadingOut || baseFade.opacity > 0)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    color: "transparent"
    visible: SessionService.fadingOut || baseFade.opacity > 0

    readonly property real centerX: root.width / 2
    readonly property real centerY: 20
    readonly property real targetRadius: Math.ceil(Math.hypot(root.width / 2, root.height)) + 100

    // Capture and discard all mouse inputs & hide cursor once wave begins
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.BlankCursor
        acceptedButtons: Qt.AllButtons
        onPressed: (mouse) => mouse.accepted = true
    }

    // ── 1. BASE FADE (Catches display corners at the end of the wave) ───────
    Rectangle {
        id: baseFade
        anchors.fill: parent
        color: "#000000"
        opacity: 0.0
    }

    // ── 2. MAIN SOLID BLACK EXPANDING WAVE ─────────────────────────────────
    Rectangle {
        id: mainWave
        width: 0
        height: width
        radius: width / 2
        x: root.centerX - width / 2
        y: root.centerY - height / 2
        color: "#000000"
    }

    // ── ANIMATION TIMELINE ─────────────────────────────────────────────────
    ParallelAnimation {
        id: waveAnimation

        // Main Wave: Smooth solid black expansion from island to whole screen
        SequentialAnimation {
            NumberAnimation {
                target: mainWave
                property: "width"
                from: 60
                to: root.targetRadius * 2.2
                duration: SessionService.fadeDuration
                easing.type: Easing.OutQuad
            }
        }

        // Base fade: joins in late to ensure all 4 screen corners smoothly dissolve to 100% black
        SequentialAnimation {
            PauseAnimation { duration: Math.floor(SessionService.fadeDuration * 0.45) }
            NumberAnimation {
                target: baseFade
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: SessionService.fadeDuration - Math.floor(SessionService.fadeDuration * 0.45)
                easing.type: Easing.InQuad
            }
        }
    }

    Connections {
        target: SessionService
        function onFadingOutChanged(): void {
            if (SessionService.fadingOut) {
                mainWave.width = 60
                baseFade.opacity = 0.0
                waveAnimation.restart()
            } else {
                waveAnimation.stop()
                baseFade.opacity = 0.0
                mainWave.width = 0
            }
        }
    }
}
