// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T I F I C A T I O N   E N T R Y                                    │
// │   one notification on the island                                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import Quickshell.Services.Notifications

import "../../theme"
import "../../services"
import "../../components"

// One notification on the island, from a NotificationService copy; the
// stack (NotificationLayer) lays several out. It sizes itself to its content:
// the body wraps (up to `maxBodyLines`), a long title widens it, and a
// picture is shown at its own shape (a screenshot comes out landscape, an
// avatar square). `wantWidth` × `wantHeight` is what it asks for.
//
// Interactions: a click anywhere runs its default action when it has one; its
// other actions are pills under the body; the cross closes it and tells the
// application. All by its key, so each entry acts on its own notification.
Item {
    id: root

    implicitWidth: root.wantWidth
    implicitHeight: root.wantHeight
    height: root.wantHeight

    property var notification: null
    readonly property bool critical: root.notification
        ? NotificationService.isCritical(root.notification) : false
    readonly property int key: root.notification ? root.notification.key : -1

    readonly property var actions: root.notification ? (root.notification.actions ?? []) : []
    readonly property bool hasDefault: root.actions.some(action => action.identifier === "default")
    // Every action with a label gets a pill, the default one included, so
    // "Open" is visible and not only a click on the whole thing.
    readonly property var buttons: root.actions.filter(action => action.text !== "")

    readonly property int minWidth: 430
    readonly property int maxWidth: 600
    property int maxBodyLines: 8

    // Timeout countdown progress (1.0 -> 0.0)
    readonly property real progressFraction: {
        if (!root.notification || root.critical)
            return 1.0
        const deadline = NotificationService.deadlines[root.notification.key]
        if (!deadline)
            return 1.0
        const total = Math.max(1000, deadline - root.notification.time)
        const remaining = Math.max(0, deadline - progressTicker.now)
        return Math.min(1.0, Math.max(0.0, remaining / total))
    }

    Timer {
        id: progressTicker
        property real now: Date.now()
        interval: 33
        repeat: true
        running: !NotificationService.held
        onTriggered: now = Date.now()
    }

    // The picture: 38 px square for icons and avatars, up to `pictureWide`
    // across for a landscape image.
    readonly property int pictureHeight: picture.landscape ? 56 : 38
    readonly property int pictureWide: 100
    readonly property real pictureWidth: picture.landscape
        ? Math.min(root.pictureWide, root.pictureHeight * picture.aspect) : root.pictureHeight

    // Room the title row asks for: picture, gaps, title, app name, close.
    readonly property real wantWidth: Math.max(root.minWidth, Math.min(root.maxWidth,
        root.pictureWidth + 11 + summary.implicitWidth + 6 + app.implicitWidth + 11 + 24))
    readonly property real wantHeight: Math.max(root.pictureHeight + 6, content.implicitHeight)

    // Behind the row: the click that runs the default action or opens the app.
    // The pills and the cross sit above it and take their own clicks.
    MouseArea {
        anchors.fill: parent
        enabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: NotificationService.activate(root.notification)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 11

        // The picture with the app's icon as a badge, the icon alone, or a
        // bell. Saved to the cache once shown, for the history.
        NotificationPicture {
            id: picture

            Layout.preferredWidth: root.pictureWidth
            Layout.preferredHeight: root.pictureHeight
            Layout.alignment: Qt.AlignVCenter
            notification: root.notification
            critical: root.critical
            keep: true
        }

        ColumnLayout {
            id: content

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    id: summary

                    Layout.fillWidth: true
                    text: root.notification ? root.notification.summary : ""
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Text {
                    id: app

                    text: root.notification ? root.notification.appName : ""
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    color: root.critical ? Theme.red : Theme.textMuted
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notification ? (root.notification.body ?? "") : ""
                // Applications send Pango markup and the server advertises support
                // for it, so it has to be rendered rather than shown as tags.
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
                    NotificationService.remove(root.notification)
                }
            }

            // The actions, as pills.
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: root.buttons.length > 0
                spacing: 6

                Repeater {
                    model: root.buttons

                    PillButton {
                        required property var modelData

                        text: modelData.text
                        active: modelData.identifier === "default"
                        implicitHeight: 24
                        horizontalPadding: 11
                        onClicked: NotificationService.invokeKey(root.key, modelData.identifier)
                    }
                }
            }
        }

        Item {
            id: closeContainer
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24

            RingIndicator {
                anchors.fill: parent
                thickness: 2
                trackColor: Qt.rgba(1, 1, 1, 0.08)
                fillColor: root.critical ? Theme.red : Theme.accent
                progress: root.progressFraction
                sweepDuration: 40

                Rectangle {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: 9
                    color: closeMouse.containsMouse ? Theme.islandSurfaceHover : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        color: closeMouse.containsMouse ? Theme.text : Theme.textMuted
                    }
                }
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationService.closeKey(root.key)
            }
        }
    }
}
