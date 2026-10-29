import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// One notification, as a popup (on the island or the fullscreen overlay) or
// as a history row in the dashboard.
//
//   click        run its default action, or open what it points at
//   right-click  dismiss
//   swipe        dismiss (sideways, either way)
Item {
    id: root

    property int key: -1
    property bool popup: true
    property int maxBodyLines: root.popup ? 5 : 3

    readonly property var entry: NotificationService.entry(root.key)
    readonly property bool critical: root.entry?.critical ?? false
    readonly property bool alive: root.entry?.alive ?? false

    // The default action is what a click on the card does, so only the other
    // labelled ones get buttons (kitty labels its default " "). Only while
    // the application is still listening.
    readonly property var buttons: root.alive
        ? (root.entry?.actions ?? []).filter(action =>
            action.identifier !== "default" && action.text.trim() !== "")
        : []

    // The picture keeps its shape: a wide one (a screenshot) gets a wider
    // box, bounded so it can't take over the row.
    readonly property int pictureHeight: root.popup ? 36 : 30
    readonly property real pictureWidth: picture.hasPicture
        ? Math.max(root.pictureHeight, Math.min(root.pictureHeight * 2, root.pictureHeight * picture.aspect))
        : root.pictureHeight

    implicitHeight: body.implicitHeight + 2 * body.anchors.margins

    function dismiss(): void {
        if (root.popup)
            NotificationService.close(root.key)
        else
            NotificationService.remove(root.key)
    }

    // Countdown, drawn as the ring around the close button. Ticks per frame
    // while shown; held time is frozen by the service.
    property real now: Date.now()
    Timer {
        interval: 16
        repeat: true
        running: root.popup && root.visible && !NotificationService.held
            && (root.entry?.timeout ?? 0) > 0
        onTriggered: root.now = Date.now()
    }
    readonly property real progress: {
        const e = root.entry
        if (!e || e.timeout <= 0)
            return 1
        const remaining = NotificationService.held ? e.remaining : e.deadline - root.now
        return Math.max(0, Math.min(1, remaining / e.timeout))
    }

    // Swiped far enough: slide the rest of the way out, then go.
    SequentialAnimation {
        id: flingOut

        property real to: 0

        ParallelAnimation {
            NumberAnimation { target: surface; property: "x"; to: flingOut.to; duration: Theme.durationMedium; easing.type: Easing.OutCubic }
            NumberAnimation { target: surface; property: "opacity"; to: 0; duration: Theme.durationMedium }
        }
        ScriptAction { script: root.dismiss() }
    }

    NumberAnimation {
        id: snapBack
        target: surface
        property: "x"
        to: 0
        duration: Theme.durationSpring
        easing.type: Theme.easingSpring
        easing.overshoot: Theme.springOvershoot
    }

    Rectangle {
        id: surface

        width: root.width
        height: root.height
        radius: Theme.radiusSmall
        color: hover.hovered ? Theme.rowHover : Theme.rowRest
        opacity: 1 - Math.min(0.6, Math.abs(surface.x) / root.width)

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onTapped: (point, button) => {
                if (button === Qt.RightButton)
                    root.dismiss()
                else
                    NotificationService.activate(root.key)
            }
        }

        DragHandler {
            target: surface
            yAxis.enabled: false
            onActiveChanged: {
                if (active) {
                    snapBack.stop()
                    return
                }
                if (Math.abs(surface.x) > root.width * 0.3) {
                    flingOut.to = surface.x > 0 ? root.width : -root.width
                    flingOut.start()
                } else {
                    snapBack.start()
                }
            }
        }

        RowLayout {
            id: body

            anchors.fill: parent
            anchors.margins: 6
            spacing: 10

            NotificationPicture {
                id: picture
                Layout.preferredWidth: root.pictureWidth
                Layout.preferredHeight: root.pictureHeight
                Layout.alignment: Qt.AlignTop
                entry: root.entry
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: root.entry?.summary || root.entry?.appName || ""
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        text: root.popup
                            ? (root.entry?.appName ?? "")
                            : NotificationService.ago(root.entry?.time ?? Date.now())
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        color: root.critical ? Theme.red : Theme.textMuted
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.entry?.body ?? ""
                    // Applications send Pango markup, and the server says it
                    // supports it.
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: root.maxBodyLines
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.textMuted
                    linkColor: Theme.accent
                    onLinkActivated: link => {
                        Qt.openUrlExternally(link)
                        NotificationService.remove(root.key)
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: root.buttons.length > 0
                    spacing: 5

                    Repeater {
                        model: root.buttons

                        PillButton {
                            required property var modelData

                            text: modelData.text
                            implicitHeight: 20
                            horizontalPadding: 8
                            onClicked: NotificationService.invoke(root.key, modelData.identifier)
                        }
                    }
                }
            }

            // Close, ringed by the time left on a popup. In the history it
            // only shows on hover.
            Item {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                opacity: root.popup || hover.hovered ? 1 : 0

                RingIndicator {
                    anchors.fill: parent
                    visible: root.popup && (root.entry?.timeout ?? 0) > 0
                    thickness: 2
                    trackColor: Qt.rgba(1, 1, 1, 0.08)
                    fillColor: root.critical ? Theme.red : Theme.accent
                    progress: root.progress
                    sweepDuration: 0
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    radius: 8
                    color: closeMouse.containsMouse ? Theme.islandSurfaceHover : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        color: closeMouse.containsMouse ? Theme.text
                            : root.critical ? Theme.red : Theme.textMuted
                    }
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismiss()
                }
            }
        }
    }
}
