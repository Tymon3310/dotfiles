pragma Singleton

import QtQuick
import Quickshell
import "../theme"

// Resting notch geometry shared by the desktop and the lock-screen handoff.
// TextMetrics keeps the lock screen from constructing a hidden desktop UI.
QtObject {
    id: root

    readonly property int spacing: 10
    readonly property int padding: 14
    readonly property int artSize: 20
    readonly property real spectrumBarWidth: 2.5
    readonly property real spectrumBarSpacing: 1.5
    readonly property string song: MediaService.artist !== ""
        ? `${MediaService.title}  •  ${MediaService.artist}` : MediaService.title
    readonly property string time: Qt.formatDateTime(root.clock.date, SettingsService.clockFormat || "HH:mm")
    readonly property string date: Qt.formatDateTime(root.clock.date, "dddd, d MMM")

    readonly property SystemClock clock: SystemClock { precision: SystemClock.Minutes }

    readonly property TextMetrics songMetrics: TextMetrics {
        text: root.song
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
    }
    readonly property TextMetrics clockMetrics: TextMetrics {
        text: root.time
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall + 1
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }
    readonly property TextMetrics dateMetrics: TextMetrics {
        text: root.date
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall - 1
        font.weight: Font.Medium
    }
    readonly property TextMetrics dividerMetrics: TextMetrics {
        text: "|"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Light
    }

    readonly property real songWidth: MediaService.available && MediaService.title !== ""
        ? Math.min(280, root.songMetrics.width) : 0
    property real spectrumWidth: MediaService.visualizerActive
        ? CavaService.barCount * root.spectrumBarWidth
            + Math.max(0, CavaService.barCount - 1) * root.spectrumBarSpacing : 0
    Behavior on spectrumWidth {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    readonly property real agentWidth: AgentService.active ? 22 : 0
    readonly property real privacyWidth: PrivacyService.active ? (PrivacyService.cameraActive && PrivacyService.micActive ? 22 : 12) : 0

    readonly property real rowWidth: root.artSize + Math.ceil(root.clockMetrics.advanceWidth)
        + Math.ceil(root.dividerMetrics.advanceWidth) + Math.ceil(root.dateMetrics.advanceWidth) + 3 * root.spacing
        + (root.songWidth > 0 ? root.songWidth + root.spacing : 0)
        + (root.spectrumWidth > 0 ? root.spectrumWidth + root.spacing : 0)
        + (root.agentWidth > 0 ? root.agentWidth + root.spacing : 0)
        + (root.privacyWidth > 0 ? root.privacyWidth + root.spacing : 0)
    readonly property real notchWidth: root.rowWidth + 2 * root.padding
}
