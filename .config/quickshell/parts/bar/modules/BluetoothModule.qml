// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B L U E T O O T H   M O D U L E                                        │
// │   bluetooth · connected devices, radio switch, device menu & pairing     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "../../theme"
import "../../services"
import "../../components"

Item {
    id: root

    property bool compact: false
    property bool showDevices: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    Component {
        id: chip

        Item {
            Item {
                id: mark

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.capsuleHeight
                height: Theme.capsuleHeight

                RingIndicator {
                    anchors.fill: parent
                    thickness: 2.5
                    progress: 0
                    trackColor: Theme.indicatorDim

                    Text {
                        anchors.centerIn: parent
                        text: BluetoothService.icon
                        font.family: Theme.fontMono
                        font.pixelSize: Math.round(Theme.capsuleHeight * 0.4)
                        color: BluetoothService.enabled
                            ? Theme.indicator : Theme.textMuted
                    }
                }
            }
        }
    }

    Component {
        id: detail

        Item {
            anchors.fill: parent

            // ── OVERVIEW VIEW ───────────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                spacing: 12
                visible: !root.showDevices
                opacity: root.showDevices ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 13

                    RingIndicator {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        thickness: 2.5
                        progress: 0
                        trackColor: Theme.indicatorDim

                        Text {
                            anchors.centerIn: parent
                            text: BluetoothService.icon
                            font.family: Theme.fontMono
                            font.pixelSize: 18
                            color: BluetoothService.enabled
                                ? Theme.indicator : Theme.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: BluetoothService.toggle()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: BluetoothService.summary
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (!BluetoothService.enabled)
                                    return "Adapter off"
                                const count = BluetoothService.connectedDevices.length
                                if (count === 0)
                                    return "On · nothing connected"
                                return count === 1
                                    ? "On · 1 device connected"
                                    : `On · ${count} devices connected`
                            }
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }
                    }

                    IconButton {
                        icon: "󰒓"
                        iconSize: 14
                        onClicked: BluetoothService.openManager()
                    }

                    PillButton {
                        text: "Menu ›"
                        implicitHeight: 28
                        onClicked: root.showDevices = true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    // Clickable figure to open the device menu
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        radius: Theme.radiusSmall
                        color: figureMouse.containsMouse ? Theme.islandSurfaceHover : "transparent"
                        border.width: 1
                        border.color: figureMouse.containsMouse ? Theme.islandBorder : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                        MouseArea {
                            id: figureMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton)
                                    BluetoothService.openManager()
                                else
                                    root.showDevices = true
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: figureMouse.containsMouse ? 4 : 0
                            spacing: 1
                            Behavior on anchors.leftMargin { NumberAnimation { duration: Theme.durationFast } }

                            Text {
                                text: "DEVICES"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.6
                                color: Theme.textMuted
                            }

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: `${BluetoothService.connectedDevices.length}`
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.DemiBold
                                    color: BluetoothService.connectedDevices.length > 0 ? Theme.accent : Theme.text
                                }
                                Text {
                                    text: `/ ${BluetoothService.devices.length} paired`
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.textMuted
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: figureMouse.containsMouse ? "Click to open menu ›" : "pairing lives in the control centre"
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: figureMouse.containsMouse ? Theme.accent : Theme.textMuted
                            }
                        }
                    }

                    PillButton {
                        Layout.alignment: Qt.AlignVCenter
                        text: "Bluetooth"
                        active: BluetoothService.enabled
                        implicitHeight: 28
                        onClicked: BluetoothService.toggle()
                    }
                }
            }

            // ── DEVICE MENU VIEW ────────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6
                visible: root.showDevices
                opacity: root.showDevices ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                // Menu Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    PillButton {
                        text: "‹ Back"
                        implicitHeight: 24
                        horizontalPadding: 8
                        onClicked: root.showDevices = false
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Bluetooth Devices"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall + 1
                        font.weight: Font.DemiBold
                        color: Theme.text
                        elide: Text.ElideRight
                    }

                    IconButton {
                        icon: "󰒓"
                        iconSize: 13
                        implicitHeight: 24
                        implicitWidth: 26
                        onClicked: BluetoothService.openManager()
                    }
                }

                // Scrollable device list
                ListView {
                    id: devList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: BluetoothService.devices

                    ScrollBar.vertical: ScrollBar {
                        active: devList.moving || devList.flicking
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Rectangle {
                        id: devItem
                        required property var modelData
                        required property int index

                        width: devList.width
                        height: 28
                        radius: Theme.radiusSmall
                        color: devMouse.containsMouse
                            ? Theme.islandSurfaceHover
                            : (modelData.connected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08) : "transparent")
                        border.width: 1
                        border.color: devMouse.containsMouse
                            ? Theme.islandBorder
                            : (modelData.connected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : "transparent")

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                text: BluetoothService.deviceIcon(devItem.modelData)
                                font.family: Theme.fontMono
                                font.pixelSize: 13
                                color: devItem.modelData.connected ? Theme.accent : Theme.textMuted
                            }

                            Text {
                                Layout.fillWidth: true
                                text: devItem.modelData.name || devItem.modelData.address || "Unknown"
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: devItem.modelData.connected ? Font.DemiBold : Font.Normal
                                color: devItem.modelData.connected ? Theme.text : Theme.textMuted
                            }

                            // Status badge
                            Text {
                                text: devItem.modelData.connected ? "● Connected" : (devMouse.containsMouse ? "Connect" : "Paired")
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: devItem.modelData.connected
                                    ? Theme.green
                                    : (devMouse.containsMouse ? Theme.accent : Theme.textMuted)
                            }
                        }

                        MouseArea {
                            id: devMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: BluetoothService.connectDevice(devItem.modelData)
                        }
                    }

                    // Empty state when no paired devices
                    Item {
                        anchors.fill: parent
                        visible: BluetoothService.devices.length === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: BluetoothService.enabled ? "No paired devices found" : "Bluetooth is turned off"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.textMuted
                            }

                            PillButton {
                                Layout.alignment: Qt.AlignHCenter
                                text: BluetoothService.enabled ? "Open Blueman to Pair" : "Turn On Bluetooth"
                                implicitHeight: 24
                                onClicked: {
                                    if (BluetoothService.enabled)
                                        BluetoothService.openManager()
                                    else
                                        BluetoothService.toggle()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
