import QtQuick
import QtQuick.Layouts

Rectangle {
    id: control
    
    property string text
    property string icon
    property bool active: false
    signal clicked()
    
    // Blue accent
    readonly property color accentColor: "#89b4fa"
    
    color: active ? "#333333" : "transparent"
    radius: 8
    
    // Hover effect
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "#ffffff"
        opacity: mouseArea.containsMouse && !active ? 0.05 : 0
    }
    
    RowLayout {
        anchors.centerIn: parent
        spacing: 8
        
        Text {
            text: control.text
            color: active ? "#ffffff" : "#aaaaaa"
            font.pixelSize: 14
            font.weight: active ? Font.Medium : Font.Normal
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.clicked()
    }
    
    // Bottom border for active state
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: active ? parent.width - 20 : 0
        height: 2
        color: control.accentColor
        radius: 1
        
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
    }
}
