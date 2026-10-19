// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M E D I A   C A R D                                                    │
// │   the player: track, lyrics or what comes next, and the controls         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import "../../../theme"
import "../../../services"
import "../../../components"

// impasto's player card, grown for a column of its own. Between the track and
// the controls sits one of:
//
//   synced lyrics   the line being sung held in the middle, larger and in
//                   full white, its neighbours fading with distance; with
//                   word timing the words light up as they are sung
//   plain lyrics    the text, scrolled along with the track's progress
//   up next         the queue (MediaService.queue), when there are no lyrics,
//                   while they load, or for an instrumental
Card {
    id: root

    // Lyrics in the middle, unless there are none or the queue was picked.
    readonly property bool lyricsMode: LyricsService.shown && !SettingsService.mediaPreferQueue

    // The Spectrum in the title row subscribes to cava itself, only while
    // it is shown and playing.
    Component.onCompleted: LyricsService.subscribe()
    Component.onDestruction: LyricsService.release()

    WheelHandler {
        onWheel: event => MediaService.nudgeVolume(event.angleDelta.y > 0 ? 0.05 : -0.05)
    }

    Text {
        anchors.centerIn: parent
        visible: !MediaService.available
        text: "Nothing playing"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textMuted
    }

    ColumnLayout {
        anchors.fill: parent
        visible: MediaService.available
        spacing: 10

        // ── TRACK ─────────────────────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ClippingRectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: width * Theme.pictureCorner
                color: Theme.islandSurfaceHover

                Image {
                    id: art
                    anchors.fill: parent
                    source: MediaService.artUrl
                    readonly property bool ready: source !== "" && status === Image.Ready
                    opacity: art.ready ? 1 : 0
                    visible: opacity > 0
                    // New covers fade in rather than pop.
                    Behavior on opacity { NumberAnimation { duration: Theme.durationEnter; easing.type: Easing.OutCubic } }
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 112
                    sourceSize.height: 112
                }

                Text {
                    anchors.centerIn: parent
                    visible: !art.ready
                    text: "󰎇"
                    font.family: Theme.fontMono
                    font.pixelSize: 22
                    color: Theme.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: MediaService.title || "Unknown"
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Spectrum {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 14
                        visible: MediaService.playing
                        barColor: Theme.accent
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: MediaService.artist || "Unknown artist"
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                Text {
                    Layout.fillWidth: true
                    text: MediaService.album || ""
                    visible: text !== ""
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                    opacity: 0.7
                }
            }

            // What the middle shows. With lyrics available, a switch between
            // them and the queue; otherwise a tag saying why the queue is up.
            // Synced lyrics get a timing nudge underneath.
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 6

                // Lyrics | Up next
                Rectangle {
                    id: modeSwitch

                    readonly property var modes: [
                        { label: "LYRICS", queue: false },
                        { label: "UP NEXT", queue: true }
                    ]
                    readonly property real segment: Math.max(lyricsLabel.implicitWidth, queueLabel.implicitWidth) + 16

                    Layout.alignment: Qt.AlignRight
                    visible: LyricsService.shown
                    implicitWidth: modeSwitch.segment * 2 + 4
                    implicitHeight: 20
                    radius: height / 2
                    color: Theme.islandSurfaceHover

                    // The selected segment, sliding between the two.
                    Rectangle {
                        x: 2 + (SettingsService.mediaPreferQueue ? modeSwitch.segment : 0)
                        y: 2
                        width: modeSwitch.segment
                        height: parent.height - 4
                        radius: height / 2
                        color: Theme.accent

                        Behavior on x { NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing } }
                    }

                    Row {
                        x: 2
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: modeSwitch.modes

                            Item {
                                id: seg

                                required property var modelData
                                readonly property bool selected: SettingsService.mediaPreferQueue === seg.modelData.queue

                                width: modeSwitch.segment
                                height: 16

                                Text {
                                    anchors.centerIn: parent
                                    text: seg.modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.6
                                    color: seg.selected ? Theme.accentText
                                        : segMouse.containsMouse ? Theme.text : Theme.textMuted

                                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                                }

                                MouseArea {
                                    id: segMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: SettingsService.mediaPreferQueue = seg.modelData.queue
                                }
                            }
                        }
                    }

                    // Measure both labels, so the segments are equal.
                    Text { id: lyricsLabel; visible: false; text: "LYRICS"; font.pixelSize: 9; font.weight: Font.DemiBold; font.letterSpacing: 0.6; font.family: Theme.fontFamily }
                    Text { id: queueLabel; visible: false; text: "UP NEXT"; font.pixelSize: 9; font.weight: Font.DemiBold; font.letterSpacing: 0.6; font.family: Theme.fontFamily }
                }

                // No lyrics to switch to: just say what is shown.
                Rectangle {
                    Layout.alignment: Qt.AlignRight
                    visible: !LyricsService.shown
                    implicitWidth: tag.implicitWidth + 14
                    implicitHeight: 20
                    radius: height / 2
                    color: Theme.islandSurfaceHover

                    Text {
                        id: tag
                        anchors.centerIn: parent
                        text: LyricsService.loading ? "…"
                            : LyricsService.kind === "instrumental" ? "INSTRUMENTAL" : "UP NEXT"
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.6
                        color: Theme.textMuted
                    }
                }

                // Lyric timing: − later, the offset (click resets), + earlier.
                Row {
                    Layout.alignment: Qt.AlignRight
                    visible: root.lyricsMode && LyricsService.synced
                    spacing: 2

                    NudgeButton {
                        glyph: "−"
                        onClicked: SettingsService.lyricsOffset -= 100
                    }

                    Text {
                        width: 38
                        height: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: SettingsService.lyricsOffset === 0 ? "sync"
                            : `${SettingsService.lyricsOffset > 0 ? "+" : ""}${(SettingsService.lyricsOffset / 1000).toFixed(1)}s`
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: SettingsService.lyricsOffset !== 0
                            ? (offsetMouse.containsMouse ? Theme.text : Theme.accent) : Theme.textMuted

                        MouseArea {
                            id: offsetMouse
                            anchors.fill: parent
                            hoverEnabled: SettingsService.lyricsOffset !== 0
                            cursorShape: hoverEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: SettingsService.lyricsOffset = 0
                        }
                    }

                    NudgeButton {
                        glyph: "+"
                        onClicked: SettingsService.lyricsOffset += 100
                    }
                }
            }
        }

        // ── MIDDLE ────────────────────────────────────────────────────────

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Synced and plain lyrics share one list; only synced ones hold a
            // line in the middle.
            ListView {
                id: lyrics

                anchors.fill: parent
                visible: root.lyricsMode
                clip: true
                interactive: false
                spacing: 4
                model: LyricsService.shown ? LyricsService.lines : []

                currentIndex: LyricsService.synced ? Math.max(0, LyricsService.index) : -1
                highlightRangeMode: LyricsService.synced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
                preferredHighlightBegin: lyrics.height / 2 - 14
                preferredHighlightEnd: lyrics.height / 2 + 14
                highlightMoveDuration: 220
                highlightMoveVelocity: -1
                highlightResizeDuration: 180
                highlightResizeVelocity: -1
                highlightFollowsCurrentItem: true

                // A soft accent pill behind the line being sung; it glides to
                // the next line with the scroll.
                highlight: Rectangle {
                    visible: LyricsService.synced && LyricsService.index >= 0
                    radius: Theme.radiusMedium
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                    border.width: 1
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                }

                // Plain lyrics follow the track's progress instead.
                readonly property real follow: LyricsService.synced ? 0
                    : Math.max(0, lyrics.contentHeight - lyrics.height) * MediaService.progress
                onFollowChanged: if (!LyricsService.synced) lyrics.contentY = lyrics.follow

                delegate: Text {
                    id: line

                    required property var modelData
                    required property int index

                    readonly property int distance: LyricsService.synced
                        ? Math.abs(line.index - LyricsService.index) : 1
                    readonly property bool current: LyricsService.synced && line.index === LyricsService.index
                    readonly property bool sung: LyricsService.synced && line.index < LyricsService.index

                    width: lyrics.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    textFormat: line.current && (line.modelData.words ?? []).length > 0
                        ? Text.StyledText : Text.PlainText

                    text: {
                        const words = line.modelData.words ?? []
                        if (!line.current || words.length === 0)
                            return line.modelData.text === "" ? "♪" : line.modelData.text
                        // Sung words in the accent, the rest in dim white.
                        let out = ""
                        for (let i = 0; i < words.length; i++) {
                            const safe = words[i].text.replace(/&/g, "&amp;").replace(/</g, "&lt;")
                            out += i <= LyricsService.wordIndex
                                ? safe : `<font color="#99ffffff">${safe}</font>`
                        }
                        return out
                    }

                    font.family: Theme.fontFamily
                    // Padding inside the highlight pill.
                    topPadding: line.current ? 5 : 0
                    bottomPadding: line.current ? 5 : 0
                    leftPadding: 10
                    rightPadding: 10

                    font.pixelSize: line.current ? 15 : 12.5
                    font.weight: line.current ? Font.Bold : Font.Normal
                    color: line.current ? Theme.accentHover : Theme.textMuted

                    Behavior on color { ColorAnimation { duration: 200 } }
                    opacity: line.current ? 1 : Math.max(0.18, 0.75 - line.distance * 0.16)

                    Behavior on opacity { NumberAnimation { duration: 260 } }
                    Behavior on font.pixelSize { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
            }

            // Edge fades, over the list.
            Rectangle {
                visible: lyrics.visible
                anchors.top: parent.top
                width: parent.width
                height: 22
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.islandSurface }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            Rectangle {
                visible: lyrics.visible
                anchors.bottom: parent.bottom
                width: parent.width
                height: 22
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Theme.islandSurface }
                }
            }

            // ── UP NEXT ───────────────────────────────────────────────────

            ColumnLayout {
                id: upNext

                // As many rows as the space holds (36px art + 6px spacing),
                // under the 20px label.
                readonly property int rows: Math.max(1, Math.floor((upNext.height - 20) / 42))
                readonly property bool empty: (MediaService.queue ?? []).length === 0

                anchors.fill: parent
                visible: !root.lyricsMode
                spacing: 6

                Text {
                    visible: !upNext.empty
                    text: {
                        if (LyricsService.shown)
                            return "Up next"
                        if (LyricsService.loading)
                            return "Finding lyrics…"
                        if (LyricsService.kind === "instrumental")
                            return "Instrumental · up next"
                        return "No lyrics · up next"
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.weight: Font.DemiBold
                    color: Theme.textMuted
                }

                Repeater {
                    model: (MediaService.queue ?? []).slice(0, upNext.rows)

                    RowLayout {
                        id: next

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        spacing: 10
                        opacity: Math.max(0.35, 1 - next.index * 0.15)

                        ClippingRectangle {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: 8
                            color: Theme.islandSurfaceHover

                            Image {
                                anchors.fill: parent
                                source: next.modelData.artUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 72
                                sourceSize.height: 72
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: next.modelData.title ?? ""
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }

                            Text {
                                Layout.fillWidth: true
                                text: next.modelData.artist ?? ""
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: Theme.textMuted
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    // No lyrics and no queue: say why, centred, instead of
                    // leaving the middle of the card blank.
                    Column {
                        anchors.centerIn: parent
                        visible: upNext.empty
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: LyricsService.kind === "instrumental" ? "󰝚" : "󰎈"
                            font.family: Theme.fontMono
                            font.pixelSize: 30
                            color: Theme.textMuted
                            opacity: 0.5
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: LyricsService.loading ? "Finding lyrics…"
                                : LyricsService.kind === "instrumental" ? "Instrumental" : "No lyrics"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeRegular
                            font.weight: Font.DemiBold
                            color: Theme.textMuted
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Nothing queued"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            color: Theme.textMuted
                            opacity: 0.6
                        }
                    }
                }
            }
        }

        // ── PROGRESS AND CONTROLS ─────────────────────────────────────────

        // Click or drag to seek.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 10
            visible: MediaService.seekable

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: seek.containsMouse ? 5 : 3
                radius: height / 2
                color: Theme.islandSurfaceHover

                Behavior on height { NumberAnimation { duration: Theme.durationFast } }

                Rectangle {
                    width: parent.width * MediaService.progress
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                }
            }

            MouseArea {
                id: seek
                anchors.fill: parent
                hoverEnabled: true
                enabled: MediaService.canSeek
                cursorShape: MediaService.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: event => MediaService.seek(event.x / width)
                onPositionChanged: event => {
                    if (pressed)
                        MediaService.seek(event.x / width)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: root.clock(MediaService.position)
                visible: MediaService.seekable
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }

            Item { Layout.fillWidth: true }

            IconButton {
                icon: "󰒮"
                iconSize: 15
                enabled: MediaService.canPrevious
                opacity: MediaService.canPrevious ? 1 : 0.35
                onClicked: MediaService.previous()
            }

            // The main control, filled so it reads first.
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                radius: width / 2
                color: playMouse.containsMouse ? Theme.accentHover : Theme.accent
                scale: playMouse.pressed ? 0.92 : 1

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                Behavior on scale { NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    // The play glyph sits visually left of centre.
                    anchors.horizontalCenterOffset: MediaService.playing ? 0 : 1
                    text: MediaService.playing ? "󰏤" : "󰐊"
                    font.family: Theme.fontMono
                    font.pixelSize: 17
                    color: Theme.accentText
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MediaService.toggle()
                }
            }

            IconButton {
                icon: "󰒭"
                iconSize: 15
                enabled: MediaService.canNext
                opacity: MediaService.canNext ? 1 : 0.35
                onClicked: MediaService.next()
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.clock(MediaService.length)
                visible: MediaService.seekable
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }
        }
    }

    function clock(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds))
        const minutes = Math.floor(total / 60)
        const remainder = total % 60
        return `${minutes}:${remainder < 10 ? "0" : ""}${remainder}`
    }
}
