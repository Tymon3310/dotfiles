// It runs inside each OpenCode window (not the `serve` daemon), so the
// process id pins the terminal window too. Files, per window:
//   $XDG_RUNTIME_DIR/agent-status/opencode/<pid>.json   tabs and their state
//   $XDG_RUNTIME_DIR/agent-status/opencode/<pid>.focus  a session id to show
//
// Installed by `install.sh --only agents` as a link to this folder in
// ~/.config/opencode/plugins/. Restart OpenCode to load changes.

import { mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs"
import { join } from "node:path"

const DIR = join(process.env.XDG_RUNTIME_DIR || "/tmp", "agent-status", "opencode")
const STATUS = join(DIR, `${process.pid}.json`)
const FOCUS = join(DIR, `${process.pid}.focus`)
const POLL_MS = 400

function attempt(fn, fallback) {
    try {
        return fn()
    } catch {
        return fallback
    }
}

function directoryOf(location) {
    if (!location) return ""
    if (typeof location === "string") return location
    return location.directory || location.path || location.worktree || ""
}

// The tabs open in this window, or just the current session when tabs are
// turned off.
function currentTabs(api) {
    const tabs = api.ui.tabs
    if (attempt(() => tabs.enabled(), false)) return attempt(() => tabs.list(), [])
    const route = attempt(() => api.ui.router.current(), null)
    if (route?.type !== "session" || !route.sessionID) return []
    const id = route.sessionID
    const session = api.data.session
    return [{
        sessionID: id,
        active: true,
        busy: attempt(() => session.status(id) === "running", false),
        attention: attempt(() => (session.permission.list(id)?.length ?? 0) > 0
            || (session.form.list(id)?.length ?? 0) > 0, false),
    }]
}

export default {
    id: "agent-status",
    setup(api) {
        // Last state per session: { state, time }.
        const known = new Map()
        let written = ""

        function stateOf(tab, previous) {
            if (tab.attention) return "waiting"
            if (tab.busy) return "working"
            const failed = tab.unread === "error"
                || attempt(() => api.data.session.get(tab.sessionID)?.outcome === "failed", false)
            // The active tab is never "unread", so a turn ending there shows
            // as busy going false.
            const finished = tab.unread === "activity" || previous === "working" || previous === "waiting"
            if (finished) return failed ? "error" : "done"
            if (previous === "done" || previous === "error") return previous
            return "idle"
        }

        function report() {
            const now = Date.now()
            const tabs = []
            const seen = new Set()
            for (const tab of currentTabs(api)) {
                const id = tab.sessionID
                if (!id || seen.has(id)) continue
                seen.add(id)
                const before = known.get(id)
                const state = stateOf(tab, before?.state)
                const time = before && before.state === state ? before.time : now
                known.set(id, { state, time })
                const session = attempt(() => api.data.session.get(id), null)
                tabs.push({
                    session: id,
                    title: session?.title || tab.title || "",
                    cwd: directoryOf(session?.location) || process.cwd(),
                    state,
                    time,
                    active: Boolean(tab.active),
                })
            }
            for (const id of known.keys()) if (!seen.has(id)) known.delete(id)

            const text = JSON.stringify({ pid: process.pid, tabs })
            if (text === written) return
            mkdirSync(DIR, { recursive: true })
            writeFileSync(`${STATUS}.tmp`, text)
            renameSync(`${STATUS}.tmp`, STATUS)
            written = text
        }

        function takeFocusRequest() {
            let id
            try {
                id = readFileSync(FOCUS, "utf8").trim()
            } catch {
                return
            }
            rmSync(FOCUS, { force: true })
            if (!id) return
            const tabs = api.ui.tabs
            if (attempt(() => tabs.enabled(), false)) {
                // Not open as a tab (closed since): open it first.
                if (!tabs.list().some(tab => tab.sessionID === id)) tabs.open(id)
                tabs.focus(id)
            } else {
                api.ui.router.navigate({ type: "session", sessionID: id })
            }
        }

        const tick = () => {
            // It runs inside the TUI: never let it throw.
            attempt(takeFocusRequest)
            attempt(report)
        }
        const timer = setInterval(tick, POLL_MS)
        timer.unref?.()
        tick()

        const remove = () => {
            rmSync(STATUS, { force: true })
            rmSync(FOCUS, { force: true })
        }
        process.once("exit", remove)

        return () => {
            clearInterval(timer)
            process.off("exit", remove)
            attempt(remove)
        }
    },
}
