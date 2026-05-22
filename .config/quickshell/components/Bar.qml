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
    
    // Extracted hyprland data for this specific monitor/screen
    property var monitorHyprland: barWindow.hyprlandData && barWindow.modelData && barWindow.hyprlandData[barWindow.modelData.name] 
        ? barWindow.hyprlandData[barWindow.modelData.name] 
        : ({ "active_workspace": 0, "active_window": null, "workspaces": [] })

    // exclusiveZone reserves space so other windows don't overlap (30px height)
    exclusiveZone: 30
    implicitHeight: 510 // Keep window height constant to prevent Wayland resize flash
    
    anchors {
        top: true
        left: true
        right: true
    }
    
    // Centered horizontal width, floating effect (margins on the sides)
    margins {
        top: 0
        left: 120
        right: 120
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
    }
    
    // Unified Background shape (morphs dynamically for Dashboard/Calendar)
    Shape {
        id: barBackground
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        
        // Morphing animation variables
        property real dashY: centerIsland.dashboardOpen ? 510 : 30
        property real dashRadius: centerIsland.dashboardOpen ? 12 : 0
        property real dashDipY: centerIsland.dashboardOpen ? 12 : 0
        
        property real calY: rightWidgets.calendarOpen ? 310 : 30
        property real calRadius: rightWidgets.calendarOpen ? 12 : 0
        property real calDipY: rightWidgets.calendarOpen ? 12 : 0
        
        Behavior on dashY { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
        Behavior on dashRadius { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
        Behavior on dashDipY { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
        
        Behavior on calY { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
        Behavior on calRadius { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
        Behavior on calDipY { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
        
        // Horizontals for bulges
        readonly property real dashX2: barWindow.width / 2 + 180
        readonly property real dashX1: barWindow.width / 2 - 180
        
        readonly property real clockCenter: rightWidgets.x + rightWidgets.clockCenterX - 10
        readonly property real calX2: Math.min(barWindow.width - 16, clockCenter + 130)
        readonly property real calX1: calX2 - 260
        
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
            
            // Calendar protrusion (flattened to y=30 when closed)
            PathLine { x: barBackground.calX2 + barBackground.calRadius; y: 30 }
            PathArc {
                x: barBackground.calX2
                y: 30 + barBackground.calDipY
                radiusX: barBackground.calRadius; radiusY: barBackground.calRadius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: barBackground.calX2; y: barBackground.calY - barBackground.calRadius }
            PathArc {
                x: barBackground.calX2 - barBackground.calRadius
                y: barBackground.calY
                radiusX: barBackground.calRadius; radiusY: barBackground.calRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: barBackground.calX1 + barBackground.calRadius; y: barBackground.calY }
            PathArc {
                x: barBackground.calX1
                y: barBackground.calY - barBackground.calRadius
                radiusX: barBackground.calRadius; radiusY: barBackground.calRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: barBackground.calX1; y: 30 + barBackground.calDipY }
            PathArc {
                x: barBackground.calX1 - barBackground.calRadius
                y: 30
                radiusX: barBackground.calRadius; radiusY: barBackground.calRadius
                direction: PathArc.Counterclockwise
            }
            
            // Dashboard protrusion (flattened to y=30 when closed)
            PathLine { x: barBackground.dashX2 + barBackground.dashRadius; y: 30 }
            PathArc {
                x: barBackground.dashX2
                y: 30 + barBackground.dashDipY
                radiusX: barBackground.dashRadius; radiusY: barBackground.dashRadius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: barBackground.dashX2; y: barBackground.dashY - barBackground.dashRadius }
            PathArc {
                x: barBackground.dashX2 - barBackground.dashRadius
                y: barBackground.dashY
                radiusX: barBackground.dashRadius; radiusY: barBackground.dashRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: barBackground.dashX1 + barBackground.dashRadius; y: barBackground.dashY }
            PathArc {
                x: barBackground.dashX1
                y: barBackground.dashY - barBackground.dashRadius
                radiusX: barBackground.dashRadius; radiusY: barBackground.dashRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: barBackground.dashX1; y: 30 + barBackground.dashDipY }
            PathArc {
                x: barBackground.dashX1 - barBackground.dashRadius
                y: 30
                radiusX: barBackground.dashRadius; radiusY: barBackground.dashRadius
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
    }
    
    // Auto-close on mouse off logic
    property bool isDashHovered: (centerIsland && centerIsland.hovered) || (dashboardContainer && dashboardContainer.hovered)
    property bool isCalHovered: (rightWidgets && rightWidgets.clockHovered) || (calendarContainer && calendarContainer.hovered)

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
    
    // Mutual exclusion logic for dropdowns
    Connections {
        target: centerIsland
        function onDashboardOpenChanged() {
            if (centerIsland.dashboardOpen) {
                rightWidgets.calendarOpen = false;
            } else {
                dashCloseTimer.stop();
            }
        }
    }
    
    Connections {
        target: rightWidgets
        function onCalendarOpenChanged() {
            if (rightWidgets.calendarOpen) {
                centerIsland.dashboardOpen = false;
            } else {
                calCloseTimer.stop();
            }
        }
    }
    
    // Emerging Dashboard
    Dashboard {
        id: dashboardContainer
        parentWindow: barWindow
        spotify: barWindow.spotifyData
        sys: barWindow.sysData
        
        width: 360
        height: 480
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

    Component.onCompleted: {
        console.log("Bar loaded for screen name: " + (modelData ? modelData.name : "null"));
    }
}
