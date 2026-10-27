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
    // title, task, address, focus}); the fields above are the first busy one.
    // `focus` ({file, session}) is set for OpenCode tabs: see focusAgent().
    property var agents: []
    property int count: 0

    // Something still wants you: a session waiting for input or errored.
    // The island's agent icon pulses while this holds.
    readonly property bool needsAttention: root.agents.some(agent =>
        agent.state === "waiting" || agent.state === "error")
    readonly property string attentionState: root.agents.some(agent => agent.state === "error")
        ? "error" : root.needsAttention ? "waiting" : ""

    // A short-lived alert the island morphs into when a session finishes,
    // needs input or errors ({id, kind, title, detail, address, focus}). Not shown on
    // the first report after startup, so open sessions don't all fire.
    property bool alertActive: false
    property var alert: ({ id: "", kind: "", title: "", detail: "", address: "", focus: null })

    readonly property Timer alertTimer: Timer {
        // Input and errors stay up longer than a finished turn.
        interval: root.alert.kind === "done" ? 4200 : 8000
        onTriggered: root.alertActive = false
    }

    // While a session still waits (or has errored), the alert comes back
    // every minute, unless you're already in that window.
    readonly property Timer reminder: Timer {
        interval: 60000
        repeat: true
        running: root.needsAttention
        onTriggered: {
            if (root.alertActive)
                return
            const pending = root.agents.find(agent =>
                (agent.state === "waiting" || agent.state === "error")
                && (agent.address === "" || agent.address !== HyprlandService.focusedAddress))
            if (pending)
                root.raise(pending)
        }
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
        // A "needs input" or "error" alert closes once that session has
        // moved on (answered, retried or closed) instead of running its time.
        else if (root.alertActive && root.alert.kind !== "done"
                 && seen[root.alert.id] !== root.alert.kind)
            root.dismissAlert()
    }

    function raise(agent: var): void {
        const name = agent.agent || "Agent"
        const what = { waiting: "needs your input", done: "finished", error: "hit an error" }[agent.state]
        root.alert = {
            id: agent.id || agent.agent,
            kind: agent.state,
            title: `${name} ${what}`,
            detail: agent.task || agent.title || "",
            address: agent.address || "",
            focus: agent.focus || null
        }
        root.alertActive = true
        root.alertTimer.restart()
    }

    function focusWindow(): void {
        const primary = root.agents.find(agent => agent.state !== "idle")
        if (primary)
            root.focusAgent(primary)
        else
            root.focusAddress(root.address)
    }

    function focusAddress(address: string): void {
        // Lua dispatch over the socket: the legacy `hyprctl dispatch
        // focuswindow` syntax is rejected by the Lua config.
        if (address && address !== "")
            HyprlandService.focusWindow(address)
    }

    // Focus the agent's window and, for an OpenCode tab, switch that window
    // to it: its plugin picks the session id up from `focus.file`.
    function focusAgent(agent: var): void {
        if (!agent)
            return
        root.focusAddress(agent.address || "")
        const focus = agent.focus
        if (focus && focus.file && focus.session) {
            focusWriter.command = ["sh", "-c", 'printf "%s" "$1" > "$2"', "sh", focus.session, focus.file]
            focusWriter.running = true
        }
    }

    readonly property Process focusWriter: Process {}

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
