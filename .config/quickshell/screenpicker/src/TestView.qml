import Quickshell
import Quickshell.Wayland
import QtQuick

ScreencopyView {
    property var source
    captureSource: source
    Component.onCompleted: console.log("ScreencopyView created with source: " + source)
}
