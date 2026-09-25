// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L I N K   C A R D                                                      │
// │   throughput and round trips, for a wired machine                        │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../../theme"
import "../../../services"
import "../../../components"

// Down and up rates with their last minute as a line (StatsService, physical
// interfaces only), and a round trip to each of PingService's hosts. Pings run
// only while the card exists.
Card {
    id: root

    Component.onCompleted: PingService.subscribe()
    Component.onDestruction: PingService.release()

    // The last minute of the five kept, so the line moves visibly.
    readonly property int span: Math.round(60000 / StatsService.pollInterval)

    RowLayout {
        anchors.fill: parent
        spacing: 16

        // ── THROUGHPUT ──────────────────────────────────────────────────────

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            Repeater {
                model: [
                    { glyph: "󰇚", label: "DOWN", value: StatsService.networkDown,
                      series: StatsService.downHistory, stroke: Theme.accent },
                    { glyph: "󰕒", label: "UP", value: StatsService.networkUp,
                      series: StatsService.upHistory, stroke: Theme.green }
                ]

                ColumnLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: modelData.glyph
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                            color: modelData.stroke
                        }

                        Text {
                            text: modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            font.weight: Font.DemiBold
                            color: Theme.textMuted
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: StatsService.rate(modelData.value)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            color: Theme.text
                        }
                    }

                    Sparkline {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        values: modelData.series.slice(-root.span)
                        maximum: 0
                        stroke: modelData.stroke
                        showDot: false
                    }
                }
            }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: Theme.hairline
        }

        // ── ROUND TRIPS ─────────────────────────────────────────────────────

        ColumnLayout {
            Layout.preferredWidth: 150
            Layout.fillHeight: true
            spacing: 0

            Text {
                text: "PING"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.weight: Font.DemiBold
                color: Theme.textMuted
            }

            Repeater {
                model: PingService.hosts

                RowLayout {
                    id: host

                    required property var modelData

                    readonly property var result: PingService.results[host.modelData.id]
                    readonly property string tint: PingService.tint(host.modelData.id)

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 7

                    Rectangle {
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: 3
                        color: !host.result ? Theme.indicatorDim
                            : host.tint === "good" ? Theme.indicatorGood
                            : host.tint === "warn" ? Theme.indicatorWarn : Theme.indicatorBad
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: -1

                        Text {
                            text: host.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.text
                        }

                        Text {
                            text: host.modelData.address
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            color: Theme.textMuted
                        }
                    }

                    Text {
                        text: {
                            if (!host.result)
                                return "…"
                            if (host.result.lost)
                                return "lost"
                            return `${host.result.ms < 10 ? host.result.ms.toFixed(1) : Math.round(host.result.ms)} ms`
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: host.result && host.result.lost ? Theme.red : Theme.text
                    }
                }
            }
        }
    }
}
