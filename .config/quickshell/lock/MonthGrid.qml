import QtQuick

// A month as a grid: the month's name, the weekdays (Monday first), and six
// weeks of days with today marked. Plain QtQuick only, so the same file
// serves the lock screen and the SDDM theme (a copy lives in
// sddm/themes/nocturne/components/; keep the two the same).
Item {
    id: root

    property date today: new Date()
    property int cell: 48
    property string fontFamily: "Google Sans"
    property color textColor: "white"
    property color accentColor: "#0a84ff"
    property color accentTextColor: "white"

    readonly property int year: root.today.getFullYear()
    readonly property int month: root.today.getMonth()
    readonly property int daysInMonth: new Date(root.year, root.month + 1, 0).getDate()
    readonly property int daysInPrevious: new Date(root.year, root.month, 0).getDate()
    // Column of the 1st, Monday first.
    readonly property int leadingBlanks: (new Date(root.year, root.month, 1).getDay() + 6) % 7
    readonly property var weekdays: ["M", "T", "W", "T", "F", "S", "S"]

    implicitWidth: root.cell * 7
    implicitHeight: column.implicitHeight

    Column {
        id: column

        width: root.cell * 7
        spacing: Math.round(root.cell * 0.25)

        Text {
            x: Math.round(root.cell * 0.18)
            text: Qt.formatDateTime(root.today, "MMMM")
            font.family: root.fontFamily
            font.pixelSize: Math.round(root.cell * 0.5)
            font.weight: Font.DemiBold
            color: root.textColor
        }

        Grid {
            columns: 7

            Repeater {
                model: root.weekdays

                Text {
                    required property string modelData
                    required property int index
                    width: root.cell
                    height: Math.round(root.cell * 0.6)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    font.family: root.fontFamily
                    font.pixelSize: Math.round(root.cell * 0.27)
                    font.weight: Font.DemiBold
                    color: root.textColor
                    opacity: index >= 5 ? 0.35 : 0.5
                }
            }

            Repeater {
                model: 42

                Item {
                    id: day

                    required property int index

                    readonly property int offset: day.index - root.leadingBlanks
                    readonly property bool inMonth: day.offset >= 0 && day.offset < root.daysInMonth
                    readonly property int number: day.offset < 0
                        ? root.daysInPrevious + day.offset + 1
                        : day.offset >= root.daysInMonth
                            ? day.offset - root.daysInMonth + 1
                            : day.offset + 1
                    readonly property bool isToday: day.inMonth && day.number === root.today.getDate()
                    readonly property bool weekend: day.index % 7 >= 5

                    width: root.cell
                    height: root.cell

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(root.cell * 0.78)
                        height: width
                        radius: width / 2
                        color: root.accentColor
                        visible: day.isToday
                    }

                    Text {
                        anchors.centerIn: parent
                        text: day.number
                        font.family: root.fontFamily
                        font.pixelSize: Math.round(root.cell * 0.34)
                        font.weight: day.isToday ? Font.DemiBold : Font.Normal
                        font.features: { "tnum": 1 }
                        color: day.isToday ? root.accentTextColor : root.textColor
                        opacity: day.isToday ? 1 : !day.inMonth ? 0.18 : day.weekend ? 0.55 : 0.85
                    }
                }
            }
        }
    }
}
