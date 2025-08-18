import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Mpris

// The main shell
ShellRoot {
    Variants {
        model: Quickshell.screens;
        delegate: Component {
            PanelWindow {
            property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 35 
            color: "transparent"

            Rectangle {
                id: notch

                implicitWidth: 800
                implicitHeight: 35
                color: "#202030"
                radius: implicitHeight / 3
                anchors.centerIn: parent

                // Left -- Hyprland Information
                Rectangle {
                    id: hyprInfo
                    implicitWidth: 150
                    implicitHeight: 35
                    radius: implicitWidth /2
                    color: "#A9BCD0"

                    Text {
                        id: windowTitle
                        x: 40
                        // y: 8.75

                        anchors.verticalCenter: parent.verticalCenter

                        font.pointSize: 12
                        text: ToplevelManager.activeToplevel.appId.trim()
                    }

                    Rectangle {
                        id: workspaceCircle
                        x: 0
                        implicitWidth: 35
                        implicitHeight: 35
                        radius: implicitWidth /2
                        color: "#96ADC5"

                        Text {
                            id: workspaceNumber
                            anchors.centerIn: parent
                            color: "black"
                            text: Hyprland.focusedWorkspace.id
                            font.bold: true
                            font.pointSize: 15
                        }
                    }
                }

                // Center -- clock
                Text {
                    id: clock
                    text: "00:00 00.00.00"
                    anchors.centerIn: parent

                    color: "#A9BCD0"
                    font.pointSize: 15
                }

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    
                    property var date: new Date()
                    onTriggered: clock.text = date.getHours().toString().padStart(2, '0') + ":" + date.getMinutes().toString().padStart(2, '0') + " " + date.getDate().toString().padStart(2, '0') + "." + (date.getMonth() + 1).toString().padStart(2, '0') + "." + (date.getFullYear() % 100).toString().padStart(2, '0')
                }

                // Other
                PanelWindow {
                    id: utilPanel
                    visible: false
                    color: "transparent"
                    implicitWidth: 700
                    implicitHeight: 300

                    anchors {
                        top: true
                    }
                    margins {
                        top: 20
                    }

                    Rectangle {
                        implicitWidth: 700
                        implicitHeight: 300
                        color: "#202030"
                        radius: implicitHeight / 5
                        clip: true

                        function findSpotify(list) {
                            for (let i = 0; i < list.length; i++) {
                                if (list[i].identity === "Spotify") {
                                    return i;
                                }
                            }
                            return -1;
                        }

                        property int pIndex: findSpotify(Mpris.players ? Mpris.players.values : [])

                        Rectangle {
                            implicitWidth: 350
                            implicitHeight: 300
                            color: "#181825"
                            radius: implicitHeight / 5
                            clip: true
                            anchors {
                                right: parent.right
                            }
                            

                            Rectangle {
                                implicitWidth: 50
                                implicitHeight: 300
                                color: "#181825"
                                anchors {
                                    left: parent.left
                                }
                            }

                            // Background
                            Text {
                                anchors.centerIn: parent
                                color: "#101019"
                                text: ""
                                font.bold: true
                                font.pointSize: 200
                                font.italic: true
                            }
                            
                            Image {
                                id: mprisImage
                                source: Mpris.players.values[parent.parent.pIndex].trackArtUrl
                                // fillMode: Image.PreserveAspectFit
                                anchors.fill: parent
                                asynchronous: true
                                opacity: 0.5
                            }

                            // Music Control
                            Text { 
                                text: `  ${Mpris.players.values[parent.parent.pIndex].trackTitle}`
                                color: "#D8DBE2"
                                font.pointSize: 20
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 80
                            }

                            Text { 
                                text: `  ${Mpris.players.values[parent.parent.pIndex].trackArtist}`
                                color: "#D8DBE2"
                                font.pointSize: 15
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 120
                            }

                            Text {
                                id: posDisplay
                                text: "pos/length"
                                color: "#D8DBE2"
                                font.pointSize: 15
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 150
                            }

                            Timer {
                                function formatSeconds(totalSecondsInput) {
                                    var secs = totalSecondsInput;

                                    if (typeof secs !== 'number' || isNaN(secs) || secs < 0) {
                                        secs = 0;
                                    }
                                    secs = Math.floor(secs);

                                    var minutes = Math.floor(secs / 60);
                                    var seconds = secs % 60;

                                    var formattedMinutes = minutes.toString().padStart(2, '0');
                                    var formattedSeconds = seconds.toString().padStart(2, '0');

                                    return formattedMinutes + ":" + formattedSeconds;
                                }

                                interval: 1000
                                running: true
                                repeat: true
                                onTriggered: posDisplay.text = `${formatSeconds(Mpris.players.values[parent.parent.pIndex].position)}/${formatSeconds(Mpris.players.values[parent.parent.pIndex].length)}`
                            }

                            Text {
                                text: Mpris.players.values[parent.parent.pIndex].isPlaying ? "" : ""
                                color: "#D8DBE2"
                                font.pointSize: 40
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignTop
                                y: 200
                                x: 150
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { Mpris.players.values[parent.parent.parent.pIndex].togglePlaying() }
                                }
                            }

                            Text {
                                text: "󰒭"
                                color: "#D8DBE2"
                                font.pointSize: 35
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignTop
                                y: 205
                                x: 210
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { Mpris.players.values[parent.parent.parent.pIndex].next() }
                                }
                            }

                            Text {
                                text: "󰒮"
                                color: "#D8DBE2"
                                font.pointSize: 35
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignTop
                                y: 205
                                x: 90
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { Mpris.players.values[parent.parent.pIndex].previous() }
                                }
                            }
                        }

                        // Button container
                        Rectangle {
                            implicitWidth: 50
                            implicitHeight: 300
                            radius: implicitHeight / 5
                            color: "#A9BCD0"

                            // Buttons
                            Rectangle {
                                id: trayButton
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 8.75
                                implicitWidth: 35
                                implicitHeight: 35
                                radius: implicitWidth /2
                                color: "#96ADC5"

                                Text {
                                    id: trayIcon
                                    anchors.centerIn: parent
                                    color: "black"
                                    text: "󱊖"
                                    font.bold: true
                                    font.pointSize: 15
                                }
                            }

                            Rectangle {
                                id: mixerButton
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 68.75
                                implicitWidth: 35
                                implicitHeight: 35
                                radius: implicitWidth /2
                                color: "#96ADC5"

                                Text {
                                    id: mixerIcon
                                    anchors.centerIn: parent
                                    color: "black"
                                    text: ""
                                    font.bold: true
                                    font.pointSize: 15
                                }
                            }

                            Rectangle {
                                id: hubButton
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 125
                                implicitWidth: 45
                                implicitHeight: 45
                                radius: implicitWidth /2
                                color: "#89A2BE"

                                Text {
                                    id: hubIcon
                                    y: 2
                                    anchors.centerIn: parent
                                    color: "black"
                                    text: "󰣇"
                                    font.bold: true
                                    font.pointSize: 25
                                }
                            }

                            Rectangle {
                                id: toolButton
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 188.75
                                implicitWidth: 35
                                implicitHeight: 35
                                radius: implicitWidth /2
                                color: "#96ADC5"

                                Text {
                                    id: toolIcon
                                    anchors.centerIn: parent
                                    color: "black"
                                    text: "󱁤"
                                    font.bold: true
                                    font.pointSize: 15
                                }
                            }

                            Rectangle {
                                id: perfButton
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 248.75
                                implicitWidth: 35
                                implicitHeight: 35
                                radius: implicitWidth /2
                                color: "#96ADC5"

                                Text {
                                    id: perfIcon
                                    anchors.centerIn: parent
                                    color: "black"
                                    text: "󰄧"
                                    font.bold: true
                                    font.pointSize: 15
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: clickDetector
                    anchors.centerIn: parent
                    implicitWidth: 800
                    implicitHeight: 35

                    onClicked: { utilPanel.visible = !utilPanel.visible }                    
                }
            }
        }
        }
    }
}