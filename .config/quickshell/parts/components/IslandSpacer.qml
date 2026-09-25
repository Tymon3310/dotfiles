// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I S L A N D   S P A C E R                                              │
// │   a small break between parts sharing one island                         │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"

// Put between chromeless parts laid out in one Row inside the island.
// `dot` draws a small dot, `line` a short hairline, `gap` just space.
Item {
    id: root

    property string kind: "dot"
    property int gap: 10

    implicitWidth: root.gap
    implicitHeight: Theme.capsuleHeight

    Rectangle {
        anchors.centerIn: parent
        visible: root.kind !== "gap"
        width: root.kind === "line" ? 1 : 3
        height: root.kind === "line" ? Math.round(Theme.capsuleHeight * 0.4) : 3
        radius: width / 2
        color: Theme.indicatorDim
    }
}
