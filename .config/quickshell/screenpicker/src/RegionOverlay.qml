import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property var targetScreen
    property real screenX: targetScreen.x
    property real screenY: targetScreen.y

    signal regionSelected(string monitorName, real x, real y, real w, real h)
    signal cancelled()

    screen: targetScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: "transparent"

    property bool isSelecting: false
    property real startX: 0
    property real startY: 0
    property real currentX: 0
    property real currentY: 0

    // Live Screen Freeze
    ScreencopyView {
        anchors.fill: parent
        captureSource: root.targetScreen
        z: -1
    }
    
    // Dimmer
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.4
    }

    // Selection Box
    Rectangle {
        visible: root.isSelecting
        x: Math.min(root.startX, root.currentX)
        y: Math.min(root.startY, root.currentY)
        width: Math.abs(root.currentX - root.startX)
        height: Math.abs(root.currentY - root.startY)
        color: "transparent"
        border.color: "#ffffff"
        border.width: 2
        
        // Clearer inside
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            color: "transparent"
            border.color: "black"
            border.width: 1
            opacity: 0.5
        }
        
        // Show the screen content clearly inside (cutout effect)
        // We use an item that clips the screencopy view
        Item {
            anchors.fill: parent
            clip: true
            
            ScreencopyView {
                // Shift the view so the correct part shows up
                x: -parent.parent.x
                y: -parent.parent.y
                width: root.width
                height: root.height
                captureSource: root.targetScreen
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        
        onPressed: (mouse) => {
            root.isSelecting = true
            root.startX = mouse.x
            root.startY = mouse.y
            root.currentX = mouse.x
            root.currentY = mouse.y
        }
        
        onPositionChanged: (mouse) => {
            if (root.isSelecting) {
                root.currentX = mouse.x
                root.currentY = mouse.y
            }
        }
        
        onReleased: {
            if (root.isSelecting) {
                root.isSelecting = false
                const finalX = Math.min(root.startX, root.currentX)
                const finalY = Math.min(root.startY, root.currentY)
                const finalW = Math.abs(root.currentX - root.startX)
                const finalH = Math.abs(root.currentY - root.startY)
                
                if (finalW > 10 && finalH > 10) {
                    root.regionSelected(root.targetScreen.name, finalX, finalY, finalW, finalH)
                }
            }
        }
    }

    // Cancel on Esc
    Item {
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.cancelled()
                event.accepted = true
            }
        }
    }
}
