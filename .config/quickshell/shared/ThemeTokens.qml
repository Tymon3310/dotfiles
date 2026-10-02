// Common design tokens, derived from impasto (GPL-3.0; see parts/LICENSE).
import QtQuick

QtObject {
    property color island: "#000000"
    property color islandSurface: "#141414"
    property color islandSurfaceHover: "#1f1f1f"
    property color islandBorder: "#262626"

    property color background: "#0c0c0c"
    property color surface: "#141414"
    property color surfaceHover: "#202020"
    property color border: "#282828"
    property color text: "#ffffff"
    property color textMuted: "#8e8e93"
    property color accent: "#0070D8"
    property color accentHover: "#409cff"
    property color accentText: "#ffffff"
    property color red: "#ff453a"
    property color green: "#32d74b"
    property color yellow: "#ffd60a"
    property color blue: "#0070D8"
    property color hairline: "#20ffffff"
    property color captureWash: "#99000000"

    property string fontFamily: "Google Sans"
    property string fontMono: "Google Sans Code NF"
    property int fontSizeLabel: 10
    property int fontSizeSmall: 11
    property int fontSizeRegular: 13
    property int fontSizeMedium: 14
    property int fontSizeLarge: 16

    property int radiusSmall: 8
    property int radiusMedium: 12
    property int radiusLarge: 18
    property int radiusPill: 999
    property int radiusNotch: 6

    property int durationFast: 140
    property int durationMedium: 200
    property int durationMorph: 380
    property int easing: Easing.OutCubic
}
