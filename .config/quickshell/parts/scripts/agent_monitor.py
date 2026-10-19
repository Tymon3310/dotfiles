#!/usr/bin/env python3
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
OPENCODE_DB = HOME / ".local/share/opencode/opencode.db"
T3_DIR = HOME / ".t3/userdata"
ANTIGRAVITY_STATE = HOME / ".config/opencode/antigravity-turn-states.json"
CODEX_DIR = HOME / ".codex"
# Written by claude_status.sh from Claude Code hooks, one file per session.
CLAUDE_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "agent-status" / "claude"

# Urgency order when several agents are active: the one shown first.
STATE_RANK = {"error": 0, "waiting": 0, "working": 1, "done": 2, "idle": 3}

# A finished Claude turn reads "Done" this long, then the session stays
# listed as "Idle" until it ends. Idle sessions show only in the dashboard
# card; the bar badges count the rest.
CLAUDE_DONE_MS = 60000


def get_hyprland_windows():
    try:
        raw = subprocess.check_output(["hyprctl", "clients", "-j"], timeout=0.8)
        return json.loads(raw)
    except Exception:
        return []


def window_task(address, clients):
    """The window's title minus Claude Code's leading status glyph.

    Claude Code titles its terminal with a short summary of the session
    ("✳ Startup speed optimization"), which says more than the directory.
    Plain shell titles (a path, a program name) are not tasks.
    """
    if not address:
        return ""
    for c in clients:
        if c.get("address") == address:
            title = str(c.get("title", "")).strip()
            parts = title.split(" ", 1)
            # A single non-alphanumeric leading glyph is the status spinner.
            if len(parts) == 2 and len(parts[0]) == 1 and not parts[0].isalnum():
                title = parts[1].strip()
            if not title or title.startswith(("~", "/")) or title.lower() in ("claude", "claude code", "opencode", "zsh", "bash"):
                return ""
            return title
    return ""


def find_window(agent_name, title_hint, clients, pids=()):
    # A process ancestry (Claude Code) pins the exact terminal window.
    for pid in pids:
        for c in clients:
            if c.get("pid") == pid:
                return c.get("address", "")
    agent_lower = agent_name.lower()
    for c in clients:
        addr = c.get("address", "")
        c_class = str(c.get("class", "")).lower()
        c_title = str(c.get("title", "")).lower()

        if agent_lower == "opencode":
            if "oc |" in c_title or "opencode" in c_class or (title_hint and title_hint.lower() in c_title):
                return addr
        elif agent_lower == "t3code" or agent_lower == "t3":
            if "t3" in c_class or "t3code" in c_title:
                return addr
        elif agent_lower == "antigravity":
            if "antigravity" in c_class or "antigravity" in c_title:
                return addr
        elif agent_lower == "codex":
            if "codex" in c_class or "codex" in c_title:
                return addr
    return ""


def opencode_tui_running():
    """An OpenCode window is open (its `serve` daemon alone doesn't count)."""
    try:
        for entry in os.scandir("/proc"):
            if not entry.name.isdigit():
                continue
            try:
                with open(f"/proc/{entry.name}/comm") as stream:
                    if stream.read().strip() != "opencode":
                        continue
                with open(f"/proc/{entry.name}/cmdline", "rb") as stream:
                    args = stream.read().split(b"\0")
            except OSError:
                continue
            if b"serve" not in args:
                return True
    except OSError:
        pass
    return False


def check_opencode():
    if not OPENCODE_DB.exists():
        return None
    tui_open = opencode_tui_running()
    try:
        conn = sqlite3.connect(f"file:{OPENCODE_DB}?mode=ro", uri=True, timeout=0.15)
        cur = conn.cursor()
        cur.execute("PRAGMA query_only = ON")

        session = cur.execute(
            "SELECT id, title, agent, time_updated, time_idle, idle_outcome FROM session_v2 ORDER BY time_updated DESC LIMIT 1"
        ).fetchone()
        if not session:
            conn.close()
            return None

        sid, title, agent_type, time_updated, time_idle, outcome = session
        now_ms = time.time() * 1000
        time_idle = time_idle or 0

        # Nothing recent and no window open: nothing to show. An open window
        # keeps its last session listed (as idle, below).
        if now_ms - time_updated > 2 * 3600 * 1000 and not tui_open:
            conn.close()
            return None

        # Check pending actions / approval
        pending = cur.execute(
            "SELECT id, type, data FROM session_pending WHERE session_id=? LIMIT 1", (sid,)
        ).fetchone()

        conn.close()

        if pending:
            return {
                "active": True,
                "agent": "OpenCode",
                "state": "waiting",
                "label": "OpenCode · Needs Input",
                "title": title or "",
                "time": time_updated,
            }

        # If time_updated > time_idle, agent is actively thinking or executing tools
        if time_updated > time_idle:
            return {
                "active": True,
                "agent": "OpenCode",
                "state": "working",
                "label": "OpenCode · Thinking",
                "title": title or "",
                "time": time_updated,
            }

        # A finished turn reads "Done" for a minute, like Claude's.
        if now_ms - time_idle < CLAUDE_DONE_MS:
            return {
                "active": True,
                "agent": "OpenCode",
                "state": "done",
                "label": "OpenCode · Done",
                "title": title or "",
                "time": time_idle,
            }

        # Finished a while ago, but the window is still open.
        if tui_open:
            return {
                "active": True,
                "agent": "OpenCode",
                "state": "idle",
                "label": "OpenCode · Idle",
                "title": title or "",
                "time": time_idle,
            }
    except Exception:
        pass
    return None


