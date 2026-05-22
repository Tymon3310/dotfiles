import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    
    property var parentWindow: null
    property var spotify: null
    property var sys: null
    property bool hovered: dashHoverHandler.hovered
    
    readonly property string customFont: "Google Sans Code NF"

    HoverHandler {
        id: dashHoverHandler
    }
    
    // Formatting helper
    function formatTime(us) {
        if (!us || us < 0) return "0:00";
        var seconds = Math.floor(us / 1000000);
        var mins = Math.floor(seconds / 60);
        var secs = seconds % 60;
        return mins + ":" + secs.toString().padStart(2, '0');
    }
    
    // WEATHER STATE MANAGEMENT (Fetched in QML)
    property string weatherCity: "" // Set to your city name to override (e.g. "Warsaw"), or leave empty for IP auto-detection
    property string weatherTemp: "--"
    property string weatherDesc: "Loading..."
    property string weatherIcon: "󰖐"
    property string weatherLocation: ""
    
    function fetchWeather() {
        var xhr = new XMLHttpRequest();
        var url = "https://wttr.in/" + (root.weatherCity ? encodeURIComponent(root.weatherCity) : "") + "?format=j1";
        xhr.open("GET", url, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        var current = res.current_condition[0];
                        root.weatherTemp = current.temp_C + "°C";
                        root.weatherDesc = current.weatherDesc[0].value;
                        
                        if (res.nearest_area && res.nearest_area[0] && res.nearest_area[0].areaName && res.nearest_area[0].areaName[0]) {
                            root.weatherLocation = res.nearest_area[0].areaName[0].value;
                        } else {
                            root.weatherLocation = "";
                        }
                        
                        // Parse weather code into Nerd Font icons
                        var code = intValue(current.weatherCode);
                        root.weatherIcon = root.resolveWeatherIcon(code);
                    } catch (e) {
                        root.weatherDesc = "Error parsing weather";
                    }
                } else {
                    root.weatherDesc = "Weather offline";
                }
            }
        }
        xhr.send();
    }
    
    function intValue(str) {
        var val = parseInt(str);
        return isNaN(val) ? 113 : val;
    }
    
    function resolveWeatherIcon(code) {
        // Simple mapping from WWO code to Nerd Font weather icons
        if (code === 113) return "󰖙"; // Sunny
        if (code === 116) return "󰖕"; // Partly Cloudy
        if ([119, 122].indexOf(code) !== -1) return "󰖐"; // Cloudy
        if ([143, 248, 260].indexOf(code) !== -1) return "󰖑"; // Foggy
        if ([176, 263, 266, 293, 296, 299, 302, 353, 356].indexOf(code) !== -1) return "󰖗"; // Light Rain
        if ([305, 308, 359, 362].indexOf(code) !== -1) return "󰖖"; // Heavy Rain
        if ([200, 386, 389, 392].indexOf(code) !== -1) return "󰙾"; // Thunder
        if ([179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329, 332, 335, 338, 350, 365, 368, 371, 395].indexOf(code) !== -1) return "󰼶"; // Snow
        return "󰖐";
    }
    
    Timer {
        interval: 1800000 // Refresh every 30 minutes
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchWeather()
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12
        
        // 1. Spotify Player
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            color: "#0DFFFFFF"
            radius: 8
            border.color: "#1AFFFFFF"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                
                // Album art
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 80
                    color: "#0DFFFFFF"
                    radius: 6
                    
                    Image {
                        id: albumArt
                        source: spotify && spotify.artUrl ? spotify.artUrl : ""
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        visible: spotify && spotify.artUrl !== ""
                    }
                    
                    Text {
                        text: "󰓇"
                        font.family: root.customFont
                        font.pixelSize: 32
                        color: "#33FFFFFF"
                        anchors.centerIn: parent
                        visible: !albumArt.visible
                    }
                }
                
                // Track title, artist, seekbar & controls
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    Text {
                        text: spotify && spotify.title ? spotify.title : "Not Playing"
                        font.family: root.customFont
                        font.pixelSize: 12
                        font.bold: true
                        color: "#FFFFFF"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    
                    Text {
                        text: spotify && spotify.artist ? spotify.artist : "Unknown Artist"
                        font.family: root.customFont
                        font.pixelSize: 10
                        color: "#99FFFFFF"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    
                    // Seekbar slider
                    Slider {
                        id: seekSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 14
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 0
                        bottomPadding: 0
                        from: 0
                        to: spotify && spotify.length ? spotify.length : 100
                        value: spotify && spotify.position ? spotify.position : 0
                        live: false
                        
                        background: Rectangle {
                            x: seekSlider.leftPadding
                            y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                            width: seekSlider.availableWidth
                            height: 4
                            radius: 2
                            color: "#1AFFFFFF"
                            
                            Rectangle {
                                width: seekSlider.visualPosition * parent.width
                                height: parent.height
                                color: "#0070D8"
                                radius: 2
                            }
                        }
                        
                        handle: Rectangle {
                            x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                            y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                            width: (seekSlider.hovered || seekSlider.pressed) ? 12 : 8
                            height: (seekSlider.hovered || seekSlider.pressed) ? 12 : 8
                            radius: width / 2
                            color: seekSlider.pressed ? "#0070D8" : ((seekSlider.hovered) ? "#3399FF" : "#FFFFFF")
                            
                            Behavior on width { NumberAnimation { duration: 150 } }
                            Behavior on height { NumberAnimation { duration: 150 } }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.NoButton
                        }
                        
                        onPressedChanged: {
                            if (!pressed) {
                                var posSec = value / 1000000;
                                Quickshell.execDetached(["playerctl", "--player=spotify", "position", posSec.toString()]);
                            }
                        }
                    }
                    
                    // Elapsed/Total duration labels
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: root.formatTime(spotify ? spotify.position : 0)
                            font.family: root.customFont
                            font.pixelSize: 9
                            color: "#99FFFFFF"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.formatTime(spotify ? spotify.length : 0)
                            font.family: root.customFont
                            font.pixelSize: 9
                            color: "#99FFFFFF"
                        }
                    }
                    
                    // Control buttons row
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 14
                        
                        Button {
                            id: shuffleBtn
                            text: spotify && spotify.shuffle ? "󰒟" : "󰒞"
                            font.family: root.customFont
                            font.pixelSize: 12
                            flat: true
                            implicitWidth: 24
                            implicitHeight: 22
                            topPadding: 0
                            bottomPadding: 0
                            leftPadding: 0
                            rightPadding: 0
                            background: null
                            onClicked: Quickshell.execDetached(["playerctl", "--player=spotify", "shuffle", "Toggle"])
                            contentItem: Text { 
                                text: shuffleBtn.text
                                font: shuffleBtn.font
                                color: shuffleBtn.hovered ? (spotify && spotify.shuffle ? "#3399FF" : "#FFFFFF") : (spotify && spotify.shuffle ? "#0070D8" : "#99FFFFFF")
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.NoButton
                            }
                        }
                        
                        Button {
                            id: prevBtn
                            text: "⏮"
                            font.family: root.customFont
                            font.pixelSize: 12
                            flat: true
                            implicitWidth: 24
                            implicitHeight: 22
                            topPadding: 0
                            bottomPadding: 0
                            leftPadding: 0
                            rightPadding: 0
                            background: null
                            onClicked: Quickshell.execDetached(["playerctl", "--player=spotify", "previous"])
                            contentItem: Text { 
                                text: prevBtn.text
                                font: prevBtn.font
                                color: prevBtn.hovered ? "#0070D8" : "#FFFFFF"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.NoButton
                            }
                        }
                        
                        Button {
                            id: playBtn
                            text: spotify && spotify.status === "Playing" ? "⏸" : "▶"
                            font.family: root.customFont
                            font.pixelSize: 16
                            flat: true
                            implicitWidth: 24
                            implicitHeight: 22
                            topPadding: 0
                            bottomPadding: 0
                            leftPadding: 0
                            rightPadding: 0
                            background: null
                            onClicked: Quickshell.execDetached(["playerctl", "--player=spotify", "play-pause"])
                            contentItem: Text { 
                                text: playBtn.text
                                font: playBtn.font
                                color: playBtn.hovered ? "#3399FF" : "#0070D8"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.NoButton
                            }
                        }
                        
                        Button {
                            id: nextBtn
                            text: "⏭"
                            font.family: root.customFont
                            font.pixelSize: 12
                            flat: true
                            implicitWidth: 24
                            implicitHeight: 22
                            topPadding: 0
                            bottomPadding: 0
                            leftPadding: 0
                            rightPadding: 0
                            background: null
                            onClicked: Quickshell.execDetached(["playerctl", "--player=spotify", "next"])
                            contentItem: Text { 
                                text: nextBtn.text
                                font: nextBtn.font
                                color: nextBtn.hovered ? "#0070D8" : "#FFFFFF"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.NoButton
                            }
                        }
                        
                        Button {
                            id: loopBtn
                            text: spotify && spotify.loop === "Track" ? "󰑘" : (spotify && spotify.loop === "Playlist" ? "󰑖" : "󰑗")
                            font.family: root.customFont
                            font.pixelSize: 12
                            flat: true
                            implicitWidth: 24
                            implicitHeight: 22
                            topPadding: 0
                            bottomPadding: 0
                            leftPadding: 0
                            rightPadding: 0
                            background: null
                            onClicked: Quickshell.execDetached(["playerctl", "--player=spotify", "loop", "Toggle"])
                            contentItem: Text { 
                                text: loopBtn.text
                                font: loopBtn.font
                                color: loopBtn.hovered ? (spotify && spotify.loop !== "Off" ? "#3399FF" : "#FFFFFF") : (spotify && spotify.loop !== "Off" ? "#0070D8" : "#99FFFFFF")
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.NoButton
                            }
                        }
                    }
                }
            }
        }
        
        // 2. Weather Card
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            color: "#0DFFFFFF"
            radius: 8
            border.color: "#1AFFFFFF"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                
                Text {
                    text: root.weatherIcon
                    font.family: root.customFont
                    font.pixelSize: 24
                    color: "#0070D8"
                }
                
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: root.weatherTemp + (root.weatherLocation ? " (" + root.weatherLocation + ")" : "")
                        font.family: root.customFont
                        font.pixelSize: 12
                        font.bold: true
                        color: "#FFFFFF"
                    }
                    Text {
                        text: root.weatherDesc
                        font.family: root.customFont
                        font.pixelSize: 10
                        color: "#99FFFFFF"
                    }
                }
                
                Item { Layout.fillWidth: true }
            }
        }
        
        // 3. Detailed System Monitor Stats
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0DFFFFFF"
            radius: 8
            border.color: "#1AFFFFFF"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                
                Text {
                    text: "System Information"
                    font.family: root.customFont
                    font.pixelSize: 11
                    font.bold: true
                    color: "#0070D8"
                }
                
                // CPU Bar
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        Text { text: "CPU Usage"; font.family: root.customFont; font.pixelSize: 10; color: "#99FFFFFF" }
                        Item { Layout.fillWidth: true }
                        Text { text: Math.round(sys ? sys.cpu : 0) + "%"; font.family: root.customFont; font.pixelSize: 10; color: "#FFFFFF"; font.bold: true }
                    }
                    ProgressBar {
                        id: cpuBar
                        Layout.fillWidth: true
                        value: sys ? sys.cpu / 100.0 : 0
                        implicitHeight: 6
                        background: Rectangle { color: "#1AFFFFFF"; radius: 3 }
                        contentItem: Item {
                            Rectangle {
                                width: cpuBar.visualPosition * parent.width
                                height: parent.height
                                radius: 3
                                color: "#0070D8"
                            }
                        }
                    }
                }
                
                // RAM Bar
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        Text { text: "RAM Usage"; font.family: root.customFont; font.pixelSize: 10; color: "#99FFFFFF" }
                        Item { Layout.fillWidth: true }
                        Text { text: Math.round(sys ? sys.ram : 0) + "%"; font.family: root.customFont; font.pixelSize: 10; color: "#FFFFFF"; font.bold: true }
                    }
                    ProgressBar {
                        id: ramBar
                        Layout.fillWidth: true
                        value: sys ? sys.ram / 100.0 : 0
                        implicitHeight: 6
                        background: Rectangle { color: "#1AFFFFFF"; radius: 3 }
                        contentItem: Item {
                            Rectangle {
                                width: ramBar.visualPosition * parent.width
                                height: parent.height
                                radius: 3
                                color: "#0070D8"
                            }
                        }
                    }
                }
                
                // GPU & VRAM Bar
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        Text { text: "GPU Usage"; font.family: root.customFont; font.pixelSize: 10; color: "#99FFFFFF" }
                        Item { Layout.fillWidth: true }
                        Text { 
                            text: Math.round(sys ? sys.gpu : 0) + "% (VRAM: " + (sys ? sys.vram_used_gib.toFixed(1) : "0") + "/" + (sys ? sys.vram_total_gib.toFixed(1) : "0") + "GB)"; 
                            font.family: root.customFont; font.pixelSize: 10; color: "#FFFFFF"; font.bold: true 
                        }
                    }
                    ProgressBar {
                        id: gpuBar
                        Layout.fillWidth: true
                        value: sys ? sys.gpu / 100.0 : 0
                        implicitHeight: 6
                        background: Rectangle { color: "#1AFFFFFF"; radius: 3 }
                        contentItem: Item {
                            Rectangle {
                                width: gpuBar.visualPosition * parent.width
                                height: parent.height
                                radius: 3
                                color: "#0070D8"
                            }
                        }
                    }
                }
                
                // Network Stats rx/tx speed
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    
                    RowLayout {
                        spacing: 4
                        Text { text: ""; font.family: root.customFont; font.pixelSize: 12; color: "#0070D8" }
                        Text { text: sys ? sys.net_rx : "0 B/s"; font.family: root.customFont; font.pixelSize: 10; color: "#FFFFFF"; font.bold: true }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    RowLayout {
                        spacing: 4
                        Text { text: ""; font.family: root.customFont; font.pixelSize: 12; color: "#0070D8" }
                        Text { text: sys ? sys.net_tx : "0 B/s"; font.family: root.customFont; font.pixelSize: 10; color: "#FFFFFF"; font.bold: true }
                    }
                }
            }
        }
    }
}
