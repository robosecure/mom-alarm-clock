#!/usr/bin/env python3
"""
Token Usage Monitor for Mom Alarm Clock Marathon Sessions.

Estimates token usage from Claude Code's local session logs.
No API key needed -- works with Claude Pro/Max subscriptions.

Usage:
  python3 scripts/token_monitor.py --check              # Quick: OK / WARN / STOP
  python3 scripts/token_monitor.py --detailed            # Full breakdown
  python3 scripts/token_monitor.py --set-budget 10000000 # Set token budget
  python3 scripts/token_monitor.py --json                # Machine-readable

The marathon prompt calls --check before each round.
Exit codes: 0=OK, 1=WARN (75%+), 2=STOP (85%+ -- pause marathon).

For official usage, run /cost inside Claude Code.
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

BUDGET_FILE = Path(__file__).parent / ".token_budget.json"
DEFAULT_DAILY_BUDGET = 10_000_000
WARN_THRESHOLD = 0.75
STOP_THRESHOLD = 0.85


def get_config():
    config = {"daily_budget": int(os.environ.get("OPUS_DAILY_BUDGET", DEFAULT_DAILY_BUDGET))}
    if BUDGET_FILE.exists():
        try:
            saved = json.loads(BUDGET_FILE.read_text())
            config["daily_budget"] = saved.get("daily_budget", config["daily_budget"])
        except (json.JSONDecodeError, KeyError):
            pass
    return config


def save_budget(budget):
    BUDGET_FILE.write_text(json.dumps({
        "daily_budget": budget,
        "updated_at": datetime.now(timezone.utc).isoformat()
    }))
    print("Budget set to {:,} tokens".format(budget))


def estimate_from_session_logs():
    claude_dir = Path.home() / ".claude"
    if not claude_dir.exists():
        return None

    today_str = datetime.now().strftime("%Y-%m-%d")
    total_bytes = 0
    file_count = 0
    largest_file = ""
    largest_size = 0

    for path in claude_dir.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix not in (".jsonl", ".json", ".md", ""):
            continue
        try:
            stat = path.stat()
            mod_date = datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d")
            if mod_date == today_str:
                total_bytes += stat.st_size
                file_count += 1
                if stat.st_size > largest_size:
                    largest_size = stat.st_size
                    largest_file = str(path.relative_to(claude_dir))
        except OSError:
            continue

    if file_count == 0:
        return None

    estimated_tokens = total_bytes // 4
    return {
        "estimated_tokens": estimated_tokens,
        "files_counted": file_count,
        "total_bytes": total_bytes,
        "largest_file": largest_file,
        "largest_size": largest_size,
    }


def check_status(config):
    budget = config["daily_budget"]
    estimate = estimate_from_session_logs()
    if estimate:
        total = estimate["estimated_tokens"]
        pct = total / budget if budget > 0 else 0
        note = " (from {:,} bytes across {} files)".format(estimate["total_bytes"], estimate["files_counted"])
        msg = "{:,} / {:,} tokens ({:.0%}){}".format(total, budget, pct, note)
        if pct >= STOP_THRESHOLD:
            return "STOP", pct, msg
        elif pct >= WARN_THRESHOLD:
            return "WARN", pct, msg
        else:
            return "OK", pct, msg
    return "UNKNOWN", 0, "No logs found. Run /cost in Claude Code."


def print_detailed(config):
    budget = config["daily_budget"]
    print("=" * 55)
    print("  Token Monitor -- {}".format(datetime.now().strftime("%Y-%m-%d %H:%M")))
    print("  Budget: {:,} | Warn: {:.0%} | Stop: {:.0%}".format(budget, WARN_THRESHOLD, STOP_THRESHOLD))
    print("=" * 55)
    estimate = estimate_from_session_logs()
    if estimate:
        pct = estimate["estimated_tokens"] / budget if budget > 0 else 0
        print("  Files today:   {}".format(estimate["files_counted"]))
        print("  Total bytes:   {:,}".format(estimate["total_bytes"]))
        print("  Est. tokens:   {:,}".format(estimate["estimated_tokens"]))
        print("  Budget used:   {:.1%}".format(pct))
        print("  Largest file:  {}".format(estimate["largest_file"]))
    else:
        print("  No logs found today.")
    status, pct, msg = check_status(config)
    print("\n  Status: {} -- {}".format(status, msg))
    print("\n  Tip: /cost in Claude Code shows official session cost.")
    print("=" * 55)


def main():
    parser = argparse.ArgumentParser(description="Token monitor for marathon sessions")
    parser.add_argument("--check", action="store_true", help="Quick check")
    parser.add_argument("--detailed", action="store_true", help="Full breakdown")
    parser.add_argument("--set-budget", type=int, help="Set daily token budget")
    parser.add_argument("--json", action="store_true", help="JSON output")
    args = parser.parse_args()

    config = get_config()

    if args.set_budget:
        save_budget(args.set_budget)
        return

    if args.detailed:
        print_detailed(config)
        return

    status, pct, msg = check_status(config)
    if args.json:
        print(json.dumps({"status": status, "usage_pct": round(pct, 4), "message": msg}))
    else:
        print("[{}] {}".format(status, msg))

    sys.exit({"OK": 0, "WARN": 1, "STOP": 2, "UNKNOWN": 0}[status])


if __name__ == "__main__":
    main()
