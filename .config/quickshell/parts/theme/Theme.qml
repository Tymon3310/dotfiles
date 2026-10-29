pragma Singleton

import QtQuick
import "../services"
import "../../shared" as Shared

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

    // Growing and arriving get a light spring (OutBack, small overshoot);
    // leaving stays a quick ease. Content inside a panel enters staggered:
    // each piece scales up from `enterScale` and fades in, `durationStagger`
    // after the one before it.
    readonly property int easingSpring: Easing.OutBack
    readonly property real springOvershoot: 0.5
    readonly property int durationSpring: Math.round(440 * root.motion)
    readonly property int durationEnter: Math.round(320 * root.motion)
    readonly property int durationStagger: Math.round(32 * root.motion)
    readonly property real enterScale: 0.94
    // List-row washes. Rest and hover are both white at low opacity, so a
    // fade between them stays dark: fading from a near-transparent white to
    // an opaque grey passes through a brighter grey than either, which read
    // as a flash.
    readonly property color rowRest: Qt.rgba(1, 1, 1, 0)
    readonly property color rowRaised: Qt.rgba(1, 1, 1, 0.025)
    readonly property color rowHover: Qt.rgba(1, 1, 1, 0.06)
    function tintWash(tint: color, strength: real): color {
        return Qt.rgba(tint.r, tint.g, tint.b, strength)
    }

    readonly property real pressScale: 0.94

    // Capture waits for the island to reach its compact 72px rest. Retract
    // and demorph run in parallel over durationIslandRetract (the demorph
    // flag is set synchronously with close()), plus two compositor frames.
    readonly property int durationIslandRetract: Math.round(220 * root.motion)
    readonly property int durationIslandGone: root.durationIslandRetract + 40
}
