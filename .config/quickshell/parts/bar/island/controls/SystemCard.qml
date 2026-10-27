
import QtQuick
import QtQuick.Layouts

import "../../../theme"
import "../../../services"
import "../../../components"

// Temperatures warn in the fixed indicator hues, not the accent: yellow from
// `warmAt`, red from `hotAt` (the GPU hot spot runs hotter by design).
Card {
    id: root

    Component.onCompleted: void StatsService.ready

    readonly property int span: Math.round(60000 / StatsService.pollInterval)

    function recent(series: var): var {
        return series.slice(-root.span)
    }

    readonly property var cpuTemp: StatsService.temperature ? StatsService.temperature.celsius : null

    function degrees(value: var): string {
        return value === null || value === undefined ? "–" : `${Math.round(value)} °C`
    }

    function heat(value: var, warmAt: real, hotAt: real): color {
        if (value === null || value === undefined)
            return Theme.textMuted
        if (value >= hotAt)
            return Theme.indicatorBad
        return value >= warmAt ? Theme.indicatorWarn : Theme.text
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

            footerLabel: "Temperature"
            footerValue: root.degrees(root.cpuTemp)
            footerColor: root.heat(root.cpuTemp, 70, 85)
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

            footerLabel: StatsService.swapTotal > 0 ? "Swap used" : "Swap"
            footerValue: StatsService.swapTotal > 0
                ? StatsService.bytes(StatsService.swapUsed, 0) : "off"
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

            footerLabel: "Temperature"
            footerValue: root.degrees(StatsService.gpuTemperature)
            footerColor: root.heat(StatsService.gpuTemperature, 70, 85)
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

            footerLabel: "Free"
            footerValue: StatsService.bytes(Math.max(0, StatsService.vramTotal - StatsService.vramUsed))
        }
    }

    component Rule: Rectangle {
        Layout.fillHeight: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        Layout.preferredWidth: 1
        color: Theme.hairline
    }
}
