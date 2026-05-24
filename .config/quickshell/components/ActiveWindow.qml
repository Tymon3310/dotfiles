import QtQuick
import QtQuick.Layouts
import Quickshell

RowLayout {
    id: root
    spacing: 8

    // Properties passed from Bar.qml
    property var activeWindowData: null
    property var blocklist: []

    // Returns true if the current window should be hidden per the blocklist
    function isBlocked(data) {
        if (!data || !blocklist || blocklist.length === 0) return false;
        var cls   = (data.class  || "").toLowerCase();
        var title = (data.title  || "").toLowerCase();
        for (var i = 0; i < blocklist.length; i++) {
            var fragment = blocklist[i].toLowerCase();
            if (fragment.length > 0 && (cls.indexOf(fragment) !== -1 || title.indexOf(fragment) !== -1))
                return true;
        }
        return false;
    }

    // Only show if there is an active window on this monitor and it's not blocked
    visible: activeWindowData !== null
             && activeWindowData.title !== ""
             && !isBlocked(activeWindowData)

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
        Layout.maximumWidth: 500
        Layout.preferredWidth: Math.min(implicitWidth, 500)
    }
}
