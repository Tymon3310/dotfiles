// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   P I N G   S E R V I C E                                                │
// │   round trips to a few well-known hosts                                  │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Round trips from `scripts/ping.py`, which stays resident and pings every
// host in parallel each `interval`. It runs only while something holds a
// subscribe(): one process for as long as the pings are shown.
//
// `results[id]` is { ms, lost } — `ms` the last round trip (-1 before the
// first answer), `lost` whether the last one went unanswered.
Singleton {
    id: root

    readonly property var hosts: [
        { id: "google",     address: "8.8.8.8",           label: "Google DNS" },
        { id: "cloudflare", address: "1.1.1.1",           label: "Cloudflare" },
        { id: "arch",       address: "ping.archlinux.org", label: "Arch Linux" }
    ]

    readonly property int interval: 2000
    readonly property int historyLength: 30

    property var results: ({})
    property var history: ({})

    property int watchers: 0

    function subscribe(): void {
        root.watchers += 1
    }

    function release(): void {
        root.watchers = Math.max(0, root.watchers - 1)
    }

    function record(id: string, ms: real): void {
        const results = Object.assign({}, root.results)
        results[id] = { ms: ms < 0 ? (root.results[id]?.ms ?? -1) : ms, lost: ms < 0 }
        root.results = results

        const history = Object.assign({}, root.history)
        const series = (history[id] ?? []).concat([Math.max(0, ms)])
        history[id] = series.slice(-root.historyLength)
        root.history = history
    }

    // Green under 30 ms, yellow under 80, red above or lost.
    function tint(id: string): string {
        const result = root.results[id]
        if (!result || result.lost)
            return "bad"
        if (result.ms < 30)
            return "good"
        return result.ms < 80 ? "warn" : "bad"
    }

    readonly property Process pinger: Process {
        running: root.watchers > 0
        command: [Quickshell.shellPath("parts/scripts/ping.py"), `${root.interval / 1000}`]
            .concat(root.hosts.map(host => host.address))

        stdout: SplitParser {
            onRead: line => {
                let data
                try {
                    data = JSON.parse(line)
                } catch (error) {
                    return
                }
                for (const host of root.hosts) {
                    if (host.address in data)
                        root.record(host.id, data[host.address])
                }
            }
        }
    }
}
