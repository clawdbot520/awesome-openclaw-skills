#!/bin/bash
# memory-recall.sh — Claude Code UserPromptSubmit hook
# On every user message, search LanceDB Pro and inject relevant memories as context.
#
# Install at: ~/.claude/hooks/memory-recall.sh
# Requires: memory-lancedb-pro plugin installed in OpenClaw
# Requires: JINA_API_KEY set in environment (plist or shell profile)

set -uo pipefail

OPENCLAW="${OPENCLAW_BIN:-/opt/homebrew/bin/openclaw}"
LOG="$HOME/.openclaw/claude-code-bridge/memory-recall.log"
mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date -Iseconds)] $*" >> "$LOG"; }

# Read hook stdin (JSON)
INPUT=$(cat)
QUERY=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null | head -c 300)

[ ${#QUERY} -lt 5 ] && exit 0
log "Recall query: ${QUERY:0:80}"

# Search LanceDB Pro, strip openclaw UI noise
MEMORIES=$("$OPENCLAW" memory-pro search "$QUERY" --limit 5 2>/dev/null | \
  grep -Ev "^\[3[0-9]m|\[plugins\]|plugin registered|Doctor|Run: openclaw|^[│◇├╮╯]|^$" | \
  sed '/^[[:space:]]*$/d')

if [ -n "$MEMORIES" ]; then
  log "Injecting memories ($(echo "$MEMORIES" | wc -l) lines)"
  cat <<EOF
<memory_recall>
Relevant past experience from LanceDB Pro (OpenClaw agents + Claude Code TUI sessions):
$MEMORIES
</memory_recall>
EOF
else
  log "No memories found"
fi

exit 0
