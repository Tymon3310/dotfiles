import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications

Row {
    id: root
    spacing: 12
    
    // Properties passed from Bar.qml
    property var parentWindow: null
    property var sysData: null
    
    // Calendar properties exposed to parent Bar.qml
    property bool calendarOpen: false
    property date selectedDate: new Date()
    property real clockCenterX: clockWidget.x + clockWidget.width / 2
    property bool clockHovered: false

    // Custom System Tray Menu properties exposed to parent Bar.qml
    property bool trayMenuOpen: false
    property real trayMenuCenterX: 0
    property bool trayHovered: false
    property alias activeMenuOpener: trayMenuOpener

    // Notification panel properties exposed to parent Bar.qml
    property bool notifPanelOpen: false
    property bool notifHovered: false
    property var notifServer: null
    property var notifHistory: null
    property bool notifDnd: false

    QsMenuOpener {
        id: trayMenuOpener
    }
    
    // Access stats safely
    property var stats: root.sysData ? root.sysData : ({ "cpu": 0, "ram": 0 })

    // --- Font settings ---
    readonly property string customFont: "Google Sans Code NF"

    // --- Separator Component ---
    component Separator : Rectangle {
        width: 1
        height: 14
        color: "#33FFFFFF"
        anchors.verticalCenter: parent.verticalCenter
    }

    // ==========================================
    // 1. SYSTEM TRAY WIDGET
    // ==========================================
    Row {
        id: trayRow
        spacing: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: SystemTray.items.values.length > 0
        
        HoverHandler {
            onHoveredChanged: root.trayHovered = hovered
        }
        
        Repeater {
            model: SystemTray.items.values
            
            delegate: Item {
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                
                Image {
                    source: modelData.icon
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    opacity: trayMouse.containsMouse ? 1.0 : 0.85
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                
                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    
                    
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            modelData.activate();
                        } else if (mouse.button === Qt.RightButton) {
                            if (modelData.hasMenu && modelData.menu) {
                                if (root.parentWindow) {
                                    if (trayMenuOpener.menu === modelData.menu && root.trayMenuOpen) {
                                        root.trayMenuOpen = false;
                                    } else {
                                        trayMenuOpener.menu = modelData.menu;
                                        
                                        var localCenter = width / 2;
                                        var wPos = mapToItem(root.parentWindow.contentItem, localCenter, 0);
                                        root.trayMenuCenterX = wPos.x;
                                        
                                        root.trayMenuOpen = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    Separator { visible: trayRow.visible }

    // ==========================================
    // 2. SYSTEM STATS WIDGET (CPU/RAM)
    // ==========================================
    Row {
        id: statsRow
        spacing: 10
        anchors.verticalCenter: parent.verticalCenter
        
        function getCpuColor(val) {
            if (val > 85) return "#ff3b30"; // Red
            if (val > 65) return "#ff9500"; // Orange
            return "#FFFFFF";
        }
        
        function getRamColor(val) {
            if (val > 85) return "#ff3b30";
            if (val > 65) return "#ff9500";
            return "#FFFFFF";
        }

        // CPU
        Row {
            spacing: 4
            Text {
                text: ""
                font.family: root.customFont
                font.pixelSize: 12
                color: "#0070D8" // System blue accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: Math.round(root.stats.cpu) + "%"
                font.family: root.customFont
                font.pixelSize: 11
                font.bold: true
                color: statsRow.getCpuColor(root.stats.cpu)
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // RAM
        Row {
            spacing: 4
            Text {
                text: ""
                font.family: root.customFont
                font.pixelSize: 12
                color: "#0070D8" // System blue accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: Math.round(root.stats.ram) + "%"
                font.family: root.customFont
                font.pixelSize: 11
                font.bold: true
                color: statsRow.getRamColor(root.stats.ram)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Separator {}



    // ==========================================
    // 3. AUDIO WIDGET (PipeWire + JBL status)
    // ==========================================
    Row {
        id: audioRow
        spacing: 10
        anchors.verticalCenter: parent.verticalCenter
        
        PwObjectTracker {
            objects: [
                Pipewire.defaultAudioSink,
                Pipewire.defaultAudioSource
            ]
        }
        
        property double vol: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.volume : 0.0
        property bool muted: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.muted : true

        function getVolIcon(volume, isMuted) {
            if (isMuted) return "";
            if (volume <= 0.01) return "";
            if (volume < 0.33) return "";
            return "";
        }

        function adjustVolume(delta) {
            if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                var newVol = Math.max(0.0, Math.min(1.0, Pipewire.defaultAudioSink.audio.volume + delta));
                Pipewire.defaultAudioSink.audio.volume = newVol;
            }
        }

        function toggleSinkMute() {
            if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
            }
        }

        function toggleSourceMute() {
            if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) {
                Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted;
            }
        }

        // Volume text / icon
        Item {
            width: volDisplayRow.width
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            
            Row {
                id: volDisplayRow
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    text: audioRow.getVolIcon(audioRow.vol, audioRow.muted)
                    font.family: root.customFont
                    font.pixelSize: 12
                    color: audioRow.muted ? "#ff3b30" : "#0070D8"
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    text: Math.round(audioRow.vol * 100) + "%"
                    font.family: root.customFont
                    font.pixelSize: 11
                    font.bold: true
                    color: audioRow.muted ? "#ff3b30" : "#FFFFFF"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: audioMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                
                
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        Quickshell.execDetached(["pwvucontrol"]);
                    } else if (mouse.button === Qt.RightButton) {
                        audioRow.toggleSinkMute();
                    } else if (mouse.button === Qt.MiddleButton) {
                        audioRow.toggleSourceMute();
                    }
                }
                
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) {
                        audioRow.adjustVolume(0.02);
                    } else {
                        audioRow.adjustVolume(-0.02);
                    }
                }
            }
        }

        // JBL Mic & Battery Status
        property string jblText: ""
        property string jblTooltip: "JBL: Disconnected"
        property string jblClass: "disconnected"
        property string jblPercentage: ""

        Process {
            id: jblProc
            command: ["/home/tymon/JBL_Baterry_Monitor/tools/waybar_jbl.py", "--mode", "both"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var res = JSON.parse(text);
                        audioRow.jblText = res.text || "";
                        audioRow.jblTooltip = res.tooltip || "JBL: Disconnected";
                        audioRow.jblClass = res.class || "disconnected";
                        audioRow.jblPercentage = (res.percentage !== undefined && res.percentage !== null) ? res.percentage + "%" : "";
                    } catch (e) {
                        audioRow.jblText = "";
                        audioRow.jblTooltip = "JBL: Offline";
                        audioRow.jblClass = "error";
                        audioRow.jblPercentage = "";
                    }
                }
            }
        }

        Timer {
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                jblProc.running = false;
                jblProc.running = true;
            }
        }

        Item {
            width: jblDisplayRow.width
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            visible: audioRow.jblText !== ""
            
            Row {
                id: jblDisplayRow
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    text: audioRow.jblText
                    font.family: root.customFont
                    font.pixelSize: 11
                    font.bold: true
                    color: audioRow.jblClass === "muted" ? "#ff3b30" : "#FFFFFF"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: micMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                
                onClicked: {
                    audioRow.toggleSourceMute();
                }
            }
        }
    }

    Separator {}

    // ==========================================
    // 4. NOTIFICATION WIDGET (with preview bulge)
    // ==========================================
    // 4. NOTIFICATION WIDGET
    // ==========================================
    Item {
        id: notifWidget
        width: notifRow.width
        height: 20
        anchors.verticalCenter: parent.verticalCenter

        readonly property int count: root.notifHistory
            ? root.notifHistory.totalCount : 0

        HoverHandler {
            onHoveredChanged: root.notifHovered = hovered
        }

        Row {
            id: notifRow
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            // Bell icon
            Text {
                text: root.notifDnd ? "\uf1f6" : "\uf0f3"
                font.family: root.customFont
                font.pixelSize: 12
                color: root.notifDnd
                    ? "#FF4C4C"
                    : (notifWidget.count > 0 ? "#ff9500" : (root.notifPanelOpen ? "#0070D8" : "#FFFFFF"))
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // Unread count badge
            Text {
                visible: notifWidget.count > 0 && !root.notifDnd
                text: notifWidget.count
                font.family: root.customFont
                font.pixelSize: 10
                font.bold: true
                color: "#FFFFFF"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    root.notifPanelOpen = !root.notifPanelOpen;
                } else if (mouse.button === Qt.RightButton) {
                    root.notifDnd = !root.notifDnd;
                }
            }
        }
    }

    Separator {}

    // ==========================================
    // 5. CLOCK WIDGET (with Calendar dropdown)
    // ==========================================
    Item {
        id: clockWidget
        width: clockText.implicitWidth + 8
        height: 20
        anchors.verticalCenter: parent.verticalCenter
        
        property string timeStr: "00:00"

        function updateTime() {
            var date = new Date();
            var hours = date.getHours().toString().padStart(2, '0');
            var minutes = date.getMinutes().toString().padStart(2, '0');
            clockWidget.timeStr = hours + ":" + minutes;
        }

        Timer {
            interval: 10000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: clockWidget.updateTime()
        }

        Text {
            id: clockText
            text: clockWidget.timeStr
            font.family: root.customFont
            font.pixelSize: 12
            font.bold: true
            color: "#FFFFFF"
            anchors.centerIn: parent
        }

        MouseArea {
            id: clockMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: root.clockHovered = containsMouse
            
            onClicked: {
                root.selectedDate = new Date();
                root.calendarOpen = !root.calendarOpen;
            }
        }
    }

    Separator {}

    // ==========================================
    // 6. POWER MENU WIDGET
    // ==========================================
    Item {
        id: powerWidget
        width: 18
        height: 18
        anchors.verticalCenter: parent.verticalCenter
        
        Text {
            text: "⏻"
            font.family: root.customFont
            font.pixelSize: 12
            anchors.centerIn: parent
            color: powerMouse.containsMouse ? "#ff3b30" : "#99FFFFFF"
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        
        MouseArea {
            id: powerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            
            onClicked: {
                Quickshell.execDetached(["nwg-bar"]);
            }
        }
    }
}
