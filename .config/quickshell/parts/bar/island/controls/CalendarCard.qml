
import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

Card {
    id: root

    // Weeks start on Monday; JavaScript counts from Sunday, hence the shift
    // wherever a weekday index is used.
    readonly property var weekdays: ["M", "T", "W", "T", "F", "S", "S"]

    // Ticks at midnight; nothing here changes sooner.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property date today: clock.date

    // Months away from the current one; the header offers a way back when
    // nonzero.
    property int offsetMonths: 0

    readonly property date shown:
        new Date(root.today.getFullYear(), root.today.getMonth() + root.offsetMonths, 1)

    readonly property int year: root.shown.getFullYear()
    readonly property int month: root.shown.getMonth()

    readonly property int daysInMonth: new Date(root.year, root.month + 1, 0).getDate()
    readonly property int daysInPrevious: new Date(root.year, root.month, 0).getDate()

    // Column of the 1st, with Sunday moved to the end.
    readonly property int leadingBlanks: (new Date(root.year, root.month, 1).getDay() + 6) % 7

    // Today is only marked in its own month.
    readonly property bool showingThisMonth: root.offsetMonths === 0

    // Reset to the current month whenever the card is rebuilt.
    Component.onCompleted: root.offsetMonths = 0

    property int lastOffset: 0
    onOffsetMonthsChanged: {
        const forward = root.offsetMonths > root.lastOffset
        root.lastOffset = root.offsetMonths
        monthSlide.from = forward ? 28 : -28
        monthSlide.restart()
        monthFade.restart()
    }


    ColumnLayout {
        anchors.fill: parent
        spacing: 9

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: Qt.formatDateTime(root.shown, "MMMM")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                text: root.year
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.textMuted
            }

            Item { Layout.fillWidth: true }

            // Today's weekday while showing the current month, otherwise a way
            // back to it.
            Text {
                text: Qt.formatDateTime(root.today, "dddd")
                visible: root.showingThisMonth
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }

            PillButton {
                visible: !root.showingThisMonth
                text: "Today"
                implicitHeight: 22
                horizontalPadding: 9
                onClicked: root.offsetMonths = 0
            }

            IconButton {
                icon: "󰅁"
                iconSize: 12
                implicitWidth: 24
                implicitHeight: 22
                onClicked: root.offsetMonths -= 1
            }

            IconButton {
                icon: "󰅂"
                iconSize: 12
                implicitWidth: 24
                implicitHeight: 22
                onClicked: root.offsetMonths += 1
            }
        }

        GridLayout {
            id: grid

            transform: Translate { id: gridShift }

            NumberAnimation {
                id: monthSlide
                target: gridShift
                property: "x"
                to: 0
                duration: Theme.durationEnter
                easing.type: Theme.easingSpring
                easing.overshoot: Theme.springOvershoot
            }

            NumberAnimation {
                id: monthFade
                target: grid
                property: "opacity"
                from: 0.2
                to: 1
                duration: Theme.durationMedium
                easing.type: Easing.OutCubic
            }

            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: 2
            columnSpacing: 2

            // Wheel pages the month. A WheelHandler, not a MouseArea: a
            // GridLayout would give an Item child a cell and shift every day by
            // one.
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    root.offsetMonths += event.angleDelta.y < 0 ? 1 : -1
                }
            }

            Repeater {
                model: root.weekdays

                Text {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 18
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.weight: Font.DemiBold
                    color: Theme.textMuted
                }
            }

            // Always 42 cells, so the card height doesn't change between five-
            // and six-row months.
            Repeater {
                model: 42

                Item {
                    id: cell

                    required property int index

                    readonly property int offset: cell.index - root.leadingBlanks
                    readonly property bool inMonth: cell.offset >= 0 && cell.offset < root.daysInMonth
                    readonly property int day: {
                        if (cell.offset < 0)
                            return root.daysInPrevious + cell.offset + 1
                        if (cell.offset >= root.daysInMonth)
                            return cell.offset - root.daysInMonth + 1
                        return cell.offset + 1
                    }
                    readonly property bool isToday: cell.inMonth
                        && root.showingThisMonth
                        && cell.day === root.today.getDate()

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 1

                    HoverHandler { id: cellHover }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(34, parent.width, parent.height)
                        height: width
                        radius: width / 2
                        color: cell.isToday ? Theme.accent
                            : cellHover.hovered && cell.inMonth ? Theme.islandSurfaceHover : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                        Text {
                            anchors.centerIn: parent
                            text: cell.day
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                            color: {
                                if (cell.isToday)
                                    return Theme.accentText
                                return cell.inMonth ? Theme.text : Theme.textMuted
                            }
                            opacity: cell.inMonth ? 1 : 0.35
                        }
                    }
                }
            }
        }
    }
}