def check_t3():
    db_path = T3_DIR / "statev2.sqlite"
    if not db_path.exists():
        db_path = T3_DIR / "state.sqlite"
    if not db_path.exists():
        return None
    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=0.15)
        cur = conn.cursor()
        cur.execute("PRAGMA query_only = ON")

        # Check if table exists
        has_table = cur.execute(
            "SELECT 1 FROM sqlite_master WHERE name='projection_threads'"
        ).fetchone()
        if not has_table:
            conn.close()
            return None

        rows = cur.execute(
            """
            SELECT s.thread_id, s.provider_name, t.pending_approval_count, t.pending_user_input_count, turn.state, turn.started_at
            FROM projection_thread_sessions s
            JOIN projection_threads t ON t.thread_id=s.thread_id
            JOIN projection_turns turn ON turn.thread_id=s.thread_id AND turn.turn_id=s.active_turn_id
            WHERE s.active_turn_id IS NOT NULL AND (turn.state='running' OR t.pending_approval_count > 0 OR t.pending_user_input_count > 0)
            ORDER BY turn.started_at DESC LIMIT 1
            """
        ).fetchall()
        conn.close()

        if rows:
            thread, prov, approval, question, turn_state, started = rows[0]
            prov_name = (prov or "T3").title()
            if approval > 0 or question > 0:
                return {
                    "active": True,
                    "agent": "T3",
                    "state": "waiting",
                    "label": f"{prov_name} · Needs Input",
                    "title": thread or "",
                    "time": time.time(),
                }
            elif turn_state == "running":
                return {
                    "active": True,
                    "agent": "T3",
                    "state": "working",
                    "label": f"{prov_name} · Working",
                    "title": thread or "",
                    "time": time.time(),
                }
    except Exception:
        pass
    return None


def check_antigravity():
    if not ANTIGRAVITY_STATE.exists():
        return None
    try:
        data = json.loads(ANTIGRAVITY_STATE.read_text())
        now_ms = time.time() * 1000
        entries = data.get("entries", {})
        for eid, entry in entries.items():
            st = entry.get("state", {})
            updated = entry.get("updatedAt", 0)
            if now_ms - updated < 30000:
                if st.get("inToolLoop") or st.get("turnHasThinking") or st.get("lastModelHasThinking"):
                    return {
                        "active": True,
                        "agent": "Antigravity",
                        "state": "working",
                        "label": "Antigravity · Working",
                        "title": "Antigravity CLI",
                        "time": updated,
                    }
                elif now_ms - updated < 12000:
                    return {
                        "active": True,
                        "agent": "Antigravity",
                        "state": "done",
                        "label": "Antigravity · Done",
                        "title": "Antigravity CLI",
                        "time": updated,
                    }
    except Exception:
        pass
    return None


def check_claude():
    """Every live Claude Code session, from the hook-written status files."""
    found = []
    try:
        files = list(CLAUDE_DIR.glob("*.json"))
    except OSError:
        return found
    now_ms = time.time() * 1000
    for path in files:
        try:
            data = json.loads(path.read_text())
        except (OSError, ValueError):
            continue
        pids = [p for p in data.get("pids", []) if isinstance(p, int)]
        # pids[0] is the claude process: gone without a SessionEnd hook
        # (crash, killed terminal) means the session is over.
        if pids and not os.path.exists(f"/proc/{pids[0]}"):
            path.unlink(missing_ok=True)
            continue
        state = data.get("state", "")
        updated = data.get("time", 0)
        if state == "done" and now_ms - updated > CLAUDE_DONE_MS:
            state = "idle"
        if state not in STATE_RANK:
            continue
        project = os.path.basename(data.get("cwd", "").rstrip("/")) or "Claude"
        word = {"waiting": "Needs Input", "working": "Working", "done": "Done",
                "idle": "Idle", "error": "Error"}[state]
        found.append({
            "active": True,
            "agent": "Claude",
            "id": data.get("session") or path.stem,
            "state": state,
            "label": f"Claude · {word}",
            "title": project,
            "time": updated,
            "pids": pids,
            "cwd": data.get("cwd", ""),
        })
    return found


