// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   W O R K S P A C E S   W I D G E T                                      │
// │   dots that stretch into a pill for the one you are on                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"

// Three states, by shape and weight alone:
//
//     focused    a wide pill
//     occupied   a dot, solid but dim
//     empty      a dot, dimmer still
//
// The first few dots are always shown; the rest appear with use. The pill
// slides and stretches between positions rather than switching. Drawn in the
// accent: unlike the battery it carries no warning, so it follows the palette.
Rectangle {
    id: root

    // The screen this bar is on, by name ("DP-1"). Set, the pill marks that
    // monitor's active workspace, in the accent only while the monitor has
    // focus and grey otherwise. Empty, it follows the focused workspace.
    property string monitor: ""

    readonly property int activeId: root.monitor !== ""
        ? HyprlandService.activeOn(root.monitor) : HyprlandService.activeId
    readonly property bool monitorFocused: root.monitor === ""
        || HyprlandService.focusedMonitor === root.monitor

    // Each monitor owns a block of `SettingsService.workspacesPerMonitor`
    // workspaces (1–20 on the first, 21–40 on the second…), found from the
    // block its active workspace is in. The dots are that block only,
    // numbered from its start.
    readonly property int perMonitor: SettingsService.workspacesPerMonitor

    // ── SWITCH FLASH ────────────────────────────────────────────────────────
    //
    // On a switch the pill grows tall enough to carry the workspace's number
    // (its place in this monitor's block), then shrinks back and the number
    // is destroyed. Not on the first reading, so a reload does not flash.
    readonly property int flashHeight: 15
    property bool flashing: false
    property bool settled: false

    onActiveIdChanged: {
        if (!root.settled)
            return
        root.flashing = true
        flashTimer.restart()
    }

    Component.onCompleted: settleTimer.start()

    Timer {
        id: settleTimer
        interval: 1500
        onTriggered: root.settled = true
    }

    Timer {
        id: flashTimer
        interval: 1400
        onTriggered: root.flashing = false
    }
    readonly property int base: root.monitor !== ""
        ? Math.floor(Math.max(0, root.activeId - 1) / root.perMonitor) * root.perMonitor
        : 0

    // Inside the one capsule it drops its own capsule and padding. On by
    // default here: the parts are meant to share one island.
    property bool chromeless: true

    readonly property int dotSize: 6
    readonly property int activeWidth: 22
    readonly property int slotSpacing: 8

    implicitHeight: Theme.capsuleHeight
    // Each slot carries its own gap, so a collapsed one takes no space; the
    // spare gap is subtracted here.
    implicitWidth: layout.implicitWidth - root.slotSpacing
        + (root.chromeless ? 0 : 20)
    radius: Theme.radiusPill

    color: root.chromeless ? "transparent" : Theme.island
    border.color: Theme.islandBorder
    border.width: root.chromeless ? 0 : 1

    RowLayout {
        id: layout
        anchors.centerIn: parent
        // Row spacing would still surround a collapsed slot.
        spacing: 0

        // A slot per workspace, shown or not, so arrivals and departures both
        // animate. A Repeater over only the visible ones would destroy items
        // and make the rest jump.
        Repeater {
            model: root.monitor !== "" ? root.perMonitor : HyprlandService.maximum

            Item {
                id: slot

                required property int index
                readonly property int workspaceId: root.base + slot.index + 1
                // The first few of the block always, the rest while in use.
                readonly property bool shown: root.monitor === ""
                    ? HyprlandService.isVisible(slot.workspaceId)
                    : slot.index < HyprlandService.slots || slot.focused || slot.occupied
                readonly property bool focused: root.activeId === slot.workspaceId
                readonly property bool occupied: HyprlandService.isOccupied(slot.workspaceId)

                Layout.preferredWidth: slot.shown
                    ? (slot.focused ? root.activeWidth : root.dotSize) + root.slotSpacing
                    : 0
                Layout.preferredHeight: Theme.capsuleHeight
                Layout.alignment: Qt.AlignVCenter

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
                }

                Rectangle {
                    id: dot

                    readonly property bool flash: slot.focused && root.flashing

                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - root.slotSpacing)
                    height: dot.flash ? root.flashHeight : root.dotSize
                    radius: height / 2

                    Behavior on height {
                        NumberAnimation { duration: Theme.durationMedium; easing.type: Easing.OutBack }
                    }

                    // Built for the flash only, and destroyed with it.
                    Loader {
                        anchors.centerIn: parent
                        active: dot.flash
                        sourceComponent: Text {
                            text: slot.workspaceId - root.base
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Theme.accentText
                            opacity: 0

                            // Fades in once the pill has room for it.
                            NumberAnimation on opacity {
                                from: 0; to: 1
                                duration: Theme.durationMedium
                            }
                        }
                    }

                    color: {
                        if (slot.focused)
                            return root.monitorFocused ? Theme.accent : Theme.textMuted
                        if (mouse.containsMouse)
                            return Theme.accent
                        return slot.occupied ? Theme.accent : Theme.indicatorDim
                    }
                    // Dimming separates occupied from focused without a third
                    // shape.
                    opacity: slot.focused ? 1 : (slot.occupied ? 0.55 : 1)

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
                }

                // Fills the slot, gap included; a 6 px target is too small.
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: HyprlandService.focus(slot.workspaceId)
                }
            }
        }
    }
}
