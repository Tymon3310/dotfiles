import QtQuick
import QtQuick.Controls

ToolTip {
    id: control
    
    padding: 8
    
    readonly property var parentWindow: parent ? parent.Window.window : null
    
    y: parent ? parent.height + 14 : 36
    x: {
        if (!parent) return 0;
        var targetX = (parent.width - implicitWidth) / 2;
        var windowWidth = parentWindow ? parentWindow.width : 1920;
        var absoluteX = parent.mapToItem(null, targetX, 0).x;
        var rightLimit = windowWidth - 12;
        if (absoluteX + implicitWidth > rightLimit) {
            targetX -= (absoluteX + implicitWidth - rightLimit);
        }
        var leftLimit = 12;
        if (absoluteX < leftLimit) {
            targetX += (leftLimit - absoluteX);
        }
        return targetX;
    }
    
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
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        width: control.availableWidth
    }
    
    background: Rectangle {
        color: "#E60A0A0A"
        border.color: "#0070D8"
        border.width: 1
        radius: 6
    }
}
