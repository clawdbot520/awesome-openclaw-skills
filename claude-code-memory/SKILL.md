---
name: claude-code-memory
description: >
  Bridges Claude Code TUI sessions with OpenClaw's LanceDB Pro memory system.
  Automatically recalls relevant past experience on every message, and distills
  Claude Code session history into shared long-term memory via hourly cron.
  Use when you want Claude Code to remember knowledge across sessions and share
  memory bidirectionally with OpenClaw agents.
---

# Claude Code Memory

Share long-term memory between Claude Code TUI and OpenClaw agents via LanceDB Pro.

## Architecture

```
Claude Code TUI sessions  ──┐
                             ├─ symlinks ─→ ~/.openclaw/agents/claude-code/sessions/
OpenClaw agent sessions  ───┘
                                    │
                          hourly cron (memory-distiller)
                          jsonl_distill.py (incremental)
                                    │
                            LanceDB Pro (hybrid search)
                                    │
                      UserPromptSubmit hook (memory-recall.sh)
                                    │
                        <memory_recall> injected into prompt
```

## Based On

This skill is built on top of **[memory-lancedb-pro](https://github.com/win4r/memory-lancedb-pro)** by [@win4r](https://github.com/win4r) — an OpenClaw plugin providing hybrid vector + BM25 search, 7-layer scoring, and a `memory_store` / `memory_recall` framework backed by LanceDB Pro.

What this skill adds on top:
- **Claude Code hooks** (`UserPromptSubmit` + `Stop`) to integrate with Claude Code TUI
- **Session symlink bridge** so Claude Code JSONL files are visible to the memory-distiller cron
- **jsonl_distill.py patch** to handle Claude Code's JSONL format (`type: "user"/"assistant"` vs `type: "message"`)
- **Gemini 2.0 Flash** distillation configuration for higher-quality memory extraction

## Prerequisites

1. **[memory-lancedb-pro](https://github.com/win4r/memory-lancedb-pro)** plugin installed and configured in OpenClaw
2. **JINA_API_KEY** set in environment (plist `EnvironmentVariables` + shell profile)
3. **memory-distiller** agent present in OpenClaw (`~/.openclaw/agents/memory-distiller/`)
4. **jq** available on PATH

Optional: **GEMINI_API_KEY** for higher-quality distillation (Gemini 2.0 Flash)

## Installation

### 1. Copy hooks

```bash
cp scripts/memory-recall.sh    ~/.claude/hooks/
cp scripts/on-stop.sh          ~/.claude/hooks/
cp scripts/sync-claude-sessions.sh ~/.claude/hooks/

chmod +x ~/.claude/hooks/memory-recall.sh
chmod +x ~/.claude/hooks/on-stop.sh
chmod +x ~/.claude/hooks/sync-claude-sessions.sh
```

### 2. Configure `~/.claude/settings.json`

```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/memory-recall.sh",
        "timeout": 10
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/on-stop.sh",
        "timeout": 60
      }]
    }]
  }
}
```

### 3. Patch jsonl_distill.py for Claude Code JSONL format

Claude Code uses `{"type":"user"}` / `{"type":"assistant"}` instead of OpenClaw's `{"type":"message"}`.
Apply this one-line patch to the distiller:

```bash
DISTILL_PY="$HOME/.openclaw/workspace/plugins/memory-lancedb-pro/scripts/jsonl_distill.py"

# Before: if obj.get("type") != "message":
# After:  if obj_type not in ("message", "user", "assistant"):
sed -i '' \
  's/obj_type = obj.get("type")\n.*if obj_type not in/obj_type = obj.get("type")\n            if obj_type not in/' \
  "$DISTILL_PY"
```

Or edit manually — find this block around line 312:

```python
# Replace this:
if obj.get("type") != "message":
    continue
msg = obj.get("message")
if not isinstance(msg, dict):
    continue
role = msg.get("role")

# With this:
obj_type = obj.get("type")
if obj_type not in ("message", "user", "assistant"):
    continue
msg = obj.get("message")
# Claude Code format: type IS the role, message may be nested or flat
if not isinstance(msg, dict):
    msg = {"role": obj_type, "content": obj.get("content", "")}
role = msg.get("role") or obj_type
```

Then clear the jiti cache:

```bash
rm -rf /tmp/jiti
```

### 4. Enable the hourly distillation cron

In OpenClaw UI → Cron, enable the `jsonl-memory-distill (hourly)` job for the `memory-distiller` agent.

To use Gemini 2.0 Flash for distillation, add to `~/.openclaw/agents/memory-distiller/agent/models.json`:

```json
"google": {
  "baseUrl": "https://generativelanguage.googleapis.com/v1beta/openai",
  "api": "openai-completions",
  "authHeader": true,
  "apiKey": "<YOUR_GEMINI_API_KEY>",
  "models": [{
    "id": "gemini-2.0-flash",
    "name": "Gemini 2.0 Flash",
    "reasoning": false,
    "input": ["text"],
    "contextWindow": 1048576,
    "maxTokens": 8192
  }]
}
```

Then set the cron payload `"model": "google/gemini-2.0-flash"`.

## Files

| File | Hook | Role |
|------|------|------|
| `memory-recall.sh` | `UserPromptSubmit` | Search LanceDB Pro, inject `<memory_recall>` context |
| `on-stop.sh` | `Stop` | TUI: sync symlinks; Task: send Telegram notification |
| `sync-claude-sessions.sh` | (called by on-stop.sh) | Symlink Claude Code JSONL → OpenClaw claude-code agent |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `JINA_API_KEY` | ✅ | Jina embedding API key (for LanceDB Pro search) |
| `OPENCLAW_BIN` | ❌ | Path to openclaw CLI, defaults to `/opt/homebrew/bin/openclaw` |
| `GEMINI_API_KEY` | ❌ | Gemini API key for distillation (optional, higher quality) |

## License

Apache 2.0
