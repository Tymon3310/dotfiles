import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
    id: root

    signal requestRegionSelect()
    signal screenSelected(string name)
    signal windowSelected(string address)
    signal cancelled()

    screen: Quickshell.screens[0]
    
    // Fixed size
    width: 800
    height: 600
    
    // Center using margins
    anchors {
        left: true
        top: true
    }
    
    // Calculate center position
    property real centerX: (screen.width - width) / 2
    property real centerY: (screen.height - height) / 2
    
    margins {
        left: centerX
        top: centerY
    }
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
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
                        root.margins.left += mouse.x - clickPos.x
                        root.margins.top += mouse.y - clickPos.y
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
