import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: root

    signal requestRegionSelect()
    signal screenSelected(string name)
    signal windowSelected(string address)
    signal cancelled()
    
    required property var snapshotService

    // Dynamic size: 90% of primary screen width, 80% height
    width: (Quickshell.screens[0] ? Quickshell.screens[0].width : 1920) * 0.9
    height: (Quickshell.screens[0] ? Quickshell.screens[0].height : 1080) * 0.8
    
    // Frameless window
    flags: Qt.FramelessWindowHint | Qt.Dialog
    color: "transparent"

    // Main Container
    Rectangle {
        anchors.fill: parent
        color: "#1a1a1a" // Neutral Dark Base
        radius: 12
        border.color: "#333333" // Surface Border
        border.width: 1
        clip: true
        
        // Header / Tab Bar
        Rectangle {
            id: header
            width: parent.width
            height: 50
            color: "#121212" // Darker Header
            
            // Drag Area (Background of header)
            MouseArea {
                anchors.fill: parent
                property point clickPos
                onPressed: (mouse) => { clickPos = Qt.point(mouse.x, mouse.y) }
                onPositionChanged: (mouse) => {
                    if (pressed) {
                        root.x += mouse.x - clickPos.x
                        root.y += mouse.y - clickPos.y
                    }
                }
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10


                TabBarButton {
                    text: "Screens"
                    icon: "monitor"
                    active: stackLayout.currentIndex === 0
                    onClicked: stackLayout.currentIndex = 0
                    Layout.fillHeight: true
                    Layout.preferredWidth: 120
                }

                TabBarButton {
                    text: "Windows"
                    icon: "window-maximize"
                    active: stackLayout.currentIndex === 1
                    onClicked: stackLayout.currentIndex = 1
                    Layout.fillHeight: true
                    Layout.preferredWidth: 120
                }

                TabBarButton {
                    text: "Region"
                    icon: "crop"
                    active: stackLayout.currentIndex === 2
                    onClicked: stackLayout.currentIndex = 2
                    Layout.fillHeight: true
                    Layout.preferredWidth: 120
                }
                
                Item { Layout.fillWidth: true }
                
                // Close button
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: closeArea.containsMouse ? "#cc3333" : "#333333"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#ffffff"
                    }
                    
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.cancelled()
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        // Content Area
        StackLayout {
            id: stackLayout
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            currentIndex: 0

            // Tab 1: Screens
            ScreenTab {
                onScreenSelected: (name) => root.screenSelected(name)
            }

            // Tab 2: Windows
            WindowTab {
                active: stackLayout.currentIndex === 1
                snapshotService: root.snapshotService
                onWindowSelected: (addr) => root.windowSelected(addr)
            }

            // Tab 3: Region Info
            RegionTab {
                onRequestSelect: root.requestRegionSelect()
            }
        }
    }
    
    // Global key handler for Esc
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
