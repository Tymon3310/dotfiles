// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T H E M E                                                              │
// │   login screen design tokens                                             │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick

QtObject {
    id: root

    // ── COLOUR ──────────────────────────────────────────────────────────────

    readonly property color island: "#000000"
    readonly property color islandSurface: "#141414"
    readonly property color islandSurfaceHover: "#1f1f1f"
    readonly property color islandBorder: "#2e2e2e"

    readonly property color text: "#ffffff"
    readonly property color textMuted: "#98989d"

    readonly property color accent: "#0a84ff"
    readonly property color accentHover: "#0071e3"
    readonly property color accentText: "#ffffff"

    readonly property color green: "#30d158"
    readonly property color red: "#ff453a"
    readonly property color indicator: "#ffffff"
    readonly property color indicatorWarn: "#ffd60a"
    readonly property color indicatorBad: "#ff453a"

    // ── METRIC ──────────────────────────────────────────────────────────────

    readonly property int capsuleHeight: 32
    readonly property int barTopMargin: 4
    readonly property int radiusNotch: 10

    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 18
    readonly property int radiusPill: 999

    // ── TYPE ────────────────────────────────────────────────────────────────

    readonly property string fontFamily: "Google Sans, Inter, Cantarell, SF Pro Text, sans-serif"
    readonly property string fontMono: "Google Sans Code NF, JetBrainsMono Nerd Font, monospace"

    readonly property int fontSizeSmall: 11
    readonly property int fontSizeRegular: 13
    readonly property int fontSizeMedium: 14
    readonly property int fontSizeLarge: 16
    readonly property int fontSizeClock: 92

    // ── MOTION ──────────────────────────────────────────────────────────────

    readonly property int durationFast: 140
    readonly property int durationMedium: 200
    readonly property int durationMorph: 380
    readonly property int easing: Easing.OutCubic
}
