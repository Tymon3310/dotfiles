import QtQuick
import Quickshell.Widgets

import "../parts/theme"
import "../parts/services"
import "../parts/components"

// Resting desktop content; its geometry is also used by the lock screen.
Row {
    id: root
    spacing: IslandMetrics.spacing
    height: Theme.capsuleHeight

    // 1. Media Album Art Thumbnail
    Item {
        id: mediaThumb
        width: IslandMetrics.artSize
        height: IslandMetrics.artSize
        anchors.verticalCenter: parent.verticalCenter

        ClippingRectangle {
            anchors.fill: parent
            radius: 5
            color: Theme.islandSurfaceHover

            Image {
                anchors.fill: parent
                source: MediaService.artUrl
                opacity: source !== "" && status === Image.Ready ? 1 : 0
                visible: opacity > 0
                // New covers fade in rather than pop.
                Behavior on opacity { NumberAnimation { duration: Theme.durationEnter; easing.type: Easing.OutCubic } }
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 40
                sourceSize.height: 40
            }

            Text {
                anchors.centerIn: parent
                visible: !MediaService.available || MediaService.artUrl === ""
                text: "󰝚"
                font.family: Theme.fontMono
                font.pixelSize: 11
                color: Theme.accent
            }
        }
    }

    // 2. Song Name (Title and Artist)
    Item {
        id: songItem
        anchors.verticalCenter: parent.verticalCenter
        visible: MediaService.available && (MediaService.title !== "")
        width: IslandMetrics.songWidth
        height: Theme.capsuleHeight
        clip: true

        Text {
            id: songText
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            text: IslandMetrics.song
            font: IslandMetrics.songMetrics.font
            color: Theme.text
            elide: Text.ElideRight
        }
    }

    // Spectrum fades out after playback stops.
    Item {
        id: visualizerContainer
        anchors.verticalCenter: parent.verticalCenter
        readonly property bool shouldShow: MediaService.visualizerActive

        width: IslandMetrics.spectrumWidth
        height: 14
        opacity: shouldShow ? 1 : 0
        visible: opacity > 0 || width > 0
        clip: true

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durationMorph
                easing.type: Theme.easing
            }
        }

        Spectrum {
            id: islandVisualizer
            anchors.centerIn: parent
            barWidth: IslandMetrics.spectrumBarWidth
            barSpacing: IslandMetrics.spectrumBarSpacing
            minimum: 2
            height: 14
            active: MediaService.playing
            barColor: Theme.accent
            visible: parent.visible
        }
    }

    // 4. Clock Time
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.ceil(IslandMetrics.clockMetrics.advanceWidth)
        height: Theme.capsuleHeight

        Text {
            anchors.centerIn: parent
            text: IslandMetrics.time
            font: IslandMetrics.clockMetrics.font
            color: Theme.text
        }
    }

    // Divider
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.ceil(IslandMetrics.dividerMetrics.advanceWidth)
        text: "|"
        font: IslandMetrics.dividerMetrics.font
        color: Theme.textMuted
        opacity: 0.25
    }

    // Date
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.ceil(IslandMetrics.dateMetrics.advanceWidth)
        height: Theme.capsuleHeight

        Text {
            id: dateText
            anchors.centerIn: parent
            text: IslandMetrics.date
            font: IslandMetrics.dateMetrics.font
            color: Theme.textMuted
        }
    }

    // 5. Agent Status Indicator (resting)
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: IslandMetrics.agentWidth
        height: Theme.capsuleHeight
        visible: AgentService.active

        Row {
            anchors.centerIn: parent
            spacing: 1

            Text {
                id: agentIcon
                anchors.verticalCenter: parent.verticalCenter
                text: AgentService.state === "error" ? "󰅚"
                    : AgentService.state === "waiting" ? "󰂚"
                    : AgentService.state === "done" ? "󰄬" : "󱚥"
                font.family: Theme.fontMono
                font.pixelSize: 12
                color: AgentService.state === "error" ? Theme.indicatorBad
                    : AgentService.state === "waiting" ? Theme.indicatorWarn
                    : AgentService.state === "done" ? Theme.indicatorGood : Theme.accent

                // Pulses while a session waits for you or has errored, until
                // you get to it.
                SequentialAnimation {
                    running: AgentService.needsAttention
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) { agentIcon.scale = 1; agentIcon.opacity = 1 }

                    ParallelAnimation {
                        NumberAnimation { target: agentIcon; property: "scale"; to: 1.3; duration: 380; easing.type: Easing.OutQuad }
                        NumberAnimation { target: agentIcon; property: "opacity"; to: 1; duration: 380 }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: agentIcon; property: "scale"; to: 1; duration: 620; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: agentIcon; property: "opacity"; to: 0.55; duration: 620 }
                    }
                    PauseAnimation { duration: 500 }
                }
            }

            // How many agents are active, when more than one.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: AgentService.count > 1
                text: AgentService.count
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall - 2
                font.weight: Font.DemiBold
                color: Theme.textMuted
            }
        }
    }

    // 6. Privacy Radar (resting)
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        visible: PrivacyService.active

        Rectangle {
            visible: PrivacyService.cameraActive
            width: 7
            height: 7
            radius: 3.5
            color: Theme.green
        }

        Rectangle {
            visible: PrivacyService.micActive
            width: 7
            height: 7
            radius: 3.5
            color: Theme.yellow
        }
    }
}
