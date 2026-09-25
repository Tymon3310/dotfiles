// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T R A Y   M E N U   L I S T                                            │
// │   a tray item's menu, drawn in the island                                │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

import "../../../theme"

// A header with the application's icon and name, then its menu as a column of
// pills. Check boxes are drawn as small switches and radio items as dots, on
// the trailing edge; an entry with children slides its submenu in from the
// right, and the header becomes the way back.
//
// Give it the `menu` (and optionally the `item`) from TrayWidget.menuRequested.
// `contentHeight` is what it wants, for a host that sizes the island to fit.
Item {
    id: root

    property var menu: null
    property var item: null

    signal itemTriggered()

    // Submenus opened, deepest last, as { handle, label }. Reset whenever a
    // new menu arrives.
    property var trail: []

    readonly property bool nested: root.trail.length > 0
    readonly property var current: root.nested
        ? root.trail[root.trail.length - 1].handle : root.menu

    // +1 while going deeper, -1 while coming back: where the page slides from.
    property int direction: 1

    onMenuChanged: root.trail = []

    readonly property int rowHeight: 34
    readonly property int separatorHeight: 11
    readonly property int headerHeight: 46

    readonly property real contentHeight: root.headerHeight + list.contentHeight + 6

    function open(entry: var): void {
        root.direction = 1
        root.trail = root.trail.concat([{ handle: entry, label: root.clean(entry.text) }])
    }

    function back(): void {
        root.direction = -1
        root.trail = root.trail.slice(0, -1)
    }

    // Menu labels carry mnemonics ("&Quit") and sometimes a stray "_".
    function clean(text: var): string {
        return `${text ?? ""}`.replace(/&(?!&)/g, "").replace(/^_/, "")
    }

    // Replays the slide on every page change.
    onCurrentChanged: slide.restart()

    QsMenuOpener {
        id: opener
        menu: root.current
    }

    readonly property bool hasAnyIcon: {
        for (const entry of opener.children.values) {
            if (entry.icon && entry.icon !== "")
                return true
        }
        return false
    }

    // ── HEADER ──────────────────────────────────────────────────────────────
    //
    // The application at the top level; the submenu's name, with a way back,
    // below it.

    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        height: root.headerHeight

        Rectangle {
            anchors.fill: parent
            anchors.bottomMargin: 6
            radius: Theme.radiusMedium
            color: headerMouse.containsMouse ? Theme.islandSurfaceHover : Theme.islandSurface

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 12
                spacing: 10

                Item {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22

                    Image {
                        anchors.fill: parent
                        visible: !root.nested && source != ""
                        source: root.item?.icon ?? ""
                        sourceSize.width: 44
                        sourceSize.height: 44
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.nested
                        text: "󰁍"
                        font.family: Theme.fontMono
                        font.pixelSize: 15
                        color: Theme.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: root.nested
                            ? root.trail[root.trail.length - 1].label
                            : (root.item?.tooltipTitle || root.item?.title || root.item?.id || "Menu")
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeRegular
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.nested
                            ? (root.trail.length > 1 ? `in ${root.trail[root.trail.length - 2].label}` : "back")
                            : (root.item?.tooltipDescription ?? "")
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }
            }

            MouseArea {
                id: headerMouse
                anchors.fill: parent
                enabled: root.nested
                hoverEnabled: true
                cursorShape: root.nested ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.back()
            }
        }
    }

    // ── ENTRIES ─────────────────────────────────────────────────────────────

    ListView {
        id: list

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        interactive: list.contentHeight > list.height
        boundsBehavior: Flickable.StopAtBounds
        spacing: 2
        clip: true

        // The live model, so a menu the application updates changes row by
        // row instead of the list being rebuilt from a stale snapshot.
        model: opener.children

        // The page slides a little and fades in, from the side it came from.
        transform: Translate { id: shift }

        ParallelAnimation {
            id: slide
            NumberAnimation {
                target: shift; property: "x"
                from: 18 * root.direction; to: 0
                duration: Theme.durationMedium; easing.type: Theme.easing
            }
            NumberAnimation {
                target: list; property: "opacity"
                from: 0; to: 1
                duration: Theme.durationMedium; easing.type: Theme.easing
            }
        }

        ScrollBar.vertical: ScrollBar {
            active: list.interactive
            width: 3
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 3
                radius: 1.5
                color: Theme.islandBorder
            }
        }

        delegate: Item {
            id: entry

            required property var modelData

            readonly property bool separator: entry.modelData.isSeparator
                || root.clean(entry.modelData.text).replace(/[-_ ]/g, "") === ""
                    && !entry.modelData.icon
            readonly property bool checkable: entry.modelData.buttonType === QsMenuButtonType.CheckBox
            readonly property bool radio: entry.modelData.buttonType === QsMenuButtonType.RadioButton
            readonly property bool checked: entry.modelData.checkState === Qt.Checked
            readonly property bool usable: entry.modelData.enabled

            width: list.width
            height: entry.separator ? root.separatorHeight : root.rowHeight

            Rectangle {
                visible: entry.separator
                anchors.verticalCenter: parent.verticalCenter
                x: 12
                width: parent.width - 24
                height: 1
                color: Theme.hairline
            }

            Rectangle {
                id: pill

                visible: !entry.separator
                anchors.fill: parent
                radius: Theme.radiusMedium
                color: mouse.containsMouse && entry.usable ? Theme.islandSurfaceHover : "transparent"
                opacity: entry.usable ? 1 : 0.35
                scale: mouse.pressed ? 0.98 : 1

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                Behavior on scale { NumberAnimation { duration: Theme.durationFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    // Leading icon, kept as a slot whenever any entry has one
                    // so the labels line up.
                    Item {
                        visible: root.hasAnyIcon
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16

                        Image {
                            anchors.fill: parent
                            source: entry.modelData.icon ?? ""
                            sourceSize.width: 32
                            sourceSize.height: 32
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.clean(entry.modelData.text)
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeRegular - 0.5
                        color: mouse.containsMouse ? Theme.text : Qt.rgba(1, 1, 1, 0.86)

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    }

                    // Check box: a small switch.
                    Rectangle {
                        visible: entry.checkable
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 15
                        radius: height / 2
                        color: entry.checked ? Theme.accent : Theme.islandBorder

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                        Rectangle {
                            width: 11
                            height: 11
                            radius: 5.5
                            y: 2
                            x: entry.checked ? parent.width - width - 2 : 2
                            color: "white"

                            Behavior on x { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
                        }
                    }

                    // Radio: a ring, filled when chosen.
                    Rectangle {
                        visible: entry.radio
                        Layout.preferredWidth: 13
                        Layout.preferredHeight: 13
                        radius: 6.5
                        color: "transparent"
                        border.width: 1.5
                        border.color: entry.checked ? Theme.accent : Theme.textMuted

                        Rectangle {
                            anchors.centerIn: parent
                            width: 6
                            height: 6
                            radius: 3
                            visible: entry.checked
                            color: Theme.accent
                        }
                    }

                    Text {
                        visible: entry.modelData.hasChildren
                        text: "󰅂"
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        color: mouse.containsMouse ? Theme.text : Theme.textMuted
                    }
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: entry.usable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (entry.modelData.hasChildren) {
                            root.open(entry.modelData)
                            return
                        }
                        entry.modelData.triggered()
                        // A switch stays open to show its new state.
                        if (!entry.checkable && !entry.radio)
                            root.itemTriggered()
                    }
                }
            }
        }
    }
}
