#!/bin/bash
# dispatch.sh — Read task.json, run Claude Code headless, capture output for hook
#
# task.json fixed path: ~/.openclaw/claude-code-bridge/task.json
#
# task.json format:
#   {
#     "from":            "TELEGRAM_CHAT_ID",  # required: notify this channel on completion
#     "text":            "Create a REST API", # required: task prompt
#     "workdir":         "~/my-project",      # optional: working directory, defaults to $HOME
#     "permission_mode": "acceptEdits"        # optional: defaults to acceptEdits
#   }

set -euo pipefail

RESULT_DIR="$HOME/.openclaw/claude-code-bridge"
TASK_FILE="$RESULT_DIR/task.json"
OUTPUT_FILE="$RESULT_DIR/task-output.txt"
CLAUDE="${CLAUDE_CODE_BIN:-$(which claude 2>/dev/null || echo "claude")}"

[ -f "$TASK_FILE" ] || { echo "Error: task.json not found at $TASK_FILE" >&2; exit 1; }
[ -f "$CLAUDE" ]    || { echo "Error: claude not found at $CLAUDE (set CLAUDE_CODE_BIN)" >&2; exit 1; }

# ---- Read task.json ----
FROM=$(jq -r '.from // ""'                       "$TASK_FILE")
TEXT=$(jq -r '.text // ""'                       "$TASK_FILE")
WORKDIR=$(jq -r '.workdir // "~"'                "$TASK_FILE")
PERM=$(jq -r '.permission_mode // "acceptEdits"' "$TASK_FILE")

[ -n "$TEXT" ] || { echo "Error: text field is required" >&2; exit 1; }

# Expand ~ to $HOME
WORKDIR="${WORKDIR/#\~/$HOME}"
mkdir -p "$WORKDIR"

echo "From : ${FROM:-(none)}"
echo "Dir  : $WORKDIR"
echo "Perm : $PERM"
echo "Task : $TEXT"
echo ""

# ---- Run Claude Code (headless + PTY via macOS script), save output to file ----
cd "$WORKDIR"
unset CLAUDECODE  # prevent "nested session" error when dispatched from within Claude Code
script -q "$OUTPUT_FILE" "$CLAUDE" -p "$TEXT" --permission-mode "$PERM"

echo ""
echo "Done."
