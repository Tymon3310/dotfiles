import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root
    property bool active: false
    signal windowSelected(string address)

    // Blue accent color
    readonly property color accentColor: "#89b4fa"

    // Collect all windows from ALL workspaces
    property var allWindows: {
        let windows = []
        if (!Hyprland.workspaces) return []
        
        // Helper to check if a workspace is active (visible)
        const activeWorkspaceIds = []
        if (Hyprland.monitors) {
            for (let i = 0; i < Hyprland.monitors.values.length; i++) {
                const mon = Hyprland.monitors.values[i]
                if (mon.activeWorkspace) {
                    activeWorkspaceIds.push(mon.activeWorkspace.id)
                }
            }
        }

        // Iterate all workspaces
        for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
            const ws = Hyprland.workspaces.values[i]
            if (ws.toplevels) {
                for (let j = 0; j < ws.toplevels.values.length; j++) {
                    const win = ws.toplevels.values[j]
                    
                    // Determine visibility
                    const isVisible = activeWorkspaceIds.includes(ws.id)
                    
                    let targetScreen = null
                    let monitorObj = null
                    
                    if (Hyprland.monitors) {
                         const winMonId = win.lastIpcObject ? win.lastIpcObject.monitor : -1
                         for (let k = 0; k < Hyprland.monitors.values.length; k++) {
                             const m = Hyprland.monitors.values[k]
                             if (m.id === winMonId) {
                                 monitorObj = m
                                 break
                             }
                         }
                    }
                    
                    if (monitorObj) {
                        targetScreen = Quickshell.screens.find(s => s.name === monitorObj.name)
                    }

                    windows.push({
                        window: win,
                        ipc: win.lastIpcObject || {},
                        workspace: ws,
                        isVisible: isVisible && targetScreen !== null,
                        monitor: monitorObj,
                        screen: targetScreen
                    })
                }
            }
        }
        
        // Sort: Visible first, then by workspace ID
        windows.sort((a, b) => {
            if (a.isVisible !== b.isVisible) return a.isVisible ? -1 : 1
            return a.workspace.id - b.workspace.id
        })
        
        return windows
    }

    GridView {
        anchors.fill: parent
        anchors.margins: 20
        cellWidth: 240
        cellHeight: 180
        clip: true
        model: root.active ? root.allWindows : []

        delegate: Rectangle {
            id: delegateItem
            width: 220
            height: 160
            color: mouseArea.containsMouse ? "#333333" : "#1a1a1a"
            radius: 8
            border.color: mouseArea.containsMouse ? root.accentColor : "#333333"
            border.width: mouseArea.containsMouse ? 2 : 1

            property var entry: modelData
            property bool isLive: entry.isVisible
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // Window Preview or Placeholder
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    // Background
                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
                        radius: 4
                        opacity: 0.5
                    }

                    // LIVE PREVIEW (Only if visible)
                    Item {
                        visible: delegateItem.isLive && !!delegateItem.entry.screen
                        anchors.centerIn: parent
                        
                        property real winW: (delegateItem.entry.ipc.size && delegateItem.entry.ipc.size[0]) || 100
                        property real winH: (delegateItem.entry.ipc.size && delegateItem.entry.ipc.size[1]) || 100
                        property real scaleFactor: Math.min(parent.width / winW, parent.height / winH)
                        
                        width: winW * scaleFactor
                        height: winH * scaleFactor
                        clip: true

                        ScreencopyView {
                            property real monX: delegateItem.entry.monitor ? delegateItem.entry.monitor.lastIpcObject.x : 0
                            property real monY: delegateItem.entry.monitor ? delegateItem.entry.monitor.lastIpcObject.y : 0
                            property real relX: (delegateItem.entry.ipc.at ? delegateItem.entry.ipc.at[0] : 0) - monX
                            property real relY: (delegateItem.entry.ipc.at ? delegateItem.entry.ipc.at[1] : 0) - monY
                            
                            x: -relX * parent.scaleFactor
                            y: -relY * parent.scaleFactor
                            
                            width: (delegateItem.entry.screen ? delegateItem.entry.screen.width : 0) * parent.scaleFactor
                            height: (delegateItem.entry.screen ? delegateItem.entry.screen.height : 0) * parent.scaleFactor
                            
                            captureSource: delegateItem.entry.screen
                        }
                    }
                    
                    // FALLBACK / HIDDEN STATE
                    Item {
                        visible: !delegateItem.isLive
                        anchors.fill: parent
                        
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: "#333333"
                            border.width: 1
                            radius: 4
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                
                                // Try to show icon
                                Image {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 48
                                    height: 48
                                    source: "image://icon/" + (delegateItem.entry.ipc.class || "application-x-executable")
                                    sourceSize.width: 48
                                    sourceSize.height: 48
                                    fillMode: Image.PreserveAspectFit
                                }
                                
                                Text {
                                    text: "Workspace " + delegateItem.entry.workspace.name + " (Hidden)"
                                    color: "#666666"
                                    font.pixelSize: 11
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                    
                    // Workspace Badge
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 4
                        width: wsText.width + 10
                        height: 18
                        radius: 9
                        color: delegateItem.isLive ? root.accentColor : "#444444"
                        
                        Text {
                            id: wsText
                            anchors.centerIn: parent
                            text: delegateItem.entry.workspace.name
                            font.pixelSize: 10
                            color: parent.parent.color == root.accentColor ? "#1e1e2e" : "#cccccc"
                            font.bold: true
                        }
                    }
                }

                // Info
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    Text {
                        text: delegateItem.entry.ipc.title || "Unknown"
                        color: mouseArea.containsMouse ? root.accentColor : "#ffffff"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                
                Text {
                    text: delegateItem.entry.ipc.class || "Unknown"
                    color: "#aaaaaa"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.windowSelected(delegateItem.entry.window.address)
            }
        }
    }
}
