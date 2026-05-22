import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    property var parentWindow: null
    property date selectedDate: new Date()
    property bool hovered: calHoverHandler.hovered
    
    readonly property string customFont: "Google Sans Code NF"

    HoverHandler {
        id: calHoverHandler
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Header (Prev, Current Month/Year, Next)
        RowLayout {
            Layout.fillWidth: true
            
            Button {
                text: "◀"
                flat: true
                Layout.preferredWidth: 32
                Layout.preferredHeight: 24
                onClicked: {
                    var d = new Date(root.selectedDate);
                    d.setMonth(d.getMonth() - 1);
                    root.selectedDate = d;
                }
                background: Rectangle {
                    color: parent.hovered ? "#1AFFFFFF" : "transparent"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    font.family: root.customFont
                    font.pixelSize: 11
                    color: "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                text: root.selectedDate.toLocaleString(Qt.locale("en_US"), "MMMM yyyy")
                font.family: root.customFont
                font.pixelSize: 11
                font.bold: true
                color: "#FFFFFF"
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Button {
                text: "▶"
                flat: true
                Layout.preferredWidth: 32
                Layout.preferredHeight: 24
                onClicked: {
                    var d = new Date(root.selectedDate);
                    d.setMonth(d.getMonth() + 1);
                    root.selectedDate = d;
                }
                background: Rectangle {
                    color: parent.hovered ? "#1AFFFFFF" : "transparent"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    font.family: root.customFont
                    font.pixelSize: 11
                    color: "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Weekdays Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                delegate: Text {
                    text: modelData
                    font.family: root.customFont
                    font.pixelSize: 9
                    font.bold: true
                    color: (modelData === "Sa" || modelData === "Su") ? "#ff3b30" : "#99FFFFFF"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Month Grid of Days
        MonthGrid {
            id: monthGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            month: root.selectedDate.getMonth()
            year: root.selectedDate.getFullYear()
            locale: Qt.locale("en_US")

            delegate: Rectangle {
                required property date date
                required property bool today
                required property int month
                required property int day

                color: {
                    var todayStr = new Date().toDateString();
                    if (date.toDateString() === todayStr) return "#0070D8";
                    if (date.toDateString() === root.selectedDate.toDateString()) return "#26FFFFFF";
                    return "transparent";
                }
                
                radius: 4
                border.color: today ? "#0070D8" : "transparent"
                border.width: 1

                Text {
                    text: day
                    anchors.centerIn: parent
                    font.family: root.customFont
                    font.pixelSize: 9
                    color: {
                        var todayStr = new Date().toDateString();
                        if (date.toDateString() === todayStr) return "#FFFFFF";
                        if (month !== monthGrid.month) return "#40FFFFFF";
                        return "#FFFFFF";
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selectedDate = model.date;
                    }
                }
            }
        }
    }
}
