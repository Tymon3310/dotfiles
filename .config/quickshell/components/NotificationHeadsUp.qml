import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Widgets

import "../parts/theme"
import "../parts/services"
import "../parts/components"

// Heads-up notification overlay shown over fullscreen applications on WlrLayer.Overlay.
// When an application is fullscreen, the top bar is covered, so this floating pill
// drops down from the ceiling to present notifications with full interactivity.
PanelWindow {
    id: root

    property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.namespace: "quickshell-heads-up-notification"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property string screenName: root.screen ? root.screen.name : ""
    readonly property bool isFullscreen: HyprlandService.isFullscreenOn(root.screenName)
    readonly property bool headsUpActive: (SettingsService.notificationHeadsUpMode === "always")
        || (SettingsService.notificationHeadsUpMode === "fullscreen" && root.isFullscreen)

    readonly property var currentNotification: NotificationService.current
    property var displayedNotification: null

    onCurrentNotificationChanged: {
        if (currentNotification) {
            displayedNotification = currentNotification
        }
    }

    readonly property bool hasMultiple: NotificationService.shown.length > 1
    readonly property int notificationCount: NotificationService.shown.length
    readonly property bool isCritical: displayedNotification
        ? NotificationService.isCritical(displayedNotification) : false

    readonly property bool shouldShow: NotificationService.active
        && root.headsUpActive
        && !LockService.locked
        && currentNotification !== null

    property bool windowVisible: false
    property real cardY: -220
    property real cardOpacity: 0.0

    visible: windowVisible

    // Timeout countdown progress (1.0 -> 0.0)
    readonly property real progressFraction: {
        if (!displayedNotification || isCritical)
            return 1.0
        const deadline = NotificationService.deadlines[displayedNotification.key]
        if (!deadline)
            return 1.0
        const total = Math.max(1000, deadline - displayedNotification.time)
        const remaining = Math.max(0, deadline - progressTicker.now)
        return Math.min(1.0, Math.max(0.0, remaining / total))
    }

    Timer {
        id: progressTicker
        property real now: Date.now()
        interval: 33
        repeat: true
        running: root.windowVisible && !NotificationService.held
        onTriggered: now = Date.now()
    }

    onShouldShowChanged: {
        if (shouldShow) {
            root.windowVisible = true
            exitAnim.stop()
            entryAnim.restart()
        } else {
            entryAnim.stop()
            exitAnim.restart()
        }
    }

    ParallelAnimation {
        id: entryAnim
        NumberAnimation {
            target: root
            property: "cardY"
            from: -220
            to: 18
            duration: 380
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }
        NumberAnimation {
            target: root
            property: "cardOpacity"
            from: 0.0
            to: 1.0
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: exitAnim
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "cardY"
                to: -220
                duration: 240
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root
                property: "cardOpacity"
                to: 0.0
                duration: 180
                easing.type: Easing.InCubic
            }
        }
        ScriptAction {
            script: {
                root.windowVisible = false
                NotificationService.held = false
            }
        }
    }

    Component.onDestruction: NotificationService.held = false

    // Only the card area intercepts mouse clicks; the rest of the screen passes straight through
    mask: Region {
        item: (root.windowVisible && root.cardOpacity > 0.05) ? cardBox : null
    }

    Item {
        id: cardBox
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.cardY
        opacity: root.cardOpacity

        width: 440
        height: mainCard.implicitHeight

        Behavior on height {
            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
        }

        // Floating heads-up pill
        Rectangle {
            id: mainCard
            anchors.fill: parent

            radius: Theme.radiusLarge + 2
            color: "#0a0a0c"
            border.width: 1
            border.color: root.isCritical ? Theme.red : Theme.hairline
            clip: true

            implicitHeight: cardLayout.implicitHeight + 24

            // Outer soft glow halo
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: parent.radius + 1
                color: "transparent"
                border.color: root.isCritical ? Qt.rgba(1, 0.27, 0.23, 0.35) : Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                z: -1
            }

            // Top highlight glass sheen
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 40
                height: 1
                color: Qt.rgba(1, 1, 1, 0.12)
            }

            // Mouse interaction for the card body
            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                z: 0

                property real pressY: 0
                property bool isDragging: false

                onPressed: mouse => {
                    pressY = mouse.y
                    isDragging = true
                }

                onPositionChanged: mouse => {
                    // Swipe / drag up to dismiss
                    if (isDragging && (mouse.y - pressY < -24)) {
                        isDragging = false
                        if (root.displayedNotification)
                            NotificationService.closeKey(root.displayedNotification.key)
                    }
                }

                onReleased: mouse => {
                    if (!isDragging)
                        return
                    isDragging = false
                    if (mouse.button === Qt.RightButton) {
                        if (root.displayedNotification)
                            NotificationService.closeKey(root.displayedNotification.key)
                    } else if (mouse.button === Qt.LeftButton && Math.abs(mouse.y - pressY) < 10) {
                        if (root.displayedNotification)
                            NotificationService.activate(root.displayedNotification)
                    }
                }
            }

            HoverHandler {
                onHoveredChanged: NotificationService.held = hovered
            }

            // Card content layout
            RowLayout {
                id: cardLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 12
                z: 1

                // 1. Picture / App Icon
                NotificationPicture {
                    id: picture
                    Layout.preferredWidth: picture.landscape ? Math.min(76, Math.round(40 * picture.aspect)) : 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    notification: root.displayedNotification
                    critical: root.isCritical
                    keep: true
                }

                // 2. Text and Actions Column
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    // Title + App Name Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: root.displayedNotification ? root.displayedNotification.summary : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall + 1
                            font.weight: Font.DemiBold
                            color: Theme.text
                            elide: Text.ElideRight
                        }

                        Text {
                            text: root.displayedNotification ? (root.displayedNotification.appName || "") : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            color: root.isCritical ? Theme.red : Theme.textMuted
                            elide: Text.ElideRight
                            visible: text !== ""
                        }

                        // Badge if multiple notifications queued
                        Rectangle {
                            visible: root.hasMultiple
                            implicitWidth: stackBadgeText.implicitWidth + 8
                            implicitHeight: 15
                            radius: 7
                            color: Theme.islandSurfaceHover
                            border.color: Theme.hairline
                            border.width: 1

                            Text {
                                id: stackBadgeText
                                anchors.centerIn: parent
                                text: `+${root.notificationCount - 1}`
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: Theme.accent
                            }
                        }
                    }

                    // Body text
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.displayedNotification ? (root.displayedNotification.body ?? "") : ""
                        textFormat: Text.StyledText
                        wrapMode: Text.WrapAnywhere
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: Theme.textMuted
                        linkColor: Theme.accent
                        onLinkActivated: link => {
                            Qt.openUrlExternally(link)
                            if (root.displayedNotification)
                                NotificationService.remove(root.displayedNotification)
                        }
                    }

                    // Action Pills (if any)
                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        visible: actionRepeater.count > 0
                        spacing: 6

                        Repeater {
                            id: actionRepeater
                            model: root.displayedNotification
                                ? (root.displayedNotification.actions ?? []).filter(a => a.text !== "") : []

                            PillButton {
                                required property var modelData

                                text: modelData.text
                                active: modelData.identifier === "default"
                                implicitHeight: 24
                                horizontalPadding: 10
                                onClicked: {
                                    if (root.displayedNotification)
                                        NotificationService.invokeKey(root.displayedNotification.key, modelData.identifier)
                                }
                            }
                        }
                    }
                }

                // 3. Close button with circular RingIndicator countdown
                Item {
                    id: closeContainer
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24

                    RingIndicator {
                        anchors.fill: parent
                        thickness: 2
                        trackColor: Qt.rgba(1, 1, 1, 0.08)
                        fillColor: root.isCritical ? Theme.red : Theme.accent
                        progress: root.progressFraction
                        sweepDuration: 40

                        Rectangle {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            radius: 9
                            color: closeMouse.containsMouse ? Theme.islandSurfaceHover : "transparent"

                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                color: closeMouse.containsMouse ? Theme.text : Theme.textMuted
                            }
                        }
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.displayedNotification)
                                NotificationService.closeKey(root.displayedNotification.key)
                        }
                    }
                }
            }
        }
    }
}
