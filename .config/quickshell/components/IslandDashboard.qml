import QtQuick
import QtQuick.Layouts

import "../parts/theme"
import "../parts/components"
import "../parts/services"
import "../parts/bar/modules"
import "../parts/bar/island"
import "../parts/bar/island/controls"

// Everything the island opens, in one board. Built only while it is open.
//
//   calendar      player and lyrics    weather / notifications
//   audio + bt    speed and pings      agents
//   system (cpu, memory, gpu, vram)    session
//
// Fixed size, so the island can grow to it before it is built.
GridLayout {
    id: root

    signal closed()

    readonly property int gap: 12
    readonly property int leftWidth: 320
    readonly property int middleWidth: 380
    readonly property int rightWidth: 360
    readonly property int firstHeight: 420
    readonly property int secondHeight: 132
    readonly property int thirdHeight: 148
    // Three agent rows; more scroll.
    readonly property int agentHeight: 178

    readonly property int boardWidth: root.leftWidth + root.middleWidth + root.rightWidth + 2 * root.gap
    readonly property int boardHeight: root.firstHeight + root.secondHeight + root.thirdHeight + 2 * root.gap

    columns: 3

    // Agents card shown while any agent session is open, idle ones included.
    // Collapsing waits a while, so a session restarting or a gap between
    // polls doesn't make the column flap.
    readonly property bool hasAgents: AgentService.agents.length > 0
    property bool showAgents: root.hasAgents
    onHasAgentsChanged: {
        if (root.hasAgents) {
            agentHold.stop()
            root.showAgents = true
        } else {
            agentHold.restart()
        }
    }
    Timer {
        id: agentHold
        interval: 8000
        onTriggered: root.showAgents = root.hasAgents
    }
    rowSpacing: root.gap
    columnSpacing: root.gap

    // ── FIRST ROW ──────────────────────────────────────────────────────────

    CalendarCard {
        id: calendarCard
        Layout.row: 0
        Layout.column: 0
        Layout.preferredWidth: root.leftWidth
        Layout.preferredHeight: root.firstHeight
    }

    // The whole column: lyrics need the height.
    MediaCard {
        id: mediaCard
        Layout.row: 0
        Layout.column: 1
        Layout.preferredWidth: root.middleWidth
        Layout.preferredHeight: root.firstHeight
    }

    // The right column covers the first two rows: weather, notifications,
    // and the agents card below them. With no agent running the agents card
    // slides away and the notification list grows into its space.
    ColumnLayout {
        Layout.row: 0
        Layout.column: 2
        Layout.rowSpan: 2
        Layout.preferredWidth: root.rightWidth
        Layout.preferredHeight: root.firstHeight + root.gap + root.secondHeight
        spacing: 0

        WeatherCard {
            id: weatherCard
            Layout.fillWidth: true
            Layout.preferredHeight: 182
        }

        Item { Layout.preferredHeight: root.gap }

        NotificationList {
            id: notificationList
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // Gap + card, so a collapsed slot leaves no stray gap. The card keeps
        // its full height and is uncovered from the top as the slot grows.
        Item {
            id: agentSlot

            Layout.fillWidth: true
            Layout.preferredHeight: root.showAgents ? root.gap + root.agentHeight : 0
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
            }

            AgentCard {
                id: agentCard
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: root.gap
                height: root.agentHeight
                opacity: root.showAgents ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durationMedium } }
            }
        }
    }

    // ── SECOND ROW ─────────────────────────────────────────────────────────

    // Volume, mic and Bluetooth together, to make room for the agents.
    AudioCard {
        id: audioCard
        Layout.row: 1
        Layout.column: 0
        Layout.preferredWidth: root.leftWidth
        Layout.preferredHeight: root.secondHeight
    }
    // Wired only: throughput and pings instead of the Wi-Fi detail.
    LinkCard {
        id: linkCard
        Layout.row: 1
        Layout.column: 1
        Layout.preferredWidth: root.middleWidth
        Layout.preferredHeight: root.secondHeight
    }

    // ── THIRD ROW ──────────────────────────────────────────────────────────

    // Processor, memory, graphics and video memory, with temperatures.
    SystemCard {
        id: systemCard
        Layout.row: 2
        Layout.column: 0
        Layout.columnSpan: 2
        Layout.preferredWidth: root.leftWidth + root.gap + root.middleWidth
        Layout.preferredHeight: root.thirdHeight
    }

    SessionPanel {
        id: sessionPanel
        Layout.row: 2
        Layout.column: 2
        Layout.preferredWidth: root.rightWidth
        Layout.preferredHeight: root.thirdHeight
        onClosed: root.closed()
    }

    // ── ENTRANCE ───────────────────────────────────────────────────────────
    // Cards arrive in a diagonal wave from the top left (order = row +
    // column). The agents card's opacity follows its slot, so only its
    // scale is animated.
    Entrance { item: calendarCard; order: 0 }
    Entrance { item: mediaCard; order: 1 }
    Entrance { item: audioCard; order: 1 }
    Entrance { item: weatherCard; order: 2 }
    Entrance { item: linkCard; order: 2 }
    Entrance { item: systemCard; order: 2 }
    Entrance { item: notificationList; order: 3 }
    Entrance { item: agentCard; order: 4; fade: false }
    Entrance { item: sessionPanel; order: 4 }
}
