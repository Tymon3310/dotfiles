import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell

PanelWindow {
    id: barWindow
    
    property var modelData
    screen: modelData
    
    // Properties passed from shell.qml
    property var sysData: null
    property var spotifyData: null
    property var hyprlandData: null
    property var windowTitleBlocklist: []
    property var notifServer: null
    property var notifHistory: null
    
    // Extracted hyprland data for this specific monitor/screen
    property var monitorHyprland: barWindow.hyprlandData && barWindow.modelData && barWindow.hyprlandData[barWindow.modelData.name] 
        ? barWindow.hyprlandData[barWindow.modelData.name] 
        : ({ "active_workspace": 0, "active_window": null, "workspaces": [], "focused": false })

    // exclusiveZone reserves space so other windows don't overlap (30px height)
    exclusiveZone: 30
    implicitHeight: 850 // Keep window height constant to prevent Wayland resize flash
    
    anchors {
        top: true
        left: true
        right: true
    }
    
    // Centered horizontal width, floating effect (margins on the sides)
    margins {
        top: 0
        left: 80
        right: 80
    }
    
    color: "transparent" // Ensure window background is transparent
    
    // Mask window inputs dynamically so transparent areas are click-through
    mask: Region {
        Region { item: barContainer }
        Region {
            item: centerIsland.dashboardOpen ? dashboardContainer : null
        }
        Region {
            item: rightWidgets.calendarOpen ? calendarContainer : null
        }
        Region {
            item: rightWidgets.trayMenuOpen ? trayMenuContainer : null
        }
        Region {
            item: rightWidgets.notifPanelOpen ? notifPanelContainer : null
        }
    }
    
    // Unified Background shape (morphs dynamically for Dashboard/Calendar/TrayMenu)
    Shape {
        id: barBackground
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        
        // Morphing animation variables
        property real targetDashHeight: dashboardContainer ? (dashboardContainer.expandedMode === "none" ? 432 : (dashboardContainer.expandedMode === "weather" ? 582 : 702)) : 432
        property real dashY: centerIsland.dashboardOpen ? (30 + targetDashHeight) : 30
        property real dashRadius: centerIsland.dashboardOpen ? 12 : 0
        property real dashDipY: centerIsland.dashboardOpen ? 12 : 0
        
        property real calY: rightWidgets.calendarOpen ? 310 : 30
        property real calRadius: rightWidgets.calendarOpen ? 12 : 0
        property real calDipY: rightWidgets.calendarOpen ? 12 : 0

        // Custom Tray Menu protrusion variables
        property real targetTrayHeight: trayMenuContainer ? Math.min(550, trayMenuContainer.contentHeight) : 0
        property real trayY: rightWidgets.trayMenuOpen ? (30 + targetTrayHeight) : 30
        property real trayRadius: rightWidgets.trayMenuOpen ? 12 : 0
        property real trayDipY: rightWidgets.trayMenuOpen ? 12 : 0

        // Notification panel protrusion variables
        property real targetNotifHeight: notifPanelContainer ? notifPanelContainer.implicitHeight : 480
        property real notifY: rightWidgets.notifPanelOpen ? (30 + Math.min(targetNotifHeight, 480)) : 30
        property real notifRadius: rightWidgets.notifPanelOpen ? 12 : 0
        property real notifDipY: rightWidgets.notifPanelOpen ? 12 : 0
        
        Behavior on dashY { NumberAnimation { duration: 300; easing.type: centerIsland.dashboardOpen ? Easing.OutBack : Easing.OutQuad } }
        Behavior on dashRadius { NumberAnimation { duration: 300; easing.type: centerIsland.dashboardOpen ? Easing.OutBack : Easing.OutQuad } }
        Behavior on dashDipY { NumberAnimation { duration: 300; easing.type: centerIsland.dashboardOpen ? Easing.OutBack : Easing.OutQuad } }
        
        Behavior on calY { NumberAnimation { duration: 300; easing.type: rightWidgets.calendarOpen ? Easing.OutBack : Easing.OutQuad } }
        Behavior on calRadius { NumberAnimation { duration: 300; easing.type: rightWidgets.calendarOpen ? Easing.OutBack : Easing.OutQuad } }
        Behavior on calDipY { NumberAnimation { duration: 300; easing.type: rightWidgets.calendarOpen ? Easing.OutBack : Easing.OutQuad } }
        
        Behavior on trayY { NumberAnimation { duration: 300; easing.type: rightWidgets.trayMenuOpen ? Easing.OutBack : Easing.OutQuad } }
        Behavior on trayRadius { NumberAnimation { duration: 300; easing.type: rightWidgets.trayMenuOpen ? Easing.OutBack : Easing.OutQuad } }
        Behavior on trayDipY { NumberAnimation { duration: 300; easing.type: rightWidgets.trayMenuOpen ? Easing.OutBack : Easing.OutQuad } }

        Behavior on notifY { NumberAnimation { duration: 300; easing.type: rightWidgets.notifPanelOpen ? Easing.OutBack : Easing.OutQuad } }
        Behavior on notifRadius { NumberAnimation { duration: 300; easing.type: rightWidgets.notifPanelOpen ? Easing.OutBack : Easing.OutQuad } }
        Behavior on notifDipY { NumberAnimation { duration: 300; easing.type: rightWidgets.notifPanelOpen ? Easing.OutBack : Easing.OutQuad } }
        
        // Clean path-bound variables that instantly drop to 0 when their respective widget is closed,
        // preventing overshoot backtracking line flashes during exit animations.
        readonly property bool calendarActive: rightWidgets.calendarOpen || Math.abs(calY - 30) > 0.01
        readonly property bool trayActive: rightWidgets.trayMenuOpen || Math.abs(trayY - 30) > 0.01
        readonly property bool dashboardActive: centerIsland.dashboardOpen || Math.abs(dashY - 30) > 0.01
        readonly property bool notifActive: rightWidgets.notifPanelOpen || Math.abs(notifY - 30) > 0.01

        readonly property real pathCalRadius: Math.max(0, calRadius)
        readonly property real pathCalDipY: Math.max(0, calDipY)

        readonly property real pathTrayRadius: Math.max(0, trayRadius)
        readonly property real pathTrayDipY: Math.max(0, trayDipY)

        readonly property real pathDashRadius: Math.max(0, dashRadius)
        readonly property real pathDashDipY: Math.max(0, dashDipY)

        readonly property real pathNotifRadius: Math.max(0, notifRadius)
        readonly property real pathNotifDipY: Math.max(0, notifDipY)
        
        // Horizontals for bulges (Strictly ordered from right to left to prevent overlaps and backtracking)
        readonly property real clockCenter: rightWidgets.x + rightWidgets.clockCenterX - 10

        // Notif panel: anchored to the right edge (bell icon area), width 300
        readonly property real notifX2: notifActive ? barWindow.width - 24 : barWindow.width - 12
        readonly property real notifX1: notifActive ? notifX2 - 300 : barWindow.width - 12

        readonly property real calX2: calendarActive ? Math.min(barWindow.width - 40, clockCenter + 130) : notifX1 - pathNotifRadius
        readonly property real calX1: calendarActive ? calX2 - 260 : notifX1 - pathNotifRadius
        
        readonly property real activeTrayCenterX: trayActive && rightWidgets.trayMenuCenterX > 0
            ? rightWidgets.trayMenuCenterX
            : (barWindow.width - 250)
        readonly property real trayX2: trayActive ? trayX1 + 200 : calX1 - pathCalRadius
        readonly property real trayX1: trayActive ? Math.max(12, Math.min(barWindow.width - 212, activeTrayCenterX - 100)) : calX1 - pathCalRadius
        
        readonly property real dashX2: dashboardActive ? barWindow.width / 2 + 180 : trayX1 - pathTrayRadius
        readonly property real dashX1: dashboardActive ? dashX2 - 360 : trayX1 - pathTrayRadius
        
        ShapePath {
            strokeColor: "#0070D8"
            strokeWidth: 1
            fillColor: "#E6000000"
            
            startX: 0
            startY: -10
            
            PathLine { x: barWindow.width; y: -10 }
            PathLine { x: barWindow.width; y: 30 - 12 }
            PathArc {
                x: barWindow.width - 12
                y: 30
                radiusX: 12; radiusY: 12
                direction: PathArc.Clockwise
            }

            // Notification panel protrusion (flattened to y=30 when closed)
            PathLine { x: barBackground.notifX2 + barBackground.pathNotifRadius; y: 30 }
            PathArc {
                x: barBackground.notifX2
                y: 30 + barBackground.pathNotifDipY
                radiusX: barBackground.pathNotifRadius; radiusY: barBackground.pathNotifRadius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: barBackground.notifX2; y: Math.max(30, barBackground.notifY - barBackground.pathNotifRadius) }
            PathArc {
                x: barBackground.notifX2 - barBackground.pathNotifRadius
                y: Math.max(30, barBackground.notifY)
                radiusX: barBackground.pathNotifRadius; radiusY: barBackground.pathNotifRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: barBackground.notifX1 + barBackground.pathNotifRadius; y: Math.max(30, barBackground.notifY) }
            PathArc {
                x: barBackground.notifX1
                y: Math.max(30, barBackground.notifY - barBackground.pathNotifRadius)
                radiusX: barBackground.pathNotifRadius; radiusY: barBackground.pathNotifRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: barBackground.notifX1; y: 30 + barBackground.pathNotifDipY }
            PathArc {
                x: barBackground.notifX1 - barBackground.pathNotifRadius
                y: 30
                radiusX: barBackground.pathNotifRadius; radiusY: barBackground.pathNotifRadius
                direction: PathArc.Counterclockwise
            }

            // Calendar protrusion (flattened to y=30 when closed)
            PathLine { x: barBackground.calX2 + barBackground.pathCalRadius; y: 30 }
            PathArc {
                x: barBackground.calX2
                y: 30 + barBackground.pathCalDipY
                radiusX: barBackground.pathCalRadius; radiusY: barBackground.pathCalRadius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: barBackground.calX2; y: Math.max(30, barBackground.calY - barBackground.pathCalRadius) }
            PathArc {
                x: barBackground.calX2 - barBackground.pathCalRadius
                y: Math.max(30, barBackground.calY)
                radiusX: barBackground.pathCalRadius; radiusY: barBackground.pathCalRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: barBackground.calX1 + barBackground.pathCalRadius; y: Math.max(30, barBackground.calY) }
            PathArc {
                x: barBackground.calX1
                y: Math.max(30, barBackground.calY - barBackground.pathCalRadius)
                radiusX: barBackground.pathCalRadius; radiusY: barBackground.pathCalRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: barBackground.calX1; y: 30 + barBackground.pathCalDipY }
            PathArc {
                x: barBackground.calX1 - barBackground.pathCalRadius
                y: 30
                radiusX: barBackground.pathCalRadius; radiusY: barBackground.pathCalRadius
                direction: PathArc.Counterclockwise
            }
            
            // Tray Menu protrusion (flattened to y=30 when closed)
            PathLine { x: barBackground.trayX2 + barBackground.pathTrayRadius; y: 30 }
            PathArc {
                x: barBackground.trayX2
                y: 30 + barBackground.pathTrayDipY
                radiusX: barBackground.pathTrayRadius; radiusY: barBackground.pathTrayRadius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: barBackground.trayX2; y: Math.max(30, barBackground.trayY - barBackground.pathTrayRadius) }
            PathArc {
                x: barBackground.trayX2 - barBackground.pathTrayRadius
                y: Math.max(30, barBackground.trayY)
                radiusX: barBackground.pathTrayRadius; radiusY: barBackground.pathTrayRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: barBackground.trayX1 + barBackground.pathTrayRadius; y: Math.max(30, barBackground.trayY) }
            PathArc {
                x: barBackground.trayX1
                y: Math.max(30, barBackground.trayY - barBackground.pathTrayRadius)
                radiusX: barBackground.pathTrayRadius; radiusY: barBackground.pathTrayRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: barBackground.trayX1; y: 30 + barBackground.pathTrayDipY }
            PathArc {
                x: barBackground.trayX1 - barBackground.pathTrayRadius
                y: 30
                radiusX: barBackground.pathTrayRadius; radiusY: barBackground.pathTrayRadius
                direction: PathArc.Counterclockwise
            }
            
            // Dashboard protrusion (flattened to y=30 when closed)
            PathLine { x: barBackground.dashX2 + barBackground.pathDashRadius; y: 30 }
            PathArc {
                x: barBackground.dashX2
                y: 30 + barBackground.pathDashDipY
                radiusX: barBackground.pathDashRadius; radiusY: barBackground.pathDashRadius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: barBackground.dashX2; y: Math.max(30, barBackground.dashY - barBackground.pathDashRadius) }
            PathArc {
                x: barBackground.dashX2 - barBackground.pathDashRadius
                y: Math.max(30, barBackground.dashY)
                radiusX: barBackground.pathDashRadius; radiusY: barBackground.pathDashRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: barBackground.dashX1 + barBackground.pathDashRadius; y: Math.max(30, barBackground.dashY) }
            PathArc {
                x: barBackground.dashX1
                y: Math.max(30, barBackground.dashY - barBackground.pathDashRadius)
                radiusX: barBackground.pathDashRadius; radiusY: barBackground.pathDashRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: barBackground.dashX1; y: 30 + barBackground.pathDashDipY }
            PathArc {
                x: barBackground.dashX1 - barBackground.pathDashRadius
                y: 30
                radiusX: barBackground.pathDashRadius; radiusY: barBackground.pathDashRadius
                direction: PathArc.Counterclockwise
            }
            
            PathLine { x: 12; y: 30 }
            PathArc {
                x: 0
                y: 30 - 12
                radiusX: 12; radiusY: 12
                direction: PathArc.Clockwise
            }
            PathLine { x: 0; y: -10 }
        }
    }
    
    // Top container of fixed height 30px to anchor the main bar components
    Item {
        id: barContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 30
    }
    
    // LEFT ALIGNED ITEMS: Workspaces & Active Window Title
    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: barContainer.verticalCenter
        spacing: 12
        
        WorkspaceSwitcher {
            id: switcher
            monitorHyprland: barWindow.monitorHyprland
        }
        
        Rectangle {
            width: 1
            height: 12
            color: "#33FFFFFF"
            visible: activeWin.visible
        }
        
        ActiveWindow {
            id: activeWin
            activeWindowData: barWindow.monitorHyprland.active_window
            blocklist: barWindow.windowTitleBlocklist
        }
    }
    
    // CENTER ALIGNED ITEMS: Spotify Central Island
    CentralIsland {
        id: centerIsland
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: barContainer.verticalCenter
        parentWindow: barWindow
        spotify: barWindow.spotifyData
        sys: barWindow.sysData
    }
    
    // RIGHT ALIGNED ITEMS: Consolidated Widgets
    RightWidgets {
        id: rightWidgets
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: barContainer.verticalCenter
        parentWindow: barWindow
        sysData: barWindow.sysData
        notifServer: barWindow.notifServer
        notifHistory: barWindow.notifHistory
    }
    
    // Auto-close on mouse off logic
    property bool isDashHovered: (centerIsland && centerIsland.hovered) || (dashboardContainer && dashboardContainer.hovered)
    property bool isCalHovered: (rightWidgets && rightWidgets.clockHovered) || (calendarContainer && calendarContainer.hovered)
    property bool isTrayMenuHovered: (rightWidgets && rightWidgets.trayHovered) || (trayMenuContainer && trayMenuContainer.hovered)
    property bool isNotifHovered: (rightWidgets && rightWidgets.notifHovered) || (notifPanelContainer && notifPanelContainer.hovered)

    Timer {
        id: dashCloseTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (centerIsland) {
                centerIsland.dashboardOpen = false;
            }
        }
    }

    Timer {
        id: calCloseTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (rightWidgets) {
                rightWidgets.calendarOpen = false;
            }
        }
    }

    Timer {
        id: trayMenuCloseTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (rightWidgets) {
                rightWidgets.trayMenuOpen = false;
            }
        }
    }

    onIsDashHoveredChanged: {
        if (!isDashHovered && centerIsland && centerIsland.dashboardOpen) {
            dashCloseTimer.start();
        } else {
            dashCloseTimer.stop();
        }
    }

    onIsCalHoveredChanged: {
        if (!isCalHovered && rightWidgets && rightWidgets.calendarOpen) {
            calCloseTimer.start();
        } else {
            calCloseTimer.stop();
        }
    }

    onIsTrayMenuHoveredChanged: {
        if (!isTrayMenuHovered && rightWidgets && rightWidgets.trayMenuOpen) {
            trayMenuCloseTimer.start();
        } else {
            trayMenuCloseTimer.stop();
        }
    }

    Timer {
        id: notifCloseTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (rightWidgets) rightWidgets.notifPanelOpen = false;
        }
    }

    onIsNotifHoveredChanged: {
        if (!isNotifHovered && rightWidgets && rightWidgets.notifPanelOpen) {
            notifCloseTimer.start();
        } else {
            notifCloseTimer.stop();
        }
    }
    
    // Mutual exclusion logic for dropdowns
    Connections {
        target: centerIsland
        function onDashboardOpenChanged() {
            if (centerIsland.dashboardOpen) {
                rightWidgets.calendarOpen = false;
                rightWidgets.trayMenuOpen = false;
                rightWidgets.notifPanelOpen = false;
            } else {
                dashCloseTimer.stop();
                dashboardContainer.expandedMode = "none";
            }
        }
    }

    Connections {
        target: rightWidgets
        function onCalendarOpenChanged() {
            if (rightWidgets.calendarOpen) {
                centerIsland.dashboardOpen = false;
                rightWidgets.trayMenuOpen = false;
                rightWidgets.notifPanelOpen = false;
            } else {
                calCloseTimer.stop();
            }
        }
    }

    Connections {
        target: rightWidgets
        function onTrayMenuOpenChanged() {
            if (rightWidgets.trayMenuOpen) {
                centerIsland.dashboardOpen = false;
                rightWidgets.calendarOpen = false;
                rightWidgets.notifPanelOpen = false;
            } else {
                trayMenuCloseTimer.stop();
            }
        }
    }

    Connections {
        target: rightWidgets
        function onNotifPanelOpenChanged() {
            if (rightWidgets.notifPanelOpen) {
                centerIsland.dashboardOpen = false;
                rightWidgets.calendarOpen = false;
                rightWidgets.trayMenuOpen = false;
            } else {
                notifCloseTimer.stop();
            }
        }
    }
    
    // Emerging Dashboard
    Dashboard {
        id: dashboardContainer
        parentWindow: barWindow
        spotify: barWindow.spotifyData
        sys: barWindow.sysData
        dashboardOpen: centerIsland.dashboardOpen
        
        width: 360
        height: Math.max(0, barBackground.dashY - 30)
        clip: true
        anchors.top: parent.top
        anchors.topMargin: 30
        anchors.horizontalCenter: parent.horizontalCenter
        
        opacity: centerIsland.dashboardOpen ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }
    
    // Emerging Calendar
    CalendarDropdown {
        id: calendarContainer
        parentWindow: barWindow
        selectedDate: rightWidgets.selectedDate
        
        width: 260
        height: 280
        anchors.top: parent.top
        anchors.topMargin: 30
        anchors.left: parent.left
        anchors.leftMargin: barBackground.calX1
        
        opacity: rightWidgets.calendarOpen ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        
        onSelectedDateChanged: {
            rightWidgets.selectedDate = selectedDate;
        }
    }

    // Emerging Tray Menu
    TrayMenu {
        id: trayMenuContainer
        parentWindow: barWindow
        activeMenuOpener: rightWidgets.activeMenuOpener

        width: 200
        height: Math.max(0, barBackground.trayY - 30)
        clip: true
        anchors.top: parent.top
        anchors.topMargin: 30
        anchors.left: parent.left
        anchors.leftMargin: barBackground.trayX1

        opacity: rightWidgets.trayMenuOpen ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 250 } }

        onItemTriggered: {
            rightWidgets.trayMenuOpen = false;
        }
    }

    // Emerging Notification Panel
    NotificationPanel {
        id: notifPanelContainer
        parentWindow: barWindow
        notifServer: barWindow.notifServer
        notifHistory: barWindow.notifHistory
        dnd: rightWidgets.notifDnd

        width: 300
        height: Math.max(0, barBackground.notifY - 30)
        clip: true
        anchors.top: parent.top
        anchors.topMargin: 30
        anchors.left: parent.left
        anchors.leftMargin: barBackground.notifX1

        opacity: rightWidgets.notifPanelOpen ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 250 } }

        // Sync DND state back to RightWidgets
        onDndChanged: rightWidgets.notifDnd = dnd
    }

    // Transient Notification Popups (Toast Notifications)
    ToastContainer {
        screen: barWindow.screen
        notifServer: barWindow.notifServer
        notifDnd: rightWidgets.notifDnd
        panelOpen: centerIsland.dashboardOpen || rightWidgets.calendarOpen || rightWidgets.trayMenuOpen || rightWidgets.notifPanelOpen
    }

    Component.onCompleted: {
        console.log("Bar loaded for screen name: " + (modelData ? modelData.name : "null"));
    }
}