def parent_of(pid):
    try:
        with open(f"/proc/{pid}/stat") as stream:
            # The command can hold spaces and parentheses; fields follow ")".
            return int(stream.read().rsplit(")", 1)[1].split()[1])
    except (OSError, ValueError, IndexError):
        return 0


def daemon_attached_pids():
    """Pids of processes connected to a Claude Code daemon's control socket.

    A terminal client attached to the daemon is showing a session the daemon
    hosts (e.g. after a resume); that session's hooks run from the daemon,
    so their process ancestry never reaches the terminal window.
    """
    try:
        out = subprocess.run(["ss", "-xpH"], capture_output=True, text=True, timeout=0.8).stdout
    except (OSError, subprocess.TimeoutExpired):
        return set()
    owner = {}      # socket inode -> (local path, pids)
    peer_of = {}    # socket inode -> peer inode
    for line in out.splitlines():
        cols = line.split()
        if len(cols) < 8:
            continue
        # Netid State Recv-Q Send-Q Local LocalInode Peer PeerInode [users]
        local, inode, peer = cols[4], cols[5], cols[7]
        pids = {int(m) for m in re.findall(r"pid=(\d+)", line)}
        owner[inode] = (local, pids)
        peer_of[inode] = peer
    attached = set()
    for inode, (local, pids) in owner.items():
        peer = owner.get(peer_of.get(inode, ""))
        if peer and peer[0].endswith("/control.sock") and "cc-daemon" in peer[0]:
            attached |= pids
    return attached


def settle_claude_windows(agents, clients):
    """Window each Claude session, handing daemon-hosted ones their terminal.

    A resumed session gets a new id and runs from the daemon; the old id's
    status file lingers, tied to the terminal. When a session has no window
    of its own and an older session in the same folder sits in a terminal
    attached to the daemon, the new one takes that window and the old one is
    dropped. Any two sessions left on one window keep only the newest.
    """
    claude = [a for a in agents if a["agent"] == "Claude"]
    for a in claude:
        a["address"] = find_window("Claude", "", clients, a.get("pids", ()))
    dropped = set()
    if any(not a["address"] for a in claude):
        attached = daemon_attached_pids()
        for a in claude:
            if a["address"]:
                continue
            older = [o for o in claude
                     if o is not a and o["address"] and id(o) not in dropped
                     and o.get("cwd") == a.get("cwd")
                     and o.get("time", 0) < a.get("time", 0)
                     and (o.get("pids") or [0])[0] in attached]
            if older:
                previous = max(older, key=lambda o: o.get("time", 0))
                a["address"] = previous["address"]
                dropped.add(id(previous))
    newest = {}
    for a in claude:
        if id(a) in dropped or not a["address"]:
            continue
        if a["address"] not in newest or a.get("time", 0) > newest[a["address"]].get("time", 0):
            newest[a["address"]] = a
    return [a for a in agents
            if a["agent"] != "Claude"
            or (id(a) not in dropped and (not a["address"] or newest[a["address"]] is a))]


def poll_agents():
    agents = [a for a in (check_opencode(), check_t3(), check_antigravity()) if a]
    agents += check_claude()

    if not agents:
        return {
            "active": False,
            "agent": "",
            "state": "idle",
            "label": "",
            "title": "",
            "address": "",
            "count": 0,
            "agents": [],
        }

    # Most urgent first, newest first within a state.
    agents.sort(key=lambda a: (STATE_RANK.get(a["state"], 9), -float(a.get("time") or 0)))

    # The window list is only needed when something is shown.
    clients = get_hyprland_windows()
    listed = []
    agents = settle_claude_windows(agents, clients)
    for a in agents:
        address = a.get("address") if a["agent"] == "Claude" \
            else find_window(a["agent"], a.get("title", ""), clients, a.get("pids", ()))
        listed.append({
            # Stable per session, so the shell can tell a state change from a
            # different agent taking the first slot.
            "id": a.get("id") or a["agent"],
            "agent": a["agent"],
            "state": a["state"],
            "label": a["label"],
            "title": a.get("title", ""),
            # What the session is about, from its window title ("" if none).
            # Other agents report their session title directly.
            "task": window_task(address, clients) if a["agent"] == "Claude" else a.get("title", ""),
            "address": address,
        })

    # Badges follow the busy agents only; `agents` lists idle sessions too.
    busy_listed = [a for a in listed if a["state"] != "idle"]
    if not busy_listed:
        return {
            "active": False,
            "agent": "",
            "state": "idle",
            "label": "",
            "title": "",
            "address": "",
            "count": 0,
            "agents": listed,
        }
    primary = dict(busy_listed[0])
    primary.update({"active": True, "count": len(busy_listed), "agents": listed})
    return primary


def main():
    last_output = ""
    while True:
        try:
            status = poll_agents()
            out_str = json.dumps(status)
            if out_str != last_output:
                print(out_str, flush=True)
                last_output = out_str
        except Exception:
            pass
        time.sleep(1.2)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
