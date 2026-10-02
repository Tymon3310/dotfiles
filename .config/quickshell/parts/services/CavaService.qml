// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C A V A   S E R V I C E                                                │
// │   audio spectrum from cava                                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Audio spectrum of the output stream, from cava. Runs only while something
// is subscribed.
Singleton {
    id: root

    readonly property int barCount: 8

    property int watchers: 0
    property var values: new Array(root.barCount).fill(0)

    readonly property bool active: root.watchers > 0

    readonly property Process process: Process {
        command: ["cava", "-p", Quickshell.shellPath("parts/scripts/cava.conf")]
        running: root.active

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.parse(line)
        }
    }

    function parse(line: string): void {
        const fields = line.split(";")
        const next = []
        for (let index = 0; index < root.barCount; index++) {
            const value = Number(fields[index])
            next.push(Number.isFinite(value) ? Math.max(0, Math.min(1, value / 100)) : 0)
        }
        root.values = next
    }

    function subscribe(): void {
        root.watchers += 1
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
        if (root.watchers === 0)
            root.values = new Array(root.barCount).fill(0)
    }
}
