import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray

import "../parts/theme"
import "../parts/services"
import "../parts/components"
import "../parts/bar/modules"
import "../parts/bar/widgets"
import "../parts/bar/island"
import "../parts/bar/island/controls"

// The top bar as one island: a black notch attached to the top edge in the
// middle of the screen, nothing at the screen edges. The row holds the
// workspaces, the player, the time, the processor, the tray and a power
// button, with small spacers between them.
//
// Clicking the player, the time or the processor grows the island down into
// one combined dashboard (IslandDashboard.qml); the power button into the
// session menu. Tray icons and workspace dots keep their own clicks. A tray
// menu and a notification (impasto's NotificationLayer) also hang under the
// row; anything opened outranks the notification.
//
// The old bar is still in Bar.qml; shell.qml picks which one to build.
PanelWindow {
    id: bar

    property var modelData
    screen: modelData

    // ── STATE ───────────────────────────────────────────────────────────────

    // "dashboard", "session", "tray" or "".
    property string openId: ""
    readonly property bool expanded: bar.openId !== ""
    readonly property bool dashboardOpen: bar.openId === "dashboard"

    // The tray item and its menu, set when its icon is right-clicked and
    // dropped as soon as the menu closes: a menu handle kept past that goes
    // stale when the application rebuilds its menu (as some do when a device
    // connects), and a list still built from it crashes Quickshell.
    property var trayMenu: null
    property var trayItem: null

    onOpenIdChanged: {
        if (bar.openId !== "tray") {
            bar.trayMenu = null
            bar.trayItem = null
        }
    }

    // The application left the tray while its menu was open.
    Connections {
        target: SystemTray.items

        function onValuesChanged(): void {
            if (bar.trayItem && SystemTray.items.values.indexOf(bar.trayItem) < 0)
                bar.close()
        }
    }

    readonly property bool notifying: NotificationService.active && !bar.expanded

    function toggle(id: string): void {
        bar.openId = bar.openId === id ? "" : id
    }

    function close(): void {
        bar.openId = ""
    }

    // What hangs under the row, and how large, for the island to grow to
    // before the content is built.
    readonly property string below: bar.expanded ? bar.openId
        : bar.notifying ? "notification" : ""

    readonly property size belowSize: {
        switch (bar.below) {
        case "notification":
            // Grows with the notification (NotificationLayer's own measure).
            return notificationLoader.item
                ? Qt.size(notificationLoader.item.wantWidth, notificationLoader.item.wantHeight + 12)
                : Qt.size(430, 56)
        case "tray":
            return Qt.size(280, Math.min(460, trayLoader.item?.contentHeight ?? 60))
        case "session":
            return Qt.size(560, 130)
        case "dashboard":
            // IslandDashboard's boardWidth × boardHeight.
            return Qt.size(1084, 724)
        }
        return Qt.size(0, 0)
    }

    // ── SURFACE ─────────────────────────────────────────────────────────────

    anchors {
        top: true
        left: true
        right: true
    }

    // Tall enough for the largest detail and never resized: resizing a layer
    // surface every animation frame makes it jitter. Input goes through the
    // mask, so the empty part is click-through.
    implicitHeight: 780
    exclusiveZone: Theme.capsuleHeight
    color: "transparent"

    mask: Region {
        item: island
    }

    // Keyboard and a Hyprland focus grab only while a detail is open: the grab
    // closes it on a click anywhere else.
    WlrLayershell.keyboardFocus: bar.expanded
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: bar.expanded
        windows: [bar]
        onCleared: bar.close()
    }

    // ── ISLAND ──────────────────────────────────────────────────────────────

    readonly property int pad: 14
    readonly property int openRadius: Theme.radiusLarge + 4

    Rectangle {
        id: island

        anchors.horizontalCenter: parent.horizontalCenter
        y: 0

        width: Math.max(row.width + 2 * bar.pad,
            bar.below !== "" ? bar.belowSize.width + 2 * bar.pad : 0)
        height: Theme.capsuleHeight
            + (bar.below !== "" ? bar.belowSize.height + bar.pad : 0)

        color: Theme.island
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: bar.below !== "" ? bar.openRadius : Theme.capsuleHeight / 2
        bottomRightRadius: bottomLeftRadius

        Behavior on width { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
        Behavior on height { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }
        Behavior on bottomLeftRadius { NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing } }

        focus: bar.expanded
        Keys.onEscapePressed: bar.close()

        // The row of parts, always on top.
        Row {
            id: row

            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            height: Theme.capsuleHeight

            // Grey pill while this screen's monitor is not the focused one.
            WorkspacesWidget {
                anchors.verticalCenter: parent.verticalCenter
                monitor: bar.screen?.name ?? ""
            }

            IslandSpacer {}

            // Right click plays or pauses; the wheel sets Spotify's own
            // volume, not the system's.
            Chip {
                module: "media"
                visible: MediaService.available
                onRightClicked: MediaService.toggle()
                onWheel: delta => MediaService.nudgeVolume(delta > 0 ? 0.05 : -0.05)
            }

            IslandSpacer { visible: MediaService.available }

            Pressable {
                implicitWidth: clock.implicitWidth + 12
                ClockModule { id: clock; anchors.centerIn: parent }
            }

            IslandSpacer {}

            Chip { module: "stats" }

            IslandSpacer { visible: tray.visible }

            TrayWidget {
                id: tray
                anchors.verticalCenter: parent.verticalCenter
                onMenuRequested: (menu, centerX, item) => {
                    if (bar.openId === "tray" && bar.trayMenu === menu) {
                        bar.close()
                        return
                    }
                    bar.trayItem = item
                    bar.trayMenu = menu
                    bar.openId = "tray"
                }
            }

            IslandSpacer {}

            Glyph {
                opens: "session"
                glyph: "󰐥"
                hot: Theme.red
            }
        }

        // ── BELOW THE ROW ───────────────────────────────────────────────────

        Item {
            id: detail

            x: (island.width - width) / 2
            y: Theme.capsuleHeight
            width: bar.belowSize.width
            height: bar.belowSize.height
            clip: true

            opacity: bar.below !== "" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationMedium } }

            // Built only while a menu is open (see `trayMenu`); the island
            // grows to its height once it has laid out.
            Loader {
                id: trayLoader
                anchors.fill: parent
                active: bar.below === "tray" && bar.trayMenu !== null
                sourceComponent: TrayMenuList {
                    menu: bar.trayMenu
                    item: bar.trayItem
                    onItemTriggered: bar.close()
                }
            }

            Loader {
                id: notificationLoader
                anchors.fill: parent
                active: bar.below === "notification"
                sourceComponent: NotificationLayer {}
            }

            Loader {
                anchors.fill: parent
                active: bar.below === "session"
                sourceComponent: SessionPanel {
                    onClosed: bar.close()
                }
            }

            Loader {
                anchors.fill: parent
                active: bar.below === "dashboard"
                sourceComponent: IslandDashboard {
                    onClosed: bar.close()
                }
            }
        }
    }

    // Concave curves where the island meets the screen edge.
    NotchFillet {
        x: island.x - width
        y: 0
        mirrored: true
    }

    NotchFillet {
        x: island.x + island.width
        y: 0
    }

    // ── PIECES ──────────────────────────────────────────────────────────────

    // A clickable slot in the row: a click opens `opens`. Lit under the
    // pointer only, not while what it opened is showing.
    component Pressable: Item {
        id: pressable

        property string opens: "dashboard"
        readonly property bool hovered: mouse.containsMouse

        signal rightClicked()
        signal wheel(int delta)

        implicitHeight: Theme.capsuleHeight
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            radius: height / 2
            color: pressable.hovered ? Theme.islandSurface : "transparent"

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            z: 1
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: event => {
                if (event.button === Qt.RightButton)
                    pressable.rightClicked()
                else
                    bar.toggle(pressable.opens)
            }
            onWheel: event => pressable.wheel(event.angleDelta.y)
        }
    }

    // A module's chip: its glyph and figure.
    component Chip: Pressable {
        id: chip

        property string module: ""

        implicitWidth: face.implicitWidth

        ChipFace {
            id: face
            anchors.verticalCenter: parent.verticalCenter
            moduleId: chip.module
        }
    }

    // A lone glyph; `hot` is its colour under the pointer.
    component Glyph: Pressable {
        id: glyphButton

        property string glyph: ""
        property color hot: Theme.text

        implicitWidth: Theme.capsuleHeight

        Text {
            anchors.centerIn: parent
            text: glyphButton.glyph
            font.family: Theme.fontMono
            font.pixelSize: Math.round(Theme.capsuleHeight * 0.44)
            color: glyphButton.hovered ? glyphButton.hot : Theme.textMuted

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }
    }
}
