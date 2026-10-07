import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import "../parts/theme"
import "../parts/services"
import "../parts/components"

Item {
    id: root

    signal expandRequested()
    signal closed()

    implicitWidth: 490
    implicitHeight: 56

    Component.onCompleted: {
        MediaService.subscribe()
        LyricsService.subscribe()
    }
    Component.onDestruction: {
        MediaService.release()
        LyricsService.release()
    }

    function formatSeconds(s): string {
        if (!s || isNaN(s) || s < 0) return "0:00"
        const m = Math.floor(s / 60)
        const sec = Math.floor(s % 60)
        return `${m}:${sec < 10 ? "0" : ""}${sec}`
    }

    readonly property string currentLyric: LyricsService.synced && LyricsService.index >= 0 && LyricsService.lines[LyricsService.index]
        ? (LyricsService.lines[LyricsService.index].text || "") : ""

    readonly property int displayVolume: MediaService.available
        ? Math.round(MediaService.volume * 100)
        : AudioService.volume

    property bool volumeFeedbackActive: false
    readonly property Timer volumeFeedbackTimer: Timer {
        interval: 1400
        repeat: false
        onTriggered: root.volumeFeedbackActive = false
    }

    readonly property var activeMicApps: {
        const names = PrivacyService.micListeners.map(n => PrivacyService.nameOf(n)).filter(n => n.length > 0)
        return names.filter((v, i, a) => a.indexOf(v) === i)
    }

    readonly property var activeCamApps: {
        return PrivacyService.cameraHolders.map(n => n.charAt(0).toUpperCase() + n.slice(1))
    }

    // Background click expands to full dashboard
    MouseArea {
        id: bgMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                MediaService.toggle()
            } else {
                root.expandRequested()
            }
        }
        onWheel: event => {
            MediaService.nudgeVolume(event.angleDelta.y > 0 ? 0.05 : -0.05)
            root.volumeFeedbackActive = true
            root.volumeFeedbackTimer.restart()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 8

        // ── 1. NOW PLAYING (Left) ─────────────────────────────────────────────
        RowLayout {
            Layout.preferredWidth: 205
            Layout.fillHeight: true
            spacing: 8

            // Album Art Thumbnail
            Item {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                Layout.alignment: Qt.AlignVCenter

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Theme.islandSurfaceHover
                    border.width: 1
                    border.color: Theme.hairline

                    Image {
                        anchors.fill: parent
                        source: MediaService.artUrl
                        visible: MediaService.available && source !== "" && status === Image.Ready
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 84
                        sourceSize.height: 84
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !MediaService.available || MediaService.artUrl === ""
                        text: "󰝚"
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                        color: Theme.accent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MediaService.toggle()
                }
            }

            // Track details, lyrics line & mini controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                // Row 1 (Top): Song Title + Visualizer / Volume Feedback
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 15
                        clip: true

                        RollingText {
                            anchors.fill: parent
                            text: MediaService.available && MediaService.title !== ""
                                ? MediaService.title : (AudioService.sinkDescription || "System Audio")
                            color: Theme.text
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            marquee: true
                        }
                    }

                    // Audio Visualizer or Volume Feedback when scrolling
                    Item {
                        Layout.preferredWidth: root.volumeFeedbackActive ? volumeRow.implicitWidth : (MediaService.playing ? 26 : 0)
                        Layout.preferredHeight: 14
                        visible: root.volumeFeedbackActive || MediaService.playing
                        clip: true

                        // Volume Percentage Feedback on scroll
                        Row {
                            id: volumeRow
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            spacing: 3
                            opacity: root.volumeFeedbackActive ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }

                            Text {
                                text: AudioService.icon
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                color: Theme.accent
                            }

                            Text {
                                text: `${root.displayVolume}%`
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }
                        }

                        // Cava Spectrum Bars
                        Spectrum {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            barWidth: 2
                            barSpacing: 1.5
                            minimum: 2
                            height: 11
                            active: MediaService.playing && !root.volumeFeedbackActive
                            barColor: Theme.accent
                            opacity: !root.volumeFeedbackActive && MediaService.playing ? 0.9 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                    }
                }

                // Row 2 (Medium): Synced Lyric Line or Artist Name
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 13
                    clip: true

                    RollingText {
                        anchors.fill: parent
                        text: root.currentLyric !== ""
                            ? `♪ ${root.currentLyric}`
                            : (MediaService.available && MediaService.artist !== ""
                                ? MediaService.artist : `${root.displayVolume}% Volume`)
                        color: root.currentLyric !== "" ? Theme.accent : Theme.textMuted
                        font.pixelSize: Theme.fontSizeLabel - 1
                        font.italic: root.currentLyric !== ""
                        marquee: true
                    }
                }

                // Row 3 (Bottom): Scrubber Bar with Track Elapsed & Total Times + Controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: MediaService.available

                    Text {
                        text: root.formatSeconds(MediaService.position)
                        font.family: Theme.fontMono
                        font.pixelSize: 8
                        color: Theme.textMuted
                    }

                    // Progress Bar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 2
                        radius: 1
                        color: Theme.hairline

                        Rectangle {
                            height: parent.height
                            width: Math.max(0, Math.min(parent.width, parent.width * MediaService.progress))
                            radius: 1
                            color: Theme.accent
                        }
                    }

                    Text {
                        text: root.formatSeconds(MediaService.length)
                        font.family: Theme.fontMono
                        font.pixelSize: 8
                        color: Theme.textMuted
                    }

                    // Mini Controls
                    Row {
                        spacing: 6

                        Text {
                            text: "󰒮"
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            color: prevMouse.containsMouse ? Theme.text : Theme.textMuted
                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: MediaService.previous()
                            }
                        }

                        Text {
                            text: MediaService.playing ? "󰏤" : "󰐊"
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            color: playMouse.containsMouse ? Theme.accent : Theme.text
                            MouseArea {
                                id: playMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: MediaService.toggle()
                            }
                        }

                        Text {
                            text: "󰒭"
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            color: nextMouse.containsMouse ? Theme.text : Theme.textMuted
                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: MediaService.next()
                            }
                        }
                    }
                }
            }
        }

        // ── 2. CENTER & RIGHT: UNIFIED 3-ROW GRID ─────────────────────────────
        // Top: Privacy, JBL, Agent
        // Rows 2 & 3: Calendar (Left/Center) + Time & Weather (Right)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            // ── ROW 1 (TOP): BADGES (Privacy + JBL + Agent) ───────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Item { Layout.fillWidth: true }

                // AI Agent Badge
                Rectangle {
                    visible: AgentService.active
                    Layout.alignment: Qt.AlignVCenter
                    height: 15
                    width: agentRow.implicitWidth + 8
                    radius: 7.5
                    color: AgentService.state === "waiting"
                        ? Theme.indicatorWarn
                        : AgentService.state === "done" ? Theme.indicatorGood : "transparent"
                    border.width: 1
                    border.color: AgentService.state === "working" ? Theme.accent : Theme.hairline

                    Row {
                        id: agentRow
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: AgentService.state === "waiting" ? "󰞋" : AgentService.state === "done" ? "󰄬" : "󱚥"
                            font.family: Theme.fontMono
                            font.pixelSize: 8
                            color: AgentService.state === "waiting" || AgentService.state === "done" ? "#000000" : Theme.accent
                        }
                        Text {
                            text: AgentService.label
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                            color: AgentService.state === "waiting" || AgentService.state === "done" ? "#000000" : Theme.text
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AgentService.focusWindow()
                    }
                }

                // Privacy Mic Badges (e.g. Discord, Zen)
                Repeater {
                    model: root.activeMicApps
                    Rectangle {
                        required property string modelData
                        height: 15
                        width: micAppRow.implicitWidth + 8
                        radius: 7.5
                        color: Qt.rgba(Theme.yellow.r, Theme.yellow.g, Theme.yellow.b, 0.15)
                        border.width: 1
                        border.color: Theme.yellow

                        Row {
                            id: micAppRow
                            anchors.centerIn: parent
                            spacing: 2
                            Text { text: "󰍬"; font.family: Theme.fontMono; font.pixelSize: 8; color: Theme.yellow }
                            Text { text: modelData.split(",")[0].replace(/-bin$/i, "").trim(); font.family: Theme.fontFamily; font.pixelSize: 8; color: Theme.yellow }
                        }
                    }
                }

                // Privacy Cam Badges (e.g. Zen)
                Repeater {
                    model: root.activeCamApps
                    Rectangle {
                        required property string modelData
                        height: 15
                        width: camAppRow.implicitWidth + 8
                        radius: 7.5
                        color: Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.15)
                        border.width: 1
                        border.color: Theme.green

                        Row {
                            id: camAppRow
                            anchors.centerIn: parent
                            spacing: 2
                            Text { text: "󰄀"; font.family: Theme.fontMono; font.pixelSize: 8; color: Theme.green }
                            Text { text: modelData.split(",")[0].replace(/-bin$/i, "").trim(); font.family: Theme.fontFamily; font.pixelSize: 8; color: Theme.green }
                        }
                    }
                }

                // JBL Headset Badge
                Rectangle {
                    visible: HeadsetService.connected
                    Layout.alignment: Qt.AlignVCenter
                    height: 15
                    width: headsetRow.implicitWidth + 8
                    radius: 7.5
                    color: HeadsetService.micMuted
                        ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.14)
                        : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
                    border.width: 1
                    border.color: HeadsetService.micMuted ? Theme.red : Theme.hairline

                    Row {
                        id: headsetRow
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            text: HeadsetService.charging ? "󰂄" : "󰋋"
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            color: HeadsetService.battery <= 20 ? Theme.red
                                : HeadsetService.battery <= 40 ? Theme.yellow : Theme.text
                        }

                        Text {
                            text: `${HeadsetService.battery}%`
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            text: HeadsetService.micMuted ? "󰍭" : "󰍬"
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            color: HeadsetService.micMuted ? Theme.red : Theme.green
                        }
                    }
                }
            }

            // ── ROWS 2 & 3: CALENDAR (Perfect Column Alignment) + TIME & WEATHER ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Item { Layout.fillWidth: true }

                // The 7-Day Calendar Strip (Letters & Numbers in same Column = Zero Misalignment!)
                Row {
                    id: calendarStrip
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: 7
                        Column {
                            id: dayCol
                            required property int index
                            readonly property int distance: Math.abs(index - 3)
                            readonly property var day: {
                                const d = new Date()
                                d.setDate(d.getDate() + index - 3)
                                return d
                            }
                            width: 17
                            spacing: 2
                            opacity: [1.0, 0.72, 0.45, 0.25][dayCol.distance]

                            // Weekday letter (Medium row)
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatDateTime(dayCol.day, "ddd").slice(0, 1)
                                font.family: Theme.fontMono
                                font.pixelSize: 8
                                color: dayCol.distance === 0 ? Theme.accent : Theme.textMuted
                            }

                            // Day number (Bottom row)
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 16
                                height: 16
                                radius: 8
                                color: dayCol.distance === 0 ? Theme.accent : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: dayCol.day.getDate()
                                    font.family: Theme.fontMono
                                    font.pixelSize: 9
                                    font.weight: dayCol.distance === 0 ? Font.Bold : Font.Normal
                                    color: dayCol.distance === 0 ? "#ffffff" : Theme.text
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Time (Medium row) & Weather (Bottom row)
                ColumnLayout {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    spacing: 1

                    // Clock Time (Medium row)
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: IslandMetrics.time
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeMedium + 2
                        font.weight: Font.Bold
                        color: Theme.text
                    }

                    // Weather with Glyph (Bottom row)
                    Row {
                        Layout.alignment: Qt.AlignRight
                        spacing: 3

                        Text {
                            visible: WeatherService.available && WeatherService.glyph !== ""
                            text: WeatherService.glyph
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            color: Theme.accent
                        }

                        Text {
                            text: WeatherService.available && WeatherService.description !== ""
                                ? `${WeatherService.temperature}° · ${WeatherService.description}`
                                : IslandMetrics.date
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            color: Theme.textMuted
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
