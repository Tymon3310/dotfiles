import QtQuick

// Mode controls and AI prompt on the primary screen.
Rectangle {
    id: bottomNotch

    required property var controller
    required property bool frozen
    required property bool primary
    visible: bottomNotch.frozen && bottomNotch.primary
    z: 10
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom

    property real notchOffset: bottomNotch.frozen ? 0 : height
    anchors.bottomMargin: -notchOffset

    width: mainRow.implicitWidth + 36
    height: 52
    color: Theme.island

    topLeftRadius: Theme.radiusLarge
    topRightRadius: Theme.radiusLarge
    bottomLeftRadius: 0
    bottomRightRadius: 0

    Behavior on notchOffset {
        NumberAnimation {
            duration: Theme.durationMorph
            easing.type: Theme.easing
        }
    }
    Behavior on width {
        NumberAnimation {
            duration: Theme.durationFast
            easing.type: Theme.easing
        }
    }

    Row {
        id: mainRow
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        spacing: 12

        Row {
            id: buttonRow
            spacing: 4

            Repeater {
                model: bottomNotch.controller.modes

                Rectangle {
                    id: modeBtn
                    required property var modelData
                    readonly property bool active: bottomNotch.controller.mode === modelData.mode

                    implicitWidth: 48
                    implicitHeight: 40
                    radius: Theme.radiusMedium - 2

                    color: active
                        ? Theme.accent
                        : (btnMouse.containsMouse ? Theme.islandSurfaceHover : "transparent")
                    border.color: active
                        ? Theme.accent
                        : (btnMouse.containsMouse ? Theme.islandBorder : "transparent")
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 18
                            height: 18
                            sourceSize: Qt.size(48, 48)
                            source: Qt.resolvedUrl(`../icons/${modeBtn.modelData.icon}.svg`)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            antialiasing: true
                            opacity: modeBtn.active ? 1.0 : (btnMouse.containsMouse ? 0.9 : 0.65)
                            Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modeBtn.modelData.label
                            color: modeBtn.active ? Theme.accentText : (btnMouse.containsMouse ? Theme.text : Theme.textMuted)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            font.weight: modeBtn.active ? Font.DemiBold : Font.Normal
                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        }
                    }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bottomNotch.controller.mode = modeBtn.modelData.mode
                    }
                }
            }
        }

        Rectangle {
            width: 1
            height: 22
            color: Theme.islandBorder
            anchors.verticalCenter: parent.verticalCenter
        }

        // Options panel with fixed width to prevent layout shifts
        Item {
            id: optionsPanel
            width: 320
            height: 40
            anchors.verticalCenter: parent.verticalCenter

            // Save toggle - for region/window/screen modes
            Row {
                id: saveRow
                opacity: (bottomNotch.controller.mode === "region" || bottomNotch.controller.mode === "window" || bottomNotch.controller.mode === "screen") ? 1 : 0
                visible: opacity > 0
                spacing: 10
                anchors.verticalCenter: parent.verticalCenter

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: "Save to disk"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        id: saveToggle
                        width: 36
                        height: 20
                        radius: height / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: bottomNotch.controller.saveToDisk ? Theme.accent : Theme.islandSurfaceHover
                        border.color: bottomNotch.controller.saveToDisk ? Theme.accent : Theme.islandBorder
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                        Rectangle {
                            id: switchThumb
                            width: 14
                            height: 14
                            radius: 7
                            anchors.verticalCenter: parent.verticalCenter
                            x: bottomNotch.controller.saveToDisk ? parent.width - width - 3 : 3
                            color: bottomNotch.controller.saveToDisk ? Theme.accentText : Theme.textMuted

                            Behavior on x { NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing } }
                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bottomNotch.controller.saveToDisk = !bottomNotch.controller.saveToDisk
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: 18
                    color: Theme.islandBorder
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    // Stitch count hint
                    Rectangle {
                        visible: bottomNotch.controller.selectedScreens.length > 0 || bottomNotch.controller.windowMultiSelectCount > 0
                        implicitWidth: stitchText.implicitWidth + 14
                        implicitHeight: 18
                        radius: height / 2
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                        border.color: Theme.accent
                        border.width: 1

                        Text {
                            id: stitchText
                            anchors.centerIn: parent
                            text: {
                                if (bottomNotch.controller.selectedScreens.length > 0) return "Stitch: " + bottomNotch.controller.selectedScreens.length + " screens"
                                if (bottomNotch.controller.windowMultiSelectCount > 0) return "Stitch: " + bottomNotch.controller.windowMultiSelectCount + " windows"
                                return ""
                            }
                            color: Theme.accentText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLabel
                            font.weight: Font.DemiBold
                        }
                    }

                    // Shift+click hint
                    Text {
                        text: "Shift+click for editor"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                    }

                    // Ctrl+click hint
                    Text {
                        visible: bottomNotch.controller.mode === "window" || bottomNotch.controller.mode === "screen"
                        text: "Ctrl+click to multi-select"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLabel
                        opacity: 0.7
                    }
                }
            }

            // OCR/Lens hint
            Column {
                opacity: (bottomNotch.controller.mode === "ocr" || bottomNotch.controller.mode === "lens") ? 1 : 0
                visible: opacity > 0
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                Text {
                    text: bottomNotch.controller.mode === "ocr" ? "Select text to extract" : "Select area to search"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }

                Text {
                    visible: bottomNotch.controller.mode === "lens"
                    text: bottomNotch.controller.detectedQRCodes.length > 0
                        ? bottomNotch.controller.detectedQRCodes.length + " QR code" + (bottomNotch.controller.detectedQRCodes.length > 1 ? "s" : "") + " detected"
                        : "No QR codes detected"
                    color: bottomNotch.controller.detectedQRCodes.length > 0 ? Theme.accent : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLabel
                    font.weight: bottomNotch.controller.detectedQRCodes.length > 0 ? Font.DemiBold : Font.Normal
                }
            }

            // AI Prompt input
            Row {
                opacity: bottomNotch.controller.mode === "ai" ? 1 : 0
                visible: opacity > 0
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right

                Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                Text {
                    text: "Prompt:"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    id: promptBox
                    width: parent.width - 65
                    height: 34
                    radius: Theme.radiusSmall
                    color: promptInput.activeFocus ? Theme.islandSurfaceHover : Theme.islandSurface
                    border.color: promptInput.activeFocus ? Theme.accent : Theme.islandBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                    TextInput {
                        id: promptInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        text: bottomNotch.controller.aiPrompt
                        clip: true
                        selectByMouse: true
                        selectedTextColor: Theme.accentText
                        selectionColor: Theme.accent
                        onTextChanged: bottomNotch.controller.aiPrompt = text
                        onActiveFocusChanged: bottomNotch.controller.promptFocused = activeFocus

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Describe what to analyze..."
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            visible: !promptInput.text && !promptInput.activeFocus
                        }
                    }
                }
            }
        }
    }
}
