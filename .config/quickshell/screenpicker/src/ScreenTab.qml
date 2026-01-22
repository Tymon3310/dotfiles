import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root
    signal screenSelected(string name)

    // Blue accent color
    readonly property color accentColor: "#89b4fa"

    GridView {
        anchors.fill: parent
        anchors.margins: 20
        cellWidth: 360
        cellHeight: 260
        clip: true
        model: Quickshell.screens

        delegate: Rectangle {
            id: screenDelegate
            width: 340
            height: 240
            color: mouseArea.containsMouse ? "#333333" : "#1a1a1a"
            radius: 8
            border.color: mouseArea.containsMouse ? root.accentColor : "#333333"
            border.width: 2

            required property var modelData // The Screen object

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                // Screen Preview
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    // Container for aspect ratio handling
                    Item {
                        anchors.centerIn: parent
                        property real screenRatio: screenDelegate.modelData.width / screenDelegate.modelData.height
                        property real containerRatio: parent.width / parent.height
                        
                        width: screenRatio > containerRatio ? parent.width : parent.height * screenRatio
                        height: screenRatio > containerRatio ? parent.width / screenRatio : parent.height
                        
                        clip: true
                        
                        // Background
                        Rectangle {
                            anchors.fill: parent
                            color: "#000000"
                        }

                        ScreencopyView {
                            anchors.fill: parent
                            captureSource: screenDelegate.modelData
                        }
                    }
                }

                // Info
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: screenDelegate.modelData.name
                        color: mouseArea.containsMouse ? root.accentColor : "#ffffff"
                        font.pixelSize: 14
                        font.bold: true
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Text {
                        text: screenDelegate.modelData.width + "x" + screenDelegate.modelData.height
                        color: "#aaaaaa"
                        font.pixelSize: 12
                    }
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.screenSelected(screenDelegate.modelData.name)
            }
        }
    }
}
