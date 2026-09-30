pragma Singleton
import QtQuick

QtObject {
    id: root

    // ── ISLAND ──────────────────────────────────────────────────────────────
    readonly property color island: "#000000"
    readonly property color islandSurface: "#141414"
    readonly property color islandSurfaceHover: "#1f1f1f"
    readonly property color islandBorder: "#262626"

    // ── SEMANTIC COLOURS ────────────────────────────────────────────────────
    readonly property color background: "#0c0c0c"
    readonly property color surface: "#141414"
    readonly property color surfaceHover: "#202020"
    readonly property color border: "#282828"
    readonly property color text: "#ffffff"
    readonly property color textMuted: "#8e8e93"
    readonly property color accent: "#0070D8"
    readonly property color accentHover: "#409cff"
    readonly property color accentText: "#ffffff"

    readonly property color red: "#ff453a"
    readonly property color green: "#32d74b"
    readonly property color yellow: "#ffd60a"
    readonly property color blue: "#0070D8"

    readonly property color hairline: "#20ffffff"
    readonly property color captureWash: "#99000000"

    // ── TYPOGRAPHY ──────────────────────────────────────────────────────────
    readonly property string fontFamily: "Google Sans"
    readonly property string fontMono: "Google Sans Code NF"

    readonly property int fontSizeLabel: 10
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeRegular: 13
    readonly property int fontSizeMedium: 14
    readonly property int fontSizeLarge: 16

    // ── METRICS ─────────────────────────────────────────────────────────────
    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 18
    readonly property int radiusPill: 999
    readonly property int radiusNotch: 8

    // ── MOTION ──────────────────────────────────────────────────────────────
    readonly property int durationFast: 140
    readonly property int durationMedium: 200
    readonly property int durationMorph: 380
    readonly property int easing: Easing.OutCubic
}
