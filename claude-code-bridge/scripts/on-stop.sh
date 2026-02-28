#!/bin/bash
# on-stop.sh — Claude Code Stop hook
# Sends a Telegram notification to the originator when a task completes.
#
# Install at: ~/.claude/hooks/on-stop.sh
# settings.json:
#   "hooks": { "Stop": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/on-stop.sh", "timeout": 30 }] }] }

set -uo pipefail

RESULT_DIR="$HOME/.openclaw/claude-code-bridge"
TASK_FILE="$RESULT_DIR/task.json"
OUTPUT_FILE="$RESULT_DIR/task-output.txt"
LOCK_FILE="$RESULT_DIR/.hook-lock"
LOG="$RESULT_DIR/hook.log"
OPENCLAW="${OPENCLAW_BIN:-/opt/homebrew/bin/openclaw}"

mkdir -p "$RESULT_DIR"
log() { echo "[$(date -Iseconds)] $*" >> "$LOG"; }

log "=== Hook fired ==="

# ---- Check task.json first: no file means a TUI session, skip without touching lock ----
if [ ! -f "$TASK_FILE" ]; then
    log "No task.json, skip"; exit 0
fi

FROM=$(jq -r '.from // ""' "$TASK_FILE")
TEXT=$(jq -r '.text // ""' "$TASK_FILE")

if [ -z "$FROM" ]; then
    log "No 'from' in task.json, skip"; exit 0
fi

# ---- Check lock: only notify once within 30 seconds ----
if [ -f "$LOCK_FILE" ]; then
    LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE") ))
    if [ "$LOCK_AGE" -lt 30 ]; then
        log "Duplicate within ${LOCK_AGE}s, skip"; exit 0
    fi
fi
touch "$LOCK_FILE"

# ---- Read output summary (last 800 chars) ----
SUMMARY=""
if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    SUMMARY=$(tail -c 800 "$OUTPUT_FILE")
fi

# ---- Clean up to prevent duplicate notifications ----
rm -f "$TASK_FILE" "$OUTPUT_FILE"

log "Notifying: $FROM"

# ---- Send Telegram notification ----
MSG="✅ *Claude Code done*

📋 Task: ${TEXT:0:100}

📝 Output:
\`\`\`
${SUMMARY:-(no output)}
\`\`\`"

"$OPENCLAW" message send \
    --channel telegram \
    --target  "$FROM"  \
    --message "$MSG"   2>/dev/null \
    && log "Sent to $FROM" \
    || log "Send failed"

log "=== Hook done ==="
