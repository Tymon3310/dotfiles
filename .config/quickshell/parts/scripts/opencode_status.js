// OpenCode plugin: records each session's state for the island's agent
// indicator (read by agent_monitor.py), like claude_status.sh does for
// Claude Code. One file per session under
// $XDG_RUNTIME_DIR/agent-status/opencode/<session id>.json.
//
// Installed by `install.sh --only agents` as a link in
// ~/.config/opencode/plugins/. It must stay quick and never throw: it runs on
// every event OpenCode emits.

import { mkdirSync, renameSync, rmSync, writeFileSync, readFileSync } from "node:fs"
import { join } from "node:path"

const DIR = join(process.env.XDG_RUNTIME_DIR || "/tmp", "agent-status", "opencode")

function sessionOf(event) {
    const p = event?.properties ?? {}
    return p.sessionID ?? p.info?.sessionID ?? p.info?.id ?? p.session?.id ?? ""
}

// `touch` false updates fields without resetting the state's clock.
function write(id, patch, directory, touch = true) {
    if (!id) return
    const file = join(DIR, `${id.replace(/[^\w.-]/g, "_")}.json`)
    let current = {}
    try {
        current = JSON.parse(readFileSync(file, "utf8"))
    } catch {}
    const next = {
        session: id,
        cwd: current.cwd || directory || "",
        title: current.title || "",
        ...current,
        ...patch,
        time: touch || !current.time ? Date.now() : current.time,
        pid: process.pid,
    }
    try {
        mkdirSync(DIR, { recursive: true })
        writeFileSync(`${file}.tmp`, JSON.stringify(next))
        renameSync(`${file}.tmp`, file)
    } catch {}
}

export const AgentStatus = async ({ directory }) => ({
    event: async ({ event }) => {
        try {
            const id = sessionOf(event)
            switch (event?.type) {
                case "session.status": {
                    const type = event.properties?.status?.type
                    if (type === "busy" || type === "retry") write(id, { state: "working" }, directory)
                    else if (type === "idle") write(id, { state: "done" }, directory)
                    break
                }
                case "session.idle":
                    write(id, { state: "done" }, directory)
                    break
                case "session.error":
                    write(id, { state: "error" }, directory)
                    break
                case "permission.asked":
                    write(id, { state: "waiting" }, directory)
                    break
                case "permission.replied":
                    write(id, { state: "working" }, directory)
                    break
                case "session.updated": {
                    const info = event.properties?.info ?? {}
                    // A title only; the state comes from the events above.
                    if (info.title) {
                        const patch = { title: info.title }
                        if (info.directory) patch.cwd = info.directory
                        write(id, patch, directory, false)
                    }
                    break
                }
                case "session.deleted":
                    if (id) rmSync(join(DIR, `${id.replace(/[^\w.-]/g, "_")}.json`), { force: true })
                    break
            }
        } catch {}
    },
})
