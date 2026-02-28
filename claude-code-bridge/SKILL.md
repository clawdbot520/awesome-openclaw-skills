---
name: claude-code-bridge
description: >
  Dispatches coding tasks from Telegram to Claude Code headless and sends
  Telegram notifications on completion. Use when routing tasks from an external
  agent or messaging channel to Claude Code. Do not use for interactive Claude
  Code sessions, direct CLI usage, or tasks not originating from Telegram.
---

# Claude Code Bridge

Bridge Telegram tasks to Claude Code with automatic completion notifications.

## Flow

```
task.json  →  dispatch.sh  →  claude (headless)
{ from, text }                     ↓ done
                            on-stop.sh (Stop hook)
                                   ↓
                            Telegram notification → from
```

## task.json Format

```json
{
  "from":            "TELEGRAM_CHAT_ID",
  "text":            "Create a GET /users REST API",
  "workdir":         "~/my-project",
  "permission_mode": "acceptEdits"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| from | ✅ | Telegram chat ID to notify on completion |
| text | ✅ | Task description (prompt sent to Claude) |
| workdir | ❌ | Working directory, defaults to `$HOME` |
| permission_mode | ❌ | Claude permission mode, defaults to `acceptEdits` |

## Usage

OpenClaw writes `task.json` to the fixed path, then calls:

```bash
dispatch.sh
```

## Installation

```bash
# 1. Copy scripts
cp scripts/dispatch.sh  ~/.openclaw/skills/claude-code-bridge/
cp scripts/on-stop.sh   ~/.claude/hooks/

chmod +x ~/.openclaw/skills/claude-code-bridge/dispatch.sh
chmod +x ~/.claude/hooks/on-stop.sh

# 2. Configure settings.json
```

`~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/on-stop.sh",
        "timeout": 30
      }]
    }]
  }
}
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_CODE_BIN` | auto-detected via `which claude` | Path to claude binary |
| `OPENCLAW_BIN` | `/opt/homebrew/bin/openclaw` | Path to openclaw CLI |

## Files

- `dispatch.sh` — Reads task.json, runs Claude Code headless, captures output
- `on-stop.sh` — Stop hook: reads task.json, sends Telegram notification, cleans up

## License

Apache 2.0
