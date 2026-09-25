import QtQuick
import QtQuick.Layouts

import "../parts/theme"
import "../parts/components"
import "../parts/bar/modules"
import "../parts/bar/island"
import "../parts/bar/island/controls"

// Everything the island opens, in one board. Built only while it is open.
//
//   calendar      player and lyrics    weather / notifications
//   volume        speed and pings      bluetooth
//   system (cpu, memory, gpu, vram)    session
//
// Fixed size, so the island can grow to it before it is built.
GridLayout {
    id: root

    signal closed()

    readonly property int gap: 12
    readonly property int leftWidth: 320
    readonly property int middleWidth: 380
    readonly property int rightWidth: 360
    readonly property int firstHeight: 420
    readonly property int secondHeight: 132
    readonly property int thirdHeight: 148

    readonly property int boardWidth: root.leftWidth + root.middleWidth + root.rightWidth + 2 * root.gap
    readonly property int boardHeight: root.firstHeight + root.secondHeight + root.thirdHeight + 2 * root.gap

    columns: 3
    rowSpacing: root.gap
    columnSpacing: root.gap

    // ── FIRST ROW ───────────────────────────────────────────────────────────

    CalendarCard {
        Layout.preferredWidth: root.leftWidth
        Layout.preferredHeight: root.firstHeight
    }

    // The whole column: lyrics need the height.
    MediaCard {
        Layout.preferredWidth: root.middleWidth
        Layout.preferredHeight: root.firstHeight
    }

    ColumnLayout {
        Layout.preferredWidth: root.rightWidth
        Layout.preferredHeight: root.firstHeight
        spacing: root.gap

        WeatherCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 182
        }

        NotificationList {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    // ── SECOND ROW ──────────────────────────────────────────────────────────

    Tile { moduleId: "volume"; Layout.preferredWidth: root.leftWidth }
    // Wired only: throughput and pings instead of the Wi-Fi detail.
    LinkCard {
        Layout.preferredWidth: root.middleWidth
        Layout.preferredHeight: root.secondHeight
    }
    Tile { moduleId: "bluetooth"; Layout.preferredWidth: root.rightWidth }

    // ── THIRD ROW ───────────────────────────────────────────────────────────

    // Processor, memory, graphics and video memory, with temperatures.
    SystemCard {
        Layout.columnSpan: 2
        Layout.preferredWidth: root.leftWidth + root.gap + root.middleWidth
        Layout.preferredHeight: root.thirdHeight
    }

    SessionPanel {
        Layout.preferredWidth: root.rightWidth
        Layout.preferredHeight: root.thirdHeight
        onClosed: root.closed()
    }

    // A module's island detail on a card; the details pad themselves.
    component Tile: Card {
        property alias moduleId: module.moduleId

        padding: 0
        Layout.preferredHeight: root.secondHeight

        Module {
            id: module
            anchors.fill: parent
            compact: false
        }
    }
}
