import QtQuick
import Quickshell.Widgets

import "../parts/theme"
import "../parts/services"
import "../parts/components"

Row {
    id: root
    spacing: IslandMetrics.spacing
    height: Theme.capsuleHeight

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

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.ceil(IslandMetrics.dividerMetrics.advanceWidth)
        text: "|"
        font: IslandMetrics.dividerMetrics.font
        color: Theme.textMuted
        opacity: 0.25
    }

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

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: IslandMetrics.agentWidth
        height: Theme.capsuleHeight
        visible: AgentService.active

        // A click goes to that session (its window, and its tab in
        // OpenCode) instead of opening the dashboard.
        MouseArea {
            anchors.fill: parent
            anchors.margins: -3
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: AgentService.focusWindow()
        }

        Row {
            anchors.centerIn: parent
            spacing: AgentService.needsAttention ? 4 : 1

            Item {
                id: agentBadge
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18

                readonly property bool alarm: AgentService.needsAttention
                readonly property color tint: AgentService.attentionState === "error"
                    ? Theme.indicatorBad : Theme.indicatorWarn

                // While a session waits for you or has errored: a solid
                // badge in that colour, with a ring rippling out of it, until
                // you get to it.
                Rectangle {
                    id: agentRing
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: 9
                    color: "transparent"
                    border.width: 1.5
                    border.color: agentBadge.tint
                    opacity: 0
                    visible: agentBadge.alarm
                }

                Rectangle {
                    id: agentDisc
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: 9
                    color: agentBadge.tint
                    visible: agentBadge.alarm
                }

                Text {
                    id: agentIcon
                    anchors.centerIn: parent
                    text: AgentService.state === "error" ? "󰅚"
                        : AgentService.state === "waiting" ? "󰂚"
                        : AgentService.state === "done" ? "󰄬" : "󱚥"
                    font.family: Theme.fontMono
                    font.pixelSize: agentBadge.alarm ? 11 : 12
                    color: agentBadge.alarm ? Theme.island
                        : AgentService.state === "done" ? Theme.indicatorGood : Theme.accent
                }

                SequentialAnimation {
                    running: agentBadge.alarm
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) { agentBadge.scale = 1; agentRing.opacity = 0 }

                    ParallelAnimation {
                        NumberAnimation { target: agentBadge; property: "scale"; to: 1.15; duration: 260; easing.type: Easing.OutQuad }
                        NumberAnimation { target: agentRing; property: "scale"; from: 1; to: 1.9; duration: 1100; easing.type: Easing.OutCubic }
                        NumberAnimation { target: agentRing; property: "opacity"; from: 0.8; to: 0; duration: 1100; easing.type: Easing.OutCubic }
                        SequentialAnimation {
                            PauseAnimation { duration: 260 }
                            NumberAnimation { target: agentBadge; property: "scale"; to: 1; duration: 500; easing.type: Easing.InOutQuad }
                        }
                    }
                    PauseAnimation { duration: 600 }
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
