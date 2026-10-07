import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray

import "../parts/theme"
import "../parts/services"
import "../parts/components"
import "../parts/bar/widgets"
import "../parts/bar/island"
import "../parts/bar/island/controls"

PanelWindow {
    id: bar

    property var modelData
    screen: modelData

    // ── STATE ────────────────────────────────────────────────────────────────

    // "dashboard", "session", "tray" or "".
    property string openId: ""
    readonly property bool expanded: bar.openId !== ""
    readonly property bool dashboardOpen: bar.openId === "dashboard"

    // Dropped as soon as the menu closes: a menu handle kept past that goes
    // stale when the application rebuilds its menu (some do when a device
    // connects), and a list later built from it crashes Quickshell.
    property var trayMenu: null
    property var trayItem: null

    onOpenIdChanged: {
        if (bar.openId !== "tray") {
            bar.trayMenu = null
            bar.trayItem = null
        }
    }

    Connections {
        target: SystemTray.items
        function onValuesChanged(): void {
            if (bar.trayItem && SystemTray.items.values.indexOf(bar.trayItem) < 0)
                bar.close()
        }
    }

    readonly property bool isFullscreen: HyprlandService.isFullscreenOn(bar.screen ? bar.screen.name : "")
    readonly property bool headsUpActive: (SettingsService.notificationHeadsUpMode === "always")
        || (SettingsService.notificationHeadsUpMode === "fullscreen" && bar.isFullscreen)

    readonly property bool notifying: NotificationService.active && !bar.expanded && !bar.headsUpActive
    readonly property bool recording: ScreenRecorderService.recording

    function toggle(id: string): void {
        bar.openId = bar.openId === id ? "" : id
    }

    function close(): void {
        bar.openId = ""
    }

    readonly property string below: bar.expanded ? bar.openId
        : bar.notifying ? "notification" : ""

    readonly property size belowSize: {
        switch (bar.below) {
        case "notification":
            return notificationLoader.item
                ? Qt.size(notificationLoader.item.wantWidth, notificationLoader.item.wantHeight)
                : Qt.size(430, 56)
        case "tray":
            return Qt.size(280, Math.min(460, detailLoader.item?.contentHeight ?? 60))
        case "session":
            return Qt.size(560, 100)
        case "dashboard":
            return Qt.size(1084, 724)
        }
        return Qt.size(0, 0)
    }

    // ── OSD (VOLUME, CAPS LOCK, NUM LOCK) ────────────────────────────────────

    property bool osdActive: false
    property string osdIcon: ""
    property string osdLabel: ""
    property real osdProgress: -1

    readonly property Timer osdExpiryTimer: Timer {
        interval: 1800
        onTriggered: bar.osdActive = false
    }

    Connections {
        target: OsdService

        function onRequested(icon: string, label: string, progress: real): void {
            if (bar.expanded)
                return
            bar.osdIcon = icon
            bar.osdLabel = label
            bar.osdProgress = progress
            bar.osdActive = true
            bar.osdExpiryTimer.restart()
        }
    }

    property alias notchYOffset: motion.notchYOffset
    property alias islandsEmergeProgress: motion.islandsEmergeProgress
    property alias isDemorphed: motion.isDemorphed

    IslandMotion {
        id: motion
        island: bar
    }

    // ── SURFACE ──────────────────────────────────────────────────────────────

    anchors {
        top: true
        left: true
        right: true
    }

    readonly property int capsuleH: Theme.capsuleHeight
    readonly property int barTopMargin: Theme.barTopMargin
    readonly property int pad: 14
    readonly property int openRadius: Theme.radiusLarge + 4

    implicitHeight: 780
    // Reduced exclusiveZone to reduce the gap between the bar and tiled windows
    exclusiveZone: bar.capsuleH + bar.barTopMargin - 8
    color: "transparent"

    mask: Region {
        item: island
        Region { item: leftZone }
        Region { item: rightZone }
    }

    WlrLayershell.keyboardFocus: bar.expanded
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: bar.expanded
        windows: [bar]
        onCleared: bar.close()
    }

    // ── LEFT FLOATING ZONE ───────────────────────────────────────────────────

    Row {
        id: leftZone
        z: 1

        x: island.x - (width + Theme.capsuleSpacing) * bar.islandsEmergeProgress
        y: bar.barTopMargin
        spacing: Theme.capsuleSpacing

        opacity: Math.min(1, bar.islandsEmergeProgress * 1.5)
        visible: opacity > 0

        // Workspaces Capsule (borderless)
        Rectangle {
            height: bar.capsuleH
            width: wsWidget.implicitWidth + 12
            radius: height / 2
            color: Theme.island
            border.width: 1
            border.color: Theme.hairline

            WorkspacesWidget {
                id: wsWidget
                anchors.centerIn: parent
                monitor: bar.screen ? bar.screen.name : ""
                chromeless: true
            }
        }
    }

    // ── CENTER MAIN ISLAND (NOTCH) ───────────────────────────────────────────

    Rectangle {
        id: island
        z: 2

        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.notchYOffset

        width: bar.below !== ""
            ? bar.belowSize.width + 2 * bar.pad
            : bar.osdActive
                ? Math.max(260, osdLayerItem.implicitWidth + 36)
                : bar.recording
                    ? recordingItem.implicitWidth + 24
                    : bar.isDemorphed
                        ? 72
                        : IslandMetrics.notchWidth

        height: bar.below !== ""
            ? bar.belowSize.height + 2 * bar.pad
            : bar.capsuleH + bar.barTopMargin

        color: Theme.island
        border.width: 0
        clip: true

        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: bar.below !== "" ? bar.openRadius : Theme.radiusLarge
        bottomRightRadius: bar.below !== "" ? bar.openRadius : Theme.radiusLarge

        Behavior on width {
            NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
        }
        Behavior on height {
            NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
        }

        focus: bar.expanded
        Keys.onEscapePressed: bar.close()

        // Click and wheel interaction for the top capsule
        MouseArea {
            id: islandCapsuleMouse
            anchors.top: parent.top
            anchors.topMargin: bar.barTopMargin
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: bar.capsuleH
            enabled: bar.below === ""
            z: 10
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    MediaService.toggle()
                else
                    bar.toggle("dashboard")
            }
            onWheel: event => MediaService.nudgeVolume(event.angleDelta.y > 0 ? 0.05 : -0.05)
        }

        IslandRestRow {
            anchors.top: parent.top
            anchors.topMargin: bar.barTopMargin
            anchors.horizontalCenter: parent.horizontalCenter

            opacity: (bar.below !== "" || bar.osdActive || bar.isDemorphed || bar.recording) ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        }

        // ── RECORDING INDICATOR (replaces rest row while capturing) ───
        // z above the capsule mouse so pause/stop stay clickable.
        RecordingIndicator {
            id: recordingItem
            z: 11
            anchors.top: parent.top
            anchors.topMargin: bar.barTopMargin
            anchors.horizontalCenter: parent.horizontalCenter

            // Recording overrides demorph: the island stays wide to show it.
            opacity: (bar.recording && bar.below === "" && !bar.osdActive) ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        }

        // ── MORPHING OSD LAYER (Volume, Caps Lock, Num Lock) ───────────────
        OsdLayer {
            id: osdLayerItem
            anchors.top: parent.top
            anchors.topMargin: bar.barTopMargin
            anchors.horizontalCenter: parent.horizontalCenter
            height: bar.capsuleH

            icon: bar.osdIcon
            label: bar.osdLabel
            progress: bar.osdProgress
            opacity: (bar.osdActive && bar.below === "") ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
        }

        // ── EXPANDED DETAILS (Dashboard, Session, Tray, Notification) ───────
        Loader {
            id: detailLoader
            anchors.top: parent.top
            anchors.topMargin: bar.pad
            anchors.horizontalCenter: parent.horizontalCenter
            width: bar.belowSize.width
            height: bar.belowSize.height
            active: bar.expanded && bar.openId !== "notification"

            sourceComponent: {
                switch (bar.openId) {
                case "dashboard": return dashboardComponent
                case "session":   return sessionComponent
                case "tray":      return trayComponent
                default:          return null
                }
            }
        }

        Component {
            id: dashboardComponent
            IslandDashboard {
                onClosed: bar.close()
            }
        }

        Component {
            id: sessionComponent
            SessionPanel {
                onClosed: bar.close()
            }
        }

        Component {
            id: trayComponent
            TrayMenuList {
                menu: bar.trayMenu
                item: bar.trayItem
                onItemTriggered: bar.close()
            }
        }

        Loader {
            id: notificationLoader
            anchors.top: parent.top
            anchors.topMargin: bar.pad
            anchors.horizontalCenter: parent.horizontalCenter
            width: bar.belowSize.width
            height: bar.belowSize.height
            active: bar.notifying
            opacity: bar.notifying ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationMedium } }
            sourceComponent: NotificationLayer {}
        }
    }

    // Notch fillets where the island meets the screen edge. Siblings of the
    // island, not children: it clips, and they sit just outside it.
    NotchFillet {
        z: 2
        x: island.x - width
        y: island.y
        mirrored: true
        opacity: Math.max(0, 1 + bar.notchYOffset / 10)
    }

    NotchFillet {
        z: 2
        x: island.x + island.width
        y: island.y
        opacity: Math.max(0, 1 + bar.notchYOffset / 10)
    }

    // ── RIGHT FLOATING ZONE ──────────────────────────────────────────────────

    Row {
        id: rightZone
        z: 1

        x: (island.x + island.width - width) + (width + Theme.capsuleSpacing) * bar.islandsEmergeProgress
        y: bar.barTopMargin
        spacing: Theme.capsuleSpacing

        opacity: Math.min(1, bar.islandsEmergeProgress * 1.5)
        visible: opacity > 0

        // System Tray Capsule (borderless black pill)
        Rectangle {
            height: bar.capsuleH
            width: trayWidget.implicitWidth + 16
            radius: height / 2
            color: Theme.island
            border.width: 1
            border.color: Theme.hairline
            visible: !trayWidget.empty

            TrayWidget {
                id: trayWidget
                anchors.centerIn: parent
                onMenuRequested: (menu, centerX, item) => {
                    bar.trayItem = item
                    bar.trayMenu = menu
                    bar.openId = "tray"
                }
            }
        }

        // Power Session Action Capsule
        Rectangle {
            height: bar.capsuleH
            width: bar.capsuleH
            radius: height / 2
            color: bar.openId === "session" || powerMouse.containsMouse
                ? Theme.islandSurfaceHover : Theme.island
            border.width: 1
            border.color: bar.openId === "session" || powerMouse.containsMouse
                ? Theme.islandBorder : Theme.hairline

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

            Text {
                anchors.centerIn: parent
                text: "󰐥"
                font.family: Theme.fontMono
                font.pixelSize: 13
                color: Theme.text
                scale: powerMouse.pressed ? 0.88 : 1
                Behavior on scale {
                    NumberAnimation { duration: Theme.durationFast; easing.type: Easing.OutBack }
                }
            }

            MouseArea {
                id: powerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.toggle("session")
            }
        }
    }
}
