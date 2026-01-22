import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root
    signal requestSelect()

    // Blue accent
    readonly property color accentColor: "#89b4fa"

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        Text {
            text: "Region Selection"
            color: "#ffffff"
            font.pixelSize: 24
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: "Select a specific area on any of your screens to share."
            color: "#aaaaaa"
            font.pixelSize: 14
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            width: 200
            height: 50
            radius: 8
            color: mouseArea.containsMouse ? root.accentColor : "#333333"
            Layout.alignment: Qt.AlignHCenter
            
            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: "Crop" 
                    color: mouseArea.containsMouse ? "#1e1e2e" : "#ffffff"
                    font.pixelSize: 20
                }
                
                Text {
                    text: "Start Selection"
                    color: mouseArea.containsMouse ? "#1e1e2e" : "#ffffff"
                    font.pixelSize: 16
                    font.bold: true
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.requestSelect()
            }
        }
    }
}
