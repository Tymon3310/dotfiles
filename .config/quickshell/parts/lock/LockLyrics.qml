import QtQuick

import "../theme"
import "../services"

// Synced lyrics for the lock screen: the current line large, the previous
// and next ones dim around it, scrolling up as the song moves on.
// Right-aligned, to sit above the media card.
Item {
    id: root

    property int screenHeight: 1080
    property real maxWidth: 900
    // Whether the lyrics are wanted at all (the media is showing). They are
    // fetched while wanted, and the block shows once they have arrived.
    property bool wanted: true
    // Qt.AlignRight (beside the media card) or Qt.AlignHCenter (the stage).
    property int align: Qt.AlignRight

    readonly property bool shown: LyricsService.synced && MediaService.available
    readonly property int index: LyricsService.index
    readonly property int size: Math.max(22, Math.round(root.screenHeight * 0.024))
    readonly property int step: Math.round(root.size * 1.55)

    function lineAt(offset: int): string {
        const i = root.index + offset
        const lines = LyricsService.lines
        if (i < 0 || i >= lines.length)
            return ""
        return lines[i].text ?? ""
    }

    implicitWidth: root.maxWidth
    implicitHeight: column.implicitHeight

    // Position updates at frame rate and the lyrics fetch only while shown.
    property bool subscribed: false
    function updateSubscription(): void {
        const want = root.wanted
        if (want && !root.subscribed)
            LyricsService.subscribe()
        else if (!want && root.subscribed)
            LyricsService.release()
        root.subscribed = want
    }
    Component.onCompleted: root.updateSubscription()
    onWantedChanged: root.updateSubscription()
    Component.onDestruction: {
        if (root.subscribed)
            LyricsService.release()
    }

    // A new line: everything starts one step lower and rises into place.
    onIndexChanged: scroll.restart()
    NumberAnimation {
        id: scroll
        target: shift
        property: "y"
        from: root.step
        to: 0
        duration: Math.round(420 * Theme.motion)
        easing.type: Easing.OutCubic
    }

    Column {
        id: column

        anchors.horizontalCenter: root.align === Qt.AlignHCenter ? parent.horizontalCenter : undefined
        anchors.right: root.align === Qt.AlignHCenter ? undefined : parent.right
        width: root.maxWidth
        spacing: Math.round(root.size * 0.4)
        transform: Translate { id: shift }

        Repeater {
            model: [
                { offset: -1, opacity: 0.28, scale: 0.8 },
                { offset: 0, opacity: 1, scale: 1 },
                { offset: 1, opacity: 0.42, scale: 0.8 }
            ]

            // The current line wraps onto a second line when it is long;
            // the dim ones around it stay on one and are cut at the end.
            Text {
                required property var modelData
                readonly property bool current: modelData.offset === 0

                width: root.maxWidth
                horizontalAlignment: root.align === Qt.AlignHCenter ? Text.AlignHCenter : Text.AlignRight
                text: root.lineAt(modelData.offset)
                wrapMode: current ? Text.Wrap : Text.NoWrap
                maximumLineCount: current ? 2 : 1
                elide: Text.ElideRight
                lineHeight: 0.95
                font.family: Theme.fontFamily
                font.pixelSize: root.size
                font.weight: current ? Font.DemiBold : Font.Medium
                color: Theme.text
                opacity: modelData.opacity
                scale: modelData.scale
                transformOrigin: root.align === Qt.AlignHCenter ? Item.Bottom : Item.BottomRight
            }
        }
    }
}
