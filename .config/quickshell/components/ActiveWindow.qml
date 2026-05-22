import QtQuick
import QtQuick.Layouts
import Quickshell

RowLayout {
    id: root
    spacing: 8
    
    // Properties passed from Bar.qml
    property var activeWindowData: null
    
    // Only show if there is an active window on this monitor
    visible: activeWindowData !== null && activeWindowData.title !== ""
    
    function getIconPath(appClass) {
        if (!appClass) return Quickshell.iconPath("application-x-executable");
        
        // Try lowercase version first
        var lower = appClass.toLowerCase();
        var path = Quickshell.iconPath(lower, true);
        if (path !== "") return path;
        
        // Try original version
        path = Quickshell.iconPath(appClass, true);
        if (path !== "") return path;
        
        // Fallback icon
        return Quickshell.iconPath("application-x-executable");
    }

    Image {
        id: winIcon
        Layout.preferredWidth: 14
        Layout.preferredHeight: 14
        Layout.alignment: Qt.AlignVCenter
        source: activeWindowData ? root.getIconPath(activeWindowData.class) : ""
        fillMode: Image.PreserveAspectFit
    }
    
    Text {
        id: winTitle
        text: activeWindowData ? activeWindowData.title : ""
        font.family: "Google Sans Code NF"
        font.pixelSize: 11
        font.bold: true
        color: "#FFFFFF"
        elide: Text.ElideRight
        Layout.alignment: Qt.AlignVCenter
        Layout.maximumWidth: 180
        Layout.preferredWidth: Math.min(implicitWidth, 180)
    }
}
