// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S Y S T E M   C A R D                                                  │
// │   processor, memory, graphics and video memory, side by side             │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../../theme"
import "../../../services"
import "../../../components"

// Four of impasto's StatCards in a row, each with its last minute as a line
// behind the reading (StatsService, sampled every half second). The GPU pair
// is left out on a machine whose GPU reports no load.
//
// Temperatures warn in the fixed indicator hues, not the accent: yellow from
// `warmAt`, red from `hotAt` (the GPU hot spot runs hotter by design).
Card {
    id: root

    Component.onCompleted: void StatsService.ready

    // The last minute of the five kept.
    readonly property int span: Math.round(60000 / StatsService.pollInterval)

    function recent(series: var): var {
        return series.slice(-root.span)
    }

    function degrees(value: var): string {
        return value === null || value === undefined ? "–" : `${Math.round(value)} °C`
    }

    function heat(value: var, warmAt: real, hotAt: real): color {
        if (value === null || value === undefined)
            return Theme.textMuted
        if (value >= hotAt)
            return Theme.indicatorBad
        return value >= warmAt ? Theme.indicatorWarn : Theme.textMuted
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        StatCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            bare: true
            icon: "󰻠"
            title: "Processor"
            reading: `${StatsService.cpu.toFixed(0)}%`
            detail: `load ${StatsService.load[0].toFixed(2)}`
            series: root.recent(StatsService.cpuHistory)
            accent: Theme.accent

            Temperature {
                value: StatsService.temperature ? StatsService.temperature.celsius : null
                warmAt: 70
                hotAt: 85
            }
        }

        Rule {}

        StatCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            bare: true
            icon: "󰍛"
            title: "Memory"
            reading: `${(StatsService.memoryFraction * 100).toFixed(0)}%`
            detail: `${StatsService.bytes(StatsService.memoryUsed)} of ${StatsService.bytes(StatsService.memoryTotal)}`
            series: root.recent(StatsService.memoryHistory)
            accent: Theme.blue
        }

        Rule { visible: StatsService.gpuAvailable }

        StatCard {
            visible: StatsService.gpuAvailable
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            bare: true
            icon: "󰢮"
            title: "Graphics"
            reading: `${StatsService.gpu.toFixed(0)}%`
            detail: StatsService.gpuJunction !== null
                ? `hot spot ${root.degrees(StatsService.gpuJunction)}` : ""
            series: root.recent(StatsService.gpuHistory)
            accent: Theme.green

            Temperature {
                value: StatsService.gpuTemperature
                warmAt: 70
                hotAt: 85
            }
        }

        Rule { visible: StatsService.gpuAvailable }

        StatCard {
            visible: StatsService.gpuAvailable
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            bare: true
            icon: "󰘚"
            title: "Vram"
            reading: StatsService.bytes(StatsService.vramUsed)
            detail: `of ${StatsService.bytes(StatsService.vramTotal, 0)} · ${(StatsService.vramFraction * 100).toFixed(0)}%`
            series: root.recent(StatsService.vramHistory)
            accent: Theme.yellow
        }
    }

    // A thin divider between the readings.
    component Rule: Rectangle {
        Layout.fillHeight: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        Layout.preferredWidth: 1
        color: Theme.hairline
    }

    // A temperature under the reading, tinted when warm.
    component Temperature: Text {
        property var value: null
        property real warmAt: 70
        property real hotAt: 85

        text: root.degrees(value)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        color: root.heat(value, warmAt, hotAt)

        Behavior on color { ColorAnimation { duration: Theme.durationMedium } }
    }
}
