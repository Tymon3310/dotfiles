import QtQuick
import "../theme"

Item {
    id: root
    property string text: ""
    property font font: Qt.font({
        family: Theme.fontFamily,
        pixelSize: Theme.fontSizeRegular,
        weight: Font.Medium,
        features: { tnum: 1 }
    })
    property color color: Theme.text
    property bool animated: true

    TextMetrics {
        id: sampleMetrics
        font: root.font
        text: "0"
    }

    width: row.implicitWidth
    height: sampleMetrics.height > 0 ? sampleMetrics.height : 18

    Row {
        id: row
        anchors.centerIn: parent
        height: root.height

        Repeater {
            model: root.text.length
            Item {
                id: digit
                required property int index
                property string value: root.text.charAt(index)
                property string shown: value
                property string outgoing: ""
                property real progress: 1
                property bool ready: false

                width: digitMetrics.advanceWidth
                height: root.height
                clip: true

                TextMetrics {
                    id: digitMetrics
                    font: root.font
                    text: /\d/.test(digit.value) ? "0" : digit.value
                }

                function update(): void {
                    if (!ready || motion.running || value === shown) return;
                    if (!root.animated || !visible || !/\d/.test(value)) {
                        shown = value;
                        outgoing = "";
                        progress = 1;
                        return;
                    }
                    outgoing = shown;
                    shown = value;
                    progress = 0;
                    motion.start();
                }

                onValueChanged: update()
                onVisibleChanged: {
                    if (!visible) {
                        motion.stop();
                        shown = value;
                        outgoing = "";
                        progress = 1;
                    }
                }

                Component.onCompleted: {
                    shown = value;
                    outgoing = "";
                    progress = 1;
                    ready = true;
                }

                NumberAnimation {
                    id: motion
                    target: digit
                    property: "progress"
                    to: 1
                    duration: Theme.durationMedium
                    easing.type: Easing.OutCubic
                    onFinished: {
                        digit.outgoing = "";
                        Qt.callLater(digit.update);
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: parent.height
                    y: -parent.height * digit.progress
                    visible: digit.outgoing !== ""
                    text: digit.outgoing
                    font: root.font
                    color: root.color
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: parent.height
                    y: parent.height * (1 - digit.progress)
                    text: digit.shown
                    font: root.font
                    color: root.color
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
