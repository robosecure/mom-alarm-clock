#!/bin/bash
# One-time setup for the token usage monitor.
# Run before your first marathon session.

echo "================================================="
echo "  Token Monitor Setup"
echo "================================================="
echo ""
echo "This monitor estimates usage from Claude Code's"
echo "local session logs (~/.claude/). No API key needed."
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Set default budget (10M tokens — adjust for your plan)
echo "Setting default budget to 10,000,000 tokens..."
python3 "${SCRIPT_DIR}/token_monitor.py" --set-budget 10000000

echo ""
echo "Quick test:"
python3 "${SCRIPT_DIR}/token_monitor.py" --check

echo ""
echo "================================================="
echo "  Commands:"
echo "    --check        Quick status (OK/WARN/STOP)"
echo "    --detailed     Full breakdown"
echo "    --set-budget N Change budget"
echo "    --json         Machine-readable"
echo ""
echo "  Exit codes: 0=OK, 1=WARN(75%+), 2=STOP(85%+)"
echo ""
echo "  For official usage: run /cost inside Claude Code"
echo "================================================="
