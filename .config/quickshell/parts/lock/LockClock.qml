import QtQuick
import Quickshell

import "../theme"
import "../services"

// The lock's clock: date above, then large clean time scaled to screen resolution.
Item {
    id: root

    property int screenHeight: 1080
    property string style: SettingsService.lockClock // "inline" or "stacked"
    readonly property bool stacked: root.style === "stacked"

    readonly property int dateSize: Math.max(16, Math.round(screenHeight * 0.018))
    readonly property int inlineSize: Math.max(72, Math.round(screenHeight * 0.088))
    readonly property int stackedSize: Math.max(80, Math.round(screenHeight * 0.10))
    readonly property int stackedGap: 8

    readonly property date now: clock.date
    readonly property string time: Qt.formatDateTime(root.now, SettingsService.clockFormat || "HH:mm")
    readonly property var parts: root.time.split(":")

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.stacked ? root.stackedGap : -Math.round(root.inlineSize * 0.04)

        // Date
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "dddd, d MMMM")
            font.family: Theme.fontFamily
            font.pixelSize: root.dateSize
            font.weight: Font.DemiBold
            color: Theme.text
            opacity: 0.9
        }

        // Inline Time
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.stacked
            text: root.time
            font.family: Theme.fontFamily
            font.pixelSize: root.inlineSize
            font.weight: Font.Bold
            font.letterSpacing: -2
            font.features: { "tnum": 1 }
            color: Theme.text
        }

        // Stacked Time (Hours over Minutes)
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.stacked
            spacing: -Math.round(root.stackedSize * 0.28)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.parts[0] ?? ""
                font.family: Theme.fontFamily
                font.pixelSize: root.stackedSize
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: Theme.text
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.parts.slice(1).join(":")
                font.family: Theme.fontFamily
                font.pixelSize: root.stackedSize
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: Theme.text
                opacity: 0.55
            }
        }
    }
}
