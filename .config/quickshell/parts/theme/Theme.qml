// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T H E M E                                                              │
// │   design tokens · consumed by every component                            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import "../services"
import "../../shared" as Shared

// Shell settings extend the tokens also used by the standalone screenshot tool.
Shared.ThemeTokens {
    id: root

    readonly property color indicator: "#ffffff"
    readonly property color indicatorDim: "#4d4d4d"
    readonly property color indicatorGood: "#32d74b"
    readonly property color indicatorWarn: "#ffd60a"
    readonly property color indicatorBad: "#ff453a"
    readonly property color scrim: "#bf000000"
    readonly property real pictureCorner: 0.24

    readonly property int capsuleHeight: SettingsService.barHeight
    readonly property int barTopMargin: SettingsService.barMargin
    readonly property int capsuleSpacing: 8

    fontFamily: SettingsService.fontFamily
    fontMono: SettingsService.fontMono

    readonly property int paletteTransition: 260
    Behavior on background   { ColorAnimation { duration: root.paletteTransition } }
    Behavior on surface      { ColorAnimation { duration: root.paletteTransition } }
    Behavior on surfaceHover { ColorAnimation { duration: root.paletteTransition } }
    Behavior on border       { ColorAnimation { duration: root.paletteTransition } }
    Behavior on text         { ColorAnimation { duration: root.paletteTransition } }
    Behavior on textMuted    { ColorAnimation { duration: root.paletteTransition } }
    Behavior on accent       { ColorAnimation { duration: root.paletteTransition } }
    Behavior on accentHover  { ColorAnimation { duration: root.paletteTransition } }
    Behavior on accentText   { ColorAnimation { duration: root.paletteTransition } }

    readonly property real motion: SettingsService.motionScale / 100
    readonly property var easingCurves: ({
        OutCubic: Easing.OutCubic,
        OutQuint: Easing.OutQuint,
        OutBack: Easing.OutBack,
        Linear: Easing.Linear
    })
    easing: root.easingCurves[SettingsService.motionCurve] ?? Easing.OutCubic
    durationFast: Math.round(140 * root.motion)
    durationMedium: Math.round(200 * root.motion)
    durationMorph: Math.round(380 * root.motion)

    // Capture waits for retraction, notch shrinkage and two compositor frames.
    readonly property int durationIslandRetract: 300
    readonly property int durationIslandGone: root.durationIslandRetract + root.durationMorph + 40
}
