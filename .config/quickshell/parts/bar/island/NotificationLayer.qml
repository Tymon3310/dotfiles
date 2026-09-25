// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T I F I C A T I O N   L A Y E R                                    │
// │   the island while a notification is shown                               │
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

// The island while a notification is shown. It sizes itself to its content:
// the body wraps (up to `maxBodyLines`), a long title widens it, and a
// picture is shown at its own shape (a screenshot comes out landscape, an
// avatar square). A host reads `wantWidth` × `wantHeight` and grows the island
// to fit.
//
// Interactions: a click anywhere runs the notification's default action when
// it has one; its other actions are pills under the body; the cross closes it
// and tells the application.
Item {
    id: root

    readonly property var notification: NotificationService.current
    readonly property bool critical: NotificationService.critical

    readonly property var actions: root.notification ? (root.notification.actions ?? []) : []
    readonly property bool hasDefault: root.actions.some(action => action.identifier === "default")
    // Every action with a label gets a pill, the default one included, so
    // "Open" is visible and not only a click on the whole thing.
    readonly property var buttons: root.actions.filter(action => action.text !== "")

    readonly property int minWidth: 430
    readonly property int maxWidth: 600
    readonly property int maxBodyLines: 8

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

    // Behind the row: the click that runs the default action. The pills and
    // the cross sit above it and take their own clicks.
    MouseArea {
        anchors.fill: parent
        enabled: root.hasDefault
        cursorShape: root.hasDefault ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: NotificationService.invoke("default")
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
                        onClicked: NotificationService.invoke(modelData.identifier)
                    }
                }
            }
        }

        IconButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "󰅖"
            iconSize: 12
            onClicked: NotificationService.close()
        }
    }
}
