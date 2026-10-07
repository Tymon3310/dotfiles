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


def get_hyprland_windows():
    try:
        raw = subprocess.check_output(["hyprctl", "clients", "-j"], timeout=0.8)
        return json.loads(raw)
    except Exception:
        return []


def find_window(agent_name, title_hint, clients):
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


def check_opencode():
    if not OPENCODE_DB.exists():
        return None
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

        # Check if session is recent (active within last 2 hours)
        if now_ms - time_updated > 2 * 3600 * 1000:
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

        # If turn finished within last 15 seconds
        if now_ms - time_idle < 15000:
            return {
                "active": True,
                "agent": "OpenCode",
                "state": "done",
                "label": "OpenCode · Done",
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


def poll_agents():
    # Priority order: OpenCode > T3 > Antigravity
    res = check_opencode()
    if not res:
        res = check_t3()
    if not res:
        res = check_antigravity()

    clients = get_hyprland_windows()

    if res:
        res["address"] = find_window(res["agent"], res.get("title", ""), clients)
        return res

    return {
        "active": False,
        "agent": "",
        "state": "idle",
        "label": "",
        "title": "",
        "address": "",
    }


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
