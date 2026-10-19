pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    property string agent: ""
    property string state: "idle"
    property string label: ""
    property string title: ""
    property string address: ""
    // Every open agent session, most urgent first ({id, agent, state, label,
    // title, task, address}); the fields above are the first busy one.
    property var agents: []
    property int count: 0

    // ── ATTENTION ───────────────────────────────────────────────────────
    // Something still wants you: a session waiting for input or errored.
    // The island's agent icon pulses while this holds.
    readonly property bool needsAttention: root.agents.some(agent =>
        agent.state === "waiting" || agent.state === "error")
    readonly property string attentionState: root.agents.some(agent => agent.state === "error")
        ? "error" : root.needsAttention ? "waiting" : ""

    // A short-lived alert the island morphs into when a session finishes,
    // needs input or errors ({kind, title, detail, address}). Not shown on
    // the first report after startup, so open sessions don't all fire.
    property bool alertActive: false
    property var alert: ({ kind: "", title: "", detail: "", address: "" })

    readonly property Timer alertTimer: Timer {
        interval: 4200
        onTriggered: root.alertActive = false
    }

    function dismissAlert(): void {
        root.alertActive = false
        root.alertTimer.stop()
    }

    // Severity when several change at once: the worst one is shown.
    readonly property var alertRank: ({ error: 3, waiting: 2, done: 1 })

    property var lastStates: ({})
    property bool primed: false

    function noteTransitions(list: var): void {
        const seen = {}
        let pick = null
        for (const agent of list) {
            const id = agent.id || agent.agent
            seen[id] = agent.state
            const before = root.lastStates[id]
            if (!root.primed || before === undefined || before === agent.state)
                continue
            if (!(agent.state in root.alertRank))
                continue
            if (!pick || root.alertRank[agent.state] > root.alertRank[pick.state])
                pick = agent
        }
        root.lastStates = seen
        root.primed = true
        if (pick)
            root.raise(pick)
    }

    function raise(agent: var): void {
        const name = agent.agent || "Agent"
        const what = { waiting: "needs your input", done: "finished", error: "hit an error" }[agent.state]
        root.alert = {
            kind: agent.state,
            title: `${name} ${what}`,
            detail: agent.task || agent.title || "",
            address: agent.address || ""
        }
        root.alertActive = true
        root.alertTimer.restart()
    }

    function focusWindow(): void {
        // Lua dispatch over the socket: the legacy `hyprctl dispatch
        // focuswindow` syntax is rejected by the Lua config.
        root.focusAddress(root.address)
    }

    function focusAddress(address: string): void {
        if (address && address !== "")
            HyprlandService.focusWindow(address)
    }

    readonly property Timer monitorRestart: Timer {
        interval: 2000
        onTriggered: root.monitorProcess.running = true
    }

    readonly property Process monitorProcess: Process {
        command: ["python3", "-u", Quickshell.shellPath("parts/scripts/agent_monitor.py")]
        running: true

        // Comes back if it exits (a crash, or killed to pick up an edit);
        // otherwise the agent list would stay frozen until a restart.
        onExited: root.monitorRestart.restart()

        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    root.active = !!data.active
                    root.agent = data.agent || ""
                    root.state = data.state || "idle"
                    root.label = data.label || ""
                    root.title = data.title || ""
                    root.address = data.address || ""
                    root.noteTransitions(data.agents || [])
                    root.agents = data.agents || []
                    root.count = data.count || 0
                } catch (_) {}
            }
        }
    }
}
