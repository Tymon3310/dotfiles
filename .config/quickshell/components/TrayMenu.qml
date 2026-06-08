import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    
    property var parentWindow: null
    property var activeMenuOpener: null
    property bool hovered: trayHoverHandler.hovered
    
    onActiveMenuOpenerChanged: {
        if (activeMenuOpener) {
            console.log("[TrayMenu] Opened with " + activeMenuOpener.children.values.length + " items:");
            var vals = activeMenuOpener.children.values;
            for (var i = 0; i < vals.length; i++) {
                console.log("  Item " + i + ": text='" + vals[i].text + "' visible=" + vals[i].visible + " enabled=" + vals[i].enabled + " isSeparator=" + vals[i].isSeparator);
            }
        }
    }
    
    // Readonly properties matching our design system
    readonly property string customFont: "Google Sans Code NF"
    
    // Check if any visible item in the menu has a non-empty icon
    property bool hasAnyIcon: {
        if (!activeMenuOpener) return false;
        var vals = activeMenuOpener.children.values;
        for (var i = 0; i < vals.length; i++) {
            if (vals[i].icon && vals[i].icon !== "") return true;
        }
        return false;
    }
    
    // Dynamic height based on content
    property real contentHeight: menuListView.contentHeight + 16 // 8px padding top/bottom
    
    signal itemTriggered()

    HoverHandler {
        id: trayHoverHandler
    }
    
    ListView {
        id: menuListView
        anchors.fill: parent
        anchors.margins: 8
        interactive: contentHeight > height
        spacing: 2
        
        model: root.activeMenuOpener ? root.activeMenuOpener.children.values : []
        
        ScrollBar.vertical: ScrollBar {
            active: parent.interactive
            width: 4
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: "#4DFFFFFF" // Glassy semi-transparent handle
            }
        }
        
        delegate: Item {
            width: menuListView.width
            
            // Robust separator check (handles isSeparator and string of hyphens/underscores/spaces)
            readonly property bool isSeparatorItem: modelData.isSeparator || 
                                                    (modelData.text !== undefined && 
                                                     modelData.text !== null && 
                                                     modelData.text.replace(/[-_ ]/g, "") === "")
            
            height: isSeparatorItem ? 9 : 30
            
            // Render separators
            Rectangle {
                visible: parent.isSeparatorItem
                width: parent.width - 12
                height: 1
                color: "#33FFFFFF"
                anchors.centerIn: parent
            }
            
            // Render clickable items
            Rectangle {
                visible: !parent.isSeparatorItem
                anchors.fill: parent
                radius: 6
                color: itemMouse.containsMouse && modelData.enabled ? "#1AFFFFFF" : "transparent"
                opacity: modelData.enabled ? 1.0 : 0.4
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8
                    
                    Item {
                        width: root.hasAnyIcon ? 14 : 0
                        height: 14
                        visible: root.hasAnyIcon
                        Layout.alignment: Qt.AlignVCenter
                        
                        Image {
                            id: itemIcon
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            source: {
                                if (!modelData.icon || modelData.icon === "") return "";
                                if (modelData.icon.startsWith("/") || modelData.icon.startsWith("file:")) return modelData.icon;
                                return Quickshell.iconPath(modelData.icon, true) || "";
                            }
                            visible: source != ""
                        }
                    }
                    
                    Text {
                        text: modelData.text ? modelData.text.replace(/&/g, "") : ""
                        font.family: root.customFont
                        font.pixelSize: 12
                        color: "#FFFFFF"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    
                    onClicked: {
                        if (modelData.enabled) {
                            if (typeof modelData.triggered === "function") {
                                modelData.triggered();
                            } else if (typeof modelData.activate === "function") {
                                modelData.activate();
                            } else if (typeof modelData.click === "function") {
                                modelData.click();
                            } else if (typeof modelData.trigger === "function") {
                                modelData.trigger();
                            } else if (typeof modelData.sendTriggered === "function") {
                                modelData.sendTriggered();
                            }
                            root.itemTriggered();
                        }
                    }
                }
            }
        }
    }
}
