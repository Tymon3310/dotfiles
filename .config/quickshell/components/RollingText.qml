import QtQuick
import "../theme"

Item {
    id: root
    property string text: ""
    property color color: Theme.text
    property font font: Qt.font({
        family: Theme.fontFamily,
        pixelSize: Theme.fontSizeRegular,
        weight: Font.Medium
    })
    property int horizontalAlignment: Text.AlignLeft
    property int verticalAlignment: Text.AlignVCenter
    property bool marquee: true
    property real readingTime: 8
    property string currentText: ""
    property string outgoingText: ""
    property real travel: 1
    property real scrollOffset: 0
    property real outgoingOffset: 0
    property bool initialized: false
    property int readingDuration: 4000
    readonly property real overflow: Math.max(0, currentLabel.implicitWidth - width)
    clip: true

    function reconcile(): void {
        if (!initialized || text === currentText) return;
        if (roll.running) {
            currentText = text;
            scrollOffset = 0;
            return;
        }
        scroll.stop();
        scrollDelay.stop();
        outgoingText = currentText;
        outgoingOffset = scrollOffset;
        currentText = text;
        scrollOffset = 0;
        if (!visible || !outgoingText || !text) {
            travel = 1;
            outgoingText = "";
            scrollDelay.restart();
            return;
        }
        travel = 0;
        roll.start();
    }

    onTextChanged: Qt.callLater(reconcile)
    onOverflowChanged: {
        scroll.stop();
        scrollOffset = 0;
        scrollDelay.restart();
    }
    onVisibleChanged: {
        if (visible) {
            reconcile();
            scrollDelay.restart();
        } else {
            roll.stop();
            scroll.stop();
            scrollDelay.stop();
            currentText = text;
            outgoingText = "";
            travel = 1;
            scrollOffset = 0;
        }
    }

    Component.onCompleted: {
        currentText = text;
        initialized = true;
        scrollDelay.restart();
    }

    NumberAnimation {
        id: roll
        target: root
        property: "travel"
        to: 1
        duration: Theme.durationMedium
        easing.type: Easing.InOutCubic
        onFinished: {
            root.outgoingText = "";
            Qt.callLater(root.reconcile);
            scrollDelay.restart();
        }
    }

    Timer {
        id: scrollDelay
        interval: 800
        onTriggered: {
            if (root.visible && root.marquee && !roll.running && root.overflow > 1) {
                root.readingDuration = Math.max(900, Math.min(root.overflow / 25 * 1000, 8000));
                scroll.restart();
            }
        }
    }

    SequentialAnimation {
        id: scroll
        NumberAnimation {
            target: root
            property: "scrollOffset"
            to: root.overflow
            duration: root.readingDuration
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 1200 }
        NumberAnimation {
            target: root
            property: "scrollOffset"
            to: 0
            duration: Theme.durationFast
            easing.type: Easing.InOutCubic
        }
        PauseAnimation { duration: 1000 }
        onFinished: if (root.visible && root.overflow > 1) scrollDelay.restart()
    }

    Text {
        id: outgoingLabel
        width: parent.width
        height: parent.height
        y: -parent.height * root.travel
        x: -root.outgoingOffset
        visible: root.outgoingText !== "" && root.travel < 1
        text: root.outgoingText
        font: root.font
        color: root.color
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: root.verticalAlignment
        elide: root.marquee ? Text.ElideNone : Text.ElideRight
    }

    Text {
        id: currentLabel
        width: parent.width
        height: parent.height
        y: parent.height * (1 - root.travel)
        x: -root.scrollOffset
        text: root.currentText
        font: root.font
        color: root.color
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: root.verticalAlignment
        elide: root.marquee ? Text.ElideNone : Text.ElideRight
    }
}
