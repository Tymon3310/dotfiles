import QtQuick

import "../../theme"
import "../../services"
import "../../components"

// Recording state in the island: "on air" badge + status + elapsed + pause/stop.
// The status label and timer live in fixed-width slots so the buttons never
// shift when Recording <-> Paused toggles or the digits roll over.
Row {
    id: root
    spacing: 10
    height: Theme.capsuleHeight

    readonly property TextMetrics statusMetrics: TextMetrics {
        text: "Recording"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
    }
    readonly property TextMetrics pausedMetrics: TextMetrics {
        text: "Paused"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
    }

    // The "on air" mark: a red badge with rings spreading from it while
    // recording; yellow and still while paused.
    Item {
        width: 18
        height: parent.height

        readonly property bool live: ScreenRecorderService.recording && !ScreenRecorderService.paused
        readonly property color tint: ScreenRecorderService.paused ? Theme.yellow : Theme.red

        Repeater {
            model: 2

            Rectangle {
                id: ring

                required property int index

                anchors.centerIn: parent
                width: 12
                height: 12
                radius: 6
                color: "transparent"
                border.width: 1.5
                border.color: parent.tint
                opacity: 0

                SequentialAnimation {
                    running: ring.parent.live
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) ring.opacity = 0

                    PauseAnimation { duration: ring.index * 800 }
                    ParallelAnimation {
                        NumberAnimation { target: ring; property: "scale"; from: 1; to: 2.2; duration: 1600; easing.type: Easing.OutCubic }
                        NumberAnimation { target: ring; property: "opacity"; from: 0.6; to: 0; duration: 1600; easing.type: Easing.OutCubic }
                    }
                    PauseAnimation { duration: (1 - ring.index) * 800 }
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 10
            height: 10
            radius: 5
            color: parent.tint

            Behavior on color { ColorAnimation { duration: Theme.durationMedium } }
        }
    }

    Item {
        width: Math.ceil(Math.max(root.statusMetrics.advanceWidth, root.pausedMetrics.advanceWidth))
        height: parent.height

        Text {
            anchors.centerIn: parent
            visible: !ScreenRecorderService.paused
            text: "Recording"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.text

            SequentialAnimation on opacity {
                running: ScreenRecorderService.recording && !ScreenRecorderService.paused
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.35; to: 1; duration: 900; easing.type: Easing.InOutQuad }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: ScreenRecorderService.paused
            text: "Paused"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.yellow
        }
    }

    Text {
        id: timerText
        anchors.verticalCenter: parent.verticalCenter
        text: ScreenRecorderService.elapsedText
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeSmall + 1
        font.weight: Font.DemiBold
        color: Theme.text
    }

    // Audio sources captured by this recording (display only: gsr fixes
    // sources at launch, so they toggle in the record toolbar instead).
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: ScreenRecorderService.audioSystem ? "\uf028" : "\uf026"
        font.family: Theme.fontMono
        font.pixelSize: 12
        color: ScreenRecorderService.audioSystem ? Theme.text : Theme.textMuted
        opacity: ScreenRecorderService.audioSystem ? 1 : 0.55
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: ScreenRecorderService.audioMic ? "\uf130" : "\uf131"
        font.family: Theme.fontMono
        font.pixelSize: 12
        color: ScreenRecorderService.audioMic ? Theme.text : Theme.textMuted
        opacity: ScreenRecorderService.audioMic ? 1 : 0.55
    }

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: ScreenRecorderService.paused ? "\uf04b" : "\uf04c"
        onClicked: ScreenRecorderService.togglePause()
    }

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: "\uf04d"
        iconColor: Theme.red
        onClicked: ScreenRecorderService.stop()
    }
}
