import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland

Item {
    id: root
    implicitWidth: switcherRow.width
    implicitHeight: 30
    
    // Properties passed from Bar.qml
    property var monitorHyprland: null
    
    // Catch wheel scroll events anywhere over the workspace switcher's area
    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y > 0) {
                Hyprland.dispatch("hl.dsp.focus({ workspace = \"e-1\" })");
            } else if (event.angleDelta.y < 0) {
                Hyprland.dispatch("hl.dsp.focus({ workspace = \"e+1\" })");
            }
        }
    }
    
    ListModel {
        id: workspacesModel
    }

    function syncWorkspaces() {
        if (!root.monitorHyprland || !root.monitorHyprland.workspaces) {
            workspacesModel.clear();
            return;
        }

        var newWorkspaces = root.monitorHyprland.workspaces;

        // Create a map of new workspaces by ID for easy lookup
        var newMap = {};
        for (var i = 0; i < newWorkspaces.length; i++) {
            var ws = newWorkspaces[i];
            newMap[ws.id] = ws;
        }

        // 1. Remove workspaces that no longer exist
        for (var j = workspacesModel.count - 1; j >= 0; j--) {
            var existingId = workspacesModel.get(j).wsId;
            if (!newMap[existingId]) {
                workspacesModel.remove(j);
            }
        }

        // 2. Add or update workspaces
        var sortedNew = newWorkspaces.slice().sort((a, b) => a.id - b.id);

        for (var k = 0; k < sortedNew.length; k++) {
            var newWs = sortedNew[k];
            var foundIndex = -1;
            for (var m = 0; m < workspacesModel.count; m++) {
                if (workspacesModel.get(m).wsId === newWs.id) {
                    foundIndex = m;
                    break;
                }
            }

            if (foundIndex !== -1) {
                // Move to index k if not already there to maintain sort
                if (foundIndex !== k) {
                    workspacesModel.move(foundIndex, k, 1);
                }
                // Update properties in-place
                var item = workspacesModel.get(k);
                if (item.focused !== newWs.focused) {
                    workspacesModel.setProperty(k, "focused", newWs.focused);
                }
                if (item.windows !== newWs.windows) {
                    workspacesModel.setProperty(k, "windows", newWs.windows);
                }
                if (item.name !== newWs.name) {
                    workspacesModel.setProperty(k, "name", newWs.name);
                }
            } else {
                // Insert new workspace at k
                workspacesModel.insert(k, {
                    "wsId": newWs.id,
                    "name": newWs.name,
                    "focused": newWs.focused,
                    "windows": newWs.windows
                });
            }
        }
    }

    onMonitorHyprlandChanged: syncWorkspaces()
    Component.onCompleted: syncWorkspaces()

    Row {
        id: switcherRow
        spacing: 8
        anchors.verticalCenter: parent.verticalCenter
        
        Repeater {
            model: workspacesModel
            
            delegate: Rectangle {
                id: wsDot
                
                // Layout dimensions
                height: 8
                width: (focused && root.monitorHyprland && root.monitorHyprland.focused) ? 20 : 8
                implicitWidth: width
                radius: 4
                
                // Colors matching system theme (Blue for focused, semi-transparent white for passive)
                color: focused ? "#0070D8" : (mouseArea.containsMouse ? "#C0FFFFFF" : "#66FFFFFF")
                
                // Animation for width when active/focused changes
                Behavior on width {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
                
                // Animation for color changes
                Behavior on color {
                    ColorAnimation { duration: 200 }
                }

                // Click and scroll behavior
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    
                    
                    onClicked: {
                        // Use Hyprland 0.55+ Lua dispatch syntax
                        Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + wsId + "\" })");
                    }
                    
                    onWheel: (event) => {
                        if (event.angleDelta.y > 0) {
                            Hyprland.dispatch("hl.dsp.focus({ workspace = \"e-1\" })");
                        } else if (event.angleDelta.y < 0) {
                            Hyprland.dispatch("hl.dsp.focus({ workspace = \"e+1\" })");
                        }
                    }
                }
            }
        }
    }
}
