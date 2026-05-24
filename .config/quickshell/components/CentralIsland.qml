import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    width: islandContainer.width
    height: 24
    
    property var parentWindow: null
    property bool dashboardOpen: false
    property var spotify: null
    property var sys: null
    property bool hovered: false
    
    readonly property string customFont: "Google Sans Code NF"
    
    // Formatting helper
    function formatTime(us) {
        if (!us || us < 0) return "0:00";
        var seconds = Math.floor(us / 1000000);
        var mins = Math.floor(seconds / 60);
        var secs = seconds % 60;
        return mins + ":" + secs.toString().padStart(2, '0');
    }
    
    function getVolIcon(v) {
        if (v <= 0.01) return "";
        if (v < 0.33) return "";
        return "";
    }
    
    // Spotify text generator
    function getSpotifyText() {
        if (!spotify || !spotify.title || spotify.status === "Stopped") {
            return "No Active Player 󰝛";
        }
        var elapsed = root.formatTime(spotify.position);
        var total = root.formatTime(spotify.length);
        var vol = spotify.volume !== undefined ? spotify.volume : 0.5;
        var volIcon = root.getVolIcon(vol);
        var volPct = Math.round(vol * 100);
        return spotify.title + " [" + elapsed + "/" + total + "] " + volIcon + " " + volPct + "%";
    }
    
    // Main visible pill on the bar
    Rectangle {
        id: islandContainer
        height: 24
        width: Math.max(180, Math.min(320, scrollerText.contentWidth + 50))
        radius: 12
        color: "#99000000"
        border.color: root.dashboardOpen ? "#0070D8" : "#33FFFFFF"
        border.width: 1
        
        Behavior on border.color { ColorAnimation { duration: 150 } }
        
        Row {
            anchors.centerIn: parent
            spacing: 8
            
            Text {
                text: spotify && spotify.status === "Playing" ? "󰓇" : "󰝛"
                font.family: root.customFont
                font.pixelSize: 12
                color: spotify && spotify.status === "Playing" ? "#1db954" : "#99FFFFFF"
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Item {
                id: clipContainer
                width: islandContainer.width - 44
                height: 16
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    id: scrollerText
                    text: root.getSpotifyText()
                    font.family: root.customFont
                    font.pixelSize: 11
                    font.bold: true
                    color: "#FFFFFF"
                    anchors.verticalCenter: parent.verticalCenter
                    
                    // Simple marquee scrolling if text is wider than container
                    NumberAnimation on x {
                        id: scrollAnim
                        from: 6
                        to: clipContainer.width - scrollerText.contentWidth - 6
                        duration: 8000
                        loops: Animation.Infinite
                        running: scrollerText.contentWidth > clipContainer.width && spotify && spotify.status === "Playing"
                        
                        onRunningChanged: {
                            if (!running) scrollerText.x = 6;
                        }
                    }
                }
            }
        }
        
        MouseArea {
            id: islandMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onContainsMouseChanged: root.hovered = containsMouse
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    Quickshell.execDetached(["playerctl", "--player=spotify", "play-pause"]);
                } else {
                    root.dashboardOpen = !root.dashboardOpen;
                }
            }
            onWheel: (event) => {
                if (event.angleDelta.y > 0) {
                    Quickshell.execDetached(["playerctl", "--player=spotify", "volume", "0.05+"]);
                } else if (event.angleDelta.y < 0) {
                    Quickshell.execDetached(["playerctl", "--player=spotify", "volume", "0.05-"]);
                }
            }
        }
    }
}
