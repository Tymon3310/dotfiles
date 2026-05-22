import QtQuick
import QtQuick.Controls

ToolTip {
    id: control
    
    padding: 8
    
    y: parent ? parent.height + 14 : 36
    x: parent ? (parent.width - implicitWidth) / 2 : 0
    
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 150; easing.type: Easing.OutQuad }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 150; easing.type: Easing.OutQuad }
    }
    
    contentItem: Text {
        text: control.text
        font.family: "Google Sans Code NF"
        font.pixelSize: 11
        color: "#FFFFFF"
    }
    
    background: Rectangle {
        color: "#E60A0A0A"
        border.color: "#0070D8"
        border.width: 1
        radius: 6
    }
}
