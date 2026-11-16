import QtQuick
import QtQuick.Layouts

import "../theme"

Card {
    id: root

    property string icon: ""
    property string title: ""
    property string reading: ""
    property string detail: ""
    property var series: []
    property real maximum: 1
    property color accent: Theme.accent

    // The bottom row: a muted label and its value on the right. The row
    // keeps its height when empty, so neighbouring cards stay aligned.
    property string footerLabel: ""
    property string footerValue: ""
    property color footerColor: Theme.text

    padding: 0

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            Text {
                text: root.icon
                font.family: Theme.fontMono
                font.pixelSize: 15
                color: root.accent
            }

            Text {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                text: root.reading
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Theme.text
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.detail
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            font.features: { "tnum": 1 }
            color: Theme.textMuted
        }

        Sparkline {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 4
            Layout.rightMargin: 3
            values: root.series
            maximum: root.maximum
            stroke: root.accent
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 15
            spacing: 6

            Text {
                text: root.footerLabel
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                color: Theme.textMuted
            }

            // The value gives way, not the label.
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
                text: root.footerValue
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: root.footerColor

                Behavior on color { ColorAnimation { duration: Theme.durationMedium } }
            }
        }
    }
}
