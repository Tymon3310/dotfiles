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

    Component.onCompleted: {
        LyricsService.subscribe()
        CavaService.subscribe()
    }
    Component.onDestruction: {
        LyricsService.release()
        CavaService.release()
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

        // ── TRACK ───────────────────────────────────────────────────────────

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
                    visible: source != "" && status === Image.Ready
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 112
                    sourceSize.height: 112
                }

                Text {
                    anchors.centerIn: parent
                    visible: !art.visible
                    text: "󰎇"
                    font.family: Theme.fontMono
                    font.pixelSize: 22
                    color: Theme.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: MediaService.title
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Spectrum {
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        barWidth: 3
                        barSpacing: 2
                        minimum: 2
                        active: MediaService.playing
                        barColor: Theme.accent
                        visible: MediaService.available
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: MediaService.artist
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: MediaService.album
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    color: Theme.textMuted
                    opacity: 0.7
                }
            }

            // What the middle is showing, as a small tag.
            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: tag.implicitWidth + 14
                implicitHeight: 18
                radius: height / 2
                color: Theme.islandSurfaceHover

                Text {
                    id: tag
                    anchors.centerIn: parent
                    text: {
                        if (LyricsService.synced)
                            return "LYRICS"
                        if (LyricsService.shown)
                            return "TEXT"
                        if (LyricsService.loading)
                            return "…"
                        return LyricsService.kind === "instrumental" ? "INSTRUMENTAL" : "UP NEXT"
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.6
                    color: LyricsService.synced ? Theme.accent : Theme.textMuted
                }
            }
        }

        // ── MIDDLE ──────────────────────────────────────────────────────────

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Synced and plain lyrics share one list; only synced ones hold a
            // line in the middle.
            ListView {
                id: lyrics

                anchors.fill: parent
                visible: LyricsService.shown
                clip: true
                interactive: false
                spacing: 4
                model: LyricsService.shown ? LyricsService.lines : []

                currentIndex: LyricsService.synced ? Math.max(0, LyricsService.index) : -1
                highlightRangeMode: LyricsService.synced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
                preferredHighlightBegin: lyrics.height / 2 - 14
                preferredHighlightEnd: lyrics.height / 2 + 14
                highlightMoveDuration: 420
                highlightMoveVelocity: -1
                highlightResizeDuration: 200
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

            // ── UP NEXT ─────────────────────────────────────────────────────

            ColumnLayout {
                anchors.fill: parent
                visible: !LyricsService.shown
                spacing: 6

                Text {
                    text: {
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
                    model: (MediaService.queue ?? []).slice(0, 3)

                    RowLayout {
                        id: next

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        spacing: 10
                        opacity: 1 - next.index * 0.2

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

                Text {
                    visible: (MediaService.queue ?? []).length === 0
                    text: "Nothing queued"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                    opacity: 0.7
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ── PROGRESS AND CONTROLS ───────────────────────────────────────────

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

            IconButton {
                icon: MediaService.playing ? "󰏤" : "󰐊"
                iconSize: 18
                onClicked: MediaService.toggle()
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
