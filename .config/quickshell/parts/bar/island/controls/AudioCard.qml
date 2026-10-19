// Output volume, mic and Bluetooth in one card: the output device, a level
// row each for output and mic, then a row of pills (mute, mic, Bluetooth with
// its connected count). The Bluetooth
// device list opens in place. Replaces the separate Volume and Bluetooth
// cards so the dashboard has room for the agents card.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "../../../theme"
import "../../../services"
import "../../../components"

Card {
    id: root

    padding: 12

    property bool showDevices: false

    // ── OVERVIEW ────────────────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        spacing: 6
        visible: opacity > 0
        opacity: root.showDevices ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

        // The output device, and the headset's battery when one reports it.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: AudioService.sinkDescription || "Output"
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                visible: HeadsetService.connected && HeadsetService.battery >= 0
                text: `${HeadsetService.charging ? "󰂄" : "󰥉"} ${HeadsetService.battery}%`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.features: { "tnum": 1 }
                color: HeadsetService.battery <= 15 ? Theme.indicatorBad : Theme.textMuted
            }
        }

        LevelRow {
            icon: AudioService.icon
            muted: AudioService.muted
            level: AudioService.volume
            onToggled: AudioService.toggleMute()
            onPicked: percent => AudioService.setVolume(percent)
        }

        LevelRow {
            icon: AudioService.sourceIcon
            muted: AudioService.sourceMuted
            level: AudioService.sourceVolume
            onToggled: AudioService.toggleSourceMute()
            onPicked: percent => AudioService.setSourceVolume(percent)
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            PillButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                icon: "󰝟"
                text: "Mute"
                active: AudioService.muted
                implicitHeight: 28
                onClicked: AudioService.toggleMute()
            }

            PillButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                icon: AudioService.sourceIcon
                text: "Mic"
                active: AudioService.sourceMuted
                implicitHeight: 28
                onClicked: AudioService.toggleSourceMute()
            }

            // Bluetooth on/off, with how many devices are connected.
            PillButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                icon: BluetoothService.icon
                text: !BluetoothService.enabled ? "Off"
                    : BluetoothService.connectedDevices.length > 0
                        ? `${BluetoothService.connectedDevices.length} on` : "On"
                active: BluetoothService.enabled
                implicitHeight: 28
                onClicked: BluetoothService.toggle()
            }

            PillButton {
                text: "›"
                implicitHeight: 28
                implicitWidth: 28
                horizontalPadding: 0
                onClicked: root.showDevices = true
            }
        }
    }

    // ── BLUETOOTH DEVICES ───────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        spacing: 6
        visible: opacity > 0
        opacity: root.showDevices ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

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
                text: "Bluetooth"
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

        ListView {
            id: devList

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 3
            model: BluetoothService.devices

            ScrollBar.vertical: ScrollBar {
                active: devList.moving || devList.flicking
                policy: ScrollBar.AsNeeded
            }

            delegate: Rectangle {
                id: devItem

                required property var modelData

                width: devList.width
                height: 24
                radius: Theme.radiusSmall
                color: modelData.connected
                    ? Theme.tintWash(Theme.accent, devMouse.containsMouse ? 0.16 : 0.08)
                    : devMouse.containsMouse ? Theme.rowHover : Theme.rowRest
                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: BluetoothService.deviceIcon(devItem.modelData)
                        font.family: Theme.fontMono
                        font.pixelSize: 12
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

                    Text {
                        text: devItem.modelData.connected ? "● On" : (devMouse.containsMouse ? "Connect" : "Paired")
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: devItem.modelData.connected
                            ? Theme.green : (devMouse.containsMouse ? Theme.accent : Theme.textMuted)
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

            Text {
                anchors.centerIn: parent
                visible: BluetoothService.devices.length === 0
                text: BluetoothService.enabled ? "No paired devices" : "Bluetooth is off"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }
        }
    }
}
