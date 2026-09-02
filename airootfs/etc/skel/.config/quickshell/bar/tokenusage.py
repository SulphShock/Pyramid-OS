#!/usr/bin/env python3
"""Query token usage from opencode, claude, zcode databases."""
import sqlite3
import os
import json
import glob

DB_PATH = os.path.expanduser("~/.local/share/opencode/opencode.db")
CLAUDE_DIR = os.path.expanduser("~/.claude")

def get_opencode_usage():
    if not os.path.exists(DB_PATH):
        return None
    conn = sqlite3.connect(DB_PATH)
    cur = conn.execute(
        "SELECT SUM(tokens_input), SUM(tokens_output), SUM(tokens_reasoning), "
        "SUM(tokens_cache_read), SUM(cost), COUNT(*) FROM session"
    )
    row = cur.fetchone()
    conn.close()
    if not row or row[0] is None:
        return None
    return {
        "tool": "opencode",
        "input": row[0],
        "output": row[1],
        "reasoning": row[2],
        "cache": row[3],
        "cost": row[4],
        "sessions": row[5],
    }

def get_claude_usage():
    """Claude doesn't have a local DB with token counts, return config info."""
    settings_path = os.path.join(CLAUDE_DIR, "settings.json")
    if not os.path.exists(settings_path):
        return None
    try:
        with open(settings_path) as f:
            settings = json.load(f)
        sessions_dir = os.path.join(CLAUDE_DIR, "projects")
        session_count = 0
        if os.path.isdir(sessions_dir):
            for d in os.listdir(sessions_dir):
                p = os.path.join(sessions_dir, d)
                if os.path.isdir(p):
                    session_count += len(glob.glob(os.path.join(p, "*.jsonl")))
        return {
            "tool": "claude",
            "model": "claude-code",
            "base_url": settings.get("env", {}).get("ANTHROPIC_BASE_URL", ""),
            "sessions": session_count,
        }
    except Exception:
        return None

def get_zcode_usage():
    """ZCode is an Electron app, check for log files."""
    zcode_dir = "/opt/ZCode"
    if not os.path.isdir(zcode_dir):
        return None
    # Check for any usage/session data
    log_files = glob.glob(os.path.expanduser("~/.config/ZCode/**/*.log"), recursive=True)
    return {
        "tool": "zcode",
        "installed": True,
        "log_files": len(log_files),
    }

def format_tokens(n):
    if n is None: return "0"
    if n >= 1_000_000: return f"{n/1_000_000:.1f}M"
    if n >= 1_000: return f"{n/1_000:.1f}K"
    return str(n)

def main():
    usage = {}
    opencode = get_opencode_usage()
    if opencode:
        usage["opencode"] = opencode
    claude = get_claude_usage()
    if claude:
        usage["claude"] = claude
    zcode = get_zcode_usage()
    if zcode:
        usage["zcode"] = zcode

    # Summary line for bar
    total_in = opencode["input"] if opencode else 0
    total_out = opencode["output"] if opencode else 0
    total = total_in + total_out
    sessions = opencode["sessions"] if opencode else 0

    summary = f"{format_tokens(total)} tok | {sessions} sessions"

    # Detailed JSON for tooltip
    print(json.dumps({"summary": summary, "total": total, "sessions": sessions, "usage": usage}))

if __name__ == "__main__":
    main()
