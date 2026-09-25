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

PanelWindow {
    id: bar

    property var modelData
    screen: modelData

    // ── STATE ────────────────────────────────────────────────────────────────

    // "dashboard", "session", "tray" or "".
    property string openId: ""
    readonly property bool expanded: bar.openId !== ""
    readonly property bool dashboardOpen: bar.openId === "dashboard"

    property var trayMenu: null
    property var trayItem: null

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

    readonly property string below: bar.expanded ? bar.openId
        : bar.notifying ? "notification" : ""

    readonly property size belowSize: {
        switch (bar.below) {
        case "notification":
            return notificationLoader.item
                ? Qt.size(notificationLoader.item.wantWidth, notificationLoader.item.wantHeight)
                : Qt.size(430, 56)
        case "tray":
            return Qt.size(280, Math.min(460, trayLoader.item?.contentHeight ?? 60))
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

    // ── ANIMATION STATES (STARTUP, UNLOCK, LOCK & PANELS) ────────────────────

    property real notchYOffset: -bar.capsuleH - bar.barTopMargin - 20
    property real islandsEmergeProgress: 0.0
    property bool isDemorphed: false

    ParallelAnimation {
        id: startupAnimation

        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation {
                target: bar
                property: "notchYOffset"
                from: -bar.capsuleH - bar.barTopMargin - 20
                to: 0
                duration: 480
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }

        SequentialAnimation {
            PauseAnimation { duration: 340 }
            NumberAnimation {
                target: bar
                property: "islandsEmergeProgress"
                from: 0.0
                to: 1.0
                duration: 620
                easing.type: Easing.OutCubic
            }
        }
    }

    // Side islands retraction (into notch) - relaxed and smooth
    NumberAnimation {
        id: sideIslandsRetractAnimation
        target: bar
        property: "islandsEmergeProgress"
        to: 0.0
        duration: 360
        easing.type: Easing.InOutCubic
    }

    // Side islands emergence (out from notch) - fluid glide
    NumberAnimation {
        id: sideIslandsEmergeAnimation
        target: bar
        property: "islandsEmergeProgress"
        from: 0.0
        to: 1.0
        duration: 620
        easing.type: Easing.OutCubic
    }

    // Timer ensuring side islands pop out AFTER the island completes its morph/demorph back to rest
    readonly property Timer postMorphEmergeTimer: Timer {
        interval: Theme.durationMorph + 60
        onTriggered: {
            if (bar.below === "" && !LockService.locked && !bar.isDemorphed) {
                sideIslandsEmergeAnimation.restart()
            }
        }
    }

    onBelowChanged: {
        if (bar.below !== "") {
            postMorphEmergeTimer.stop()
            sideIslandsRetractAnimation.restart()
        } else {
            postMorphEmergeTimer.restart()
        }
    }

    // LOCK: 1. Retract side islands into notch -> 2. Demorph notch down to compact 72px
    SequentialAnimation {
        id: lockSequence

        NumberAnimation {
            target: bar
            property: "islandsEmergeProgress"
            to: 0.0
            duration: 300
            easing.type: Easing.InOutCubic
        }

        ScriptAction {
            script: bar.isDemorphed = true
        }
    }

    // UNLOCK: 1. Morph notch to full width -> 2. Pop out side islands after morph finishes
    SequentialAnimation {
        id: unlockSequence

        ScriptAction {
            script: {
                bar.notchYOffset = 0
                bar.isDemorphed = false
            }
        }

        // Wait for island morph animation to finish before popping out side islands
        PauseAnimation {
            duration: Theme.durationMorph + 60
        }

        NumberAnimation {
            target: bar
            property: "islandsEmergeProgress"
            from: 0.0
            to: 1.0
            duration: 620
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: {
        if (!LockService.locked) {
            startupAnimation.start()
        } else {
            bar.notchYOffset = 0
            bar.isDemorphed = true
            bar.islandsEmergeProgress = 0.0
        }
    }

    Connections {
        target: LockService

        function onPrepareLock(): void {
            bar.close()
            lockSequence.restart()
        }

        function onLockedChanged(): void {
            if (LockService.locked) {
                bar.close()
                bar.isDemorphed = true
                bar.islandsEmergeProgress = 0.0
            }
        }

        function onUnlocked(): void {
            unlockSequence.restart()
        }
    }

    // ── SURFACE ──────────────────────────────────────────────────────────────

    anchors {
        top: true
        left: true
        right: true
    }

    readonly property int capsuleH: Theme.capsuleHeight
    readonly property int barTopMargin: 4
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

    SystemClock {
        id: clockTime
        precision: SystemClock.Minutes
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
            border.width: 0

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
                : bar.isDemorphed
                    ? 72
                    : restRow.implicitWidth + 28

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

        // Notch fillets seamlessly attaching to screen edge
        NotchFillet {
            anchors.right: island.left
            anchors.top: parent.top
            mirrored: true
            opacity: Math.max(0, 1 + bar.notchYOffset / 10)
        }

        NotchFillet {
            anchors.left: island.right
            anchors.top: parent.top
            opacity: Math.max(0, 1 + bar.notchYOffset / 10)
        }

        focus: bar.expanded
        Keys.onEscapePressed: bar.close()

        // Rest row content
        Item {
            id: restRowContainer
            anchors.top: parent.top
            anchors.topMargin: bar.barTopMargin
            anchors.horizontalCenter: parent.horizontalCenter
            width: restRow.implicitWidth
            height: bar.capsuleH

            opacity: (bar.below !== "" || bar.osdActive || bar.isDemorphed) ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

            Row {
                id: restRow
                anchors.centerIn: parent
                spacing: 10

                // 1. Media Album Art Thumbnail
                Item {
                    id: mediaThumb
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: Theme.islandSurfaceHover
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: MediaService.artUrl
                            visible: source !== "" && status === Image.Ready
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !MediaService.available || MediaService.artUrl === ""
                            text: "󰝚"
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            color: Theme.accent
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
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
                }

                // 2. Song Name (Title and Artist)
                Item {
                    id: songItem
                    anchors.verticalCenter: parent.verticalCenter
                    visible: MediaService.available && (MediaService.title !== "")
                    width: visible ? Math.min(280, songText.implicitWidth) : 0
                    height: bar.capsuleH
                    clip: true

                    Text {
                        id: songText
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        text: MediaService.artist !== ""
                            ? `${MediaService.title}  •  ${MediaService.artist}`
                            : MediaService.title
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.text
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                MediaService.toggle()
                            else
                                bar.toggle("dashboard")
                        }
                    }
                }

                // 3. Audio Visualizer Spectrum (Smoothly disappears after ~5m of no Spotify)
                Item {
                    id: visualizerContainer
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool shouldShow: MediaService.visualizerActive

                    width: shouldShow ? islandVisualizer.implicitWidth : 0
                    height: 14
                    opacity: shouldShow ? 1 : 0
                    visible: opacity > 0 || width > 0
                    clip: true

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.durationMorph
                            easing.type: Theme.easing
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durationMorph
                            easing.type: Theme.easing
                        }
                    }

                    Spectrum {
                        id: islandVisualizer
                        anchors.centerIn: parent
                        barWidth: 2.5
                        barSpacing: 1.5
                        minimum: 2
                        height: 14
                        active: MediaService.playing
                        barColor: Theme.accent
                        visible: parent.visible
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                MediaService.toggle()
                            else
                                bar.toggle("dashboard")
                        }
                    }
                }

                // 4. Clock Time
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: clockText.implicitWidth
                    height: bar.capsuleH

                    Text {
                        id: clockText
                        anchors.centerIn: parent
                        text: Qt.formatDateTime(clockTime.date, SettingsService.clockFormat || "HH:mm")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall + 1
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: Theme.text
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                MediaService.toggle()
                            else
                                bar.toggle("dashboard")
                        }
                    }
                }

                // Divider
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "|"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Light
                    color: Theme.textMuted
                    opacity: 0.25
                }

                // 4. Clock Date
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: dateText.implicitWidth
                    height: bar.capsuleH

                    Text {
                        id: dateText
                        anchors.centerIn: parent
                        text: Qt.formatDateTime(clockTime.date, "dddd, d MMM")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall - 1
                        font.weight: Font.Medium
                        color: Theme.textMuted
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                MediaService.toggle()
                            else
                                bar.toggle("dashboard")
                        }
                    }
                }
            }
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
            border.width: 0
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
            color: bar.openId === "session" ? Theme.islandSurfaceHover : Theme.island
            border.width: 0

            Text {
                anchors.centerIn: parent
                text: "󰐥"
                font.family: Theme.fontMono
                font.pixelSize: 13
                color: Theme.text
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.toggle("session")
            }
        }
    }
}
