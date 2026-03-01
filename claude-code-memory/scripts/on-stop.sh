#!/bin/bash
# on-stop.sh — Claude Code Stop hook
# - TUI session: sync JSONL symlinks so memory-distiller can pick them up
# - Task session (task.json present): send Telegram completion notification
#
# Install at: ~/.claude/hooks/on-stop.sh
# settings.json:
#   "hooks": { "Stop": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/on-stop.sh", "timeout": 60 }] }] }

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

# ---- No task.json = TUI session: just sync symlinks ----
if [ ! -f "$TASK_FILE" ]; then
    bash "$HOME/.claude/hooks/sync-claude-sessions.sh" 2>/dev/null
    log "TUI session - symlinks synced, memory-distiller will distill hourly"
    exit 0
fi

FROM=$(jq -r '.from // ""' "$TASK_FILE")
TEXT=$(jq -r '.text // ""' "$TASK_FILE")

if [ -z "$FROM" ]; then
    log "No 'from' in task.json, skip"; exit 0
fi

# ---- Deduplicate: only notify once within 30 seconds ----
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
