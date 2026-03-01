#!/bin/bash
# sync-claude-sessions.sh
# Symlink ~/.claude/projects/**/*.jsonl into ~/.openclaw/agents/claude-code/sessions/
# so memory-distiller's hourly cron can distill Claude Code TUI sessions alongside OpenClaw sessions.
#
# Called by on-stop.sh on every TUI session end (runs in < 0.1s).

DEST="$HOME/.openclaw/agents/claude-code/sessions"
mkdir -p "$DEST"

find "$HOME/.claude/projects" -maxdepth 2 -name "*.jsonl" 2>/dev/null | while read -r src; do
    name=$(basename "$src")
    link="$DEST/$name"
    [ -L "$link" ] || ln -sf "$src" "$link"
done
