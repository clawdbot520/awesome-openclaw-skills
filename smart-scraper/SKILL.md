---
name: smart-scraper
description: >
  Multi-tier intelligent web scraping framework - starts with the fastest, lowest-token method
  and automatically falls back to heavier tiers on failure.
  Trigger: user says "scrape XXX", "fetch content from OO", "get data from URL".
---

# Smart Scraper

A 7-tier fallback scraping framework. Tries the cheapest method first and escalates automatically.

## 7-Tier Flow

```
URL → detect type → try tiers in priority order → auto-fallback on failure
```

| Tier | Tool | Best For |
|------|------|----------|
| 1 | opencli (public) | X, Bilibili, Reddit, HN, GitHub and 17+ platforms |
| 2 | web_fetch / curl | Any public webpage |
| 3 | yt-dlp | YouTube, Podcasts, media |
| 4 | web_search | Search engine queries |
| 5 | opencli (cookie) | Pages requiring login |
| 6 | CDP | Browser automation via Chrome DevTools Protocol |
| 7 | browser | Last resort (expensive — ~8000 tokens) |

## Usage

```bash
~/.openclaw/skills/smart-scraper/scripts/smart_scrape.sh "URL"

# With content type hint
~/.openclaw/skills/smart-scraper/scripts/smart_scrape.sh "https://youtube.com/..." -t video

# With agent override
AGENT=openclaw ~/.openclaw/skills/smart-scraper/scripts/smart_scrape.sh "URL"
```

## Installation

### Required
```bash
# opencli — multi-platform scraper (X, Bilibili, Reddit, HN, etc.)
npm install -g @jackwener/opencli

# yt-dlp — video/audio downloader
brew install yt-dlp
```

### Optional
```bash
# CDP is bundled in chrome-cdp/ — no install needed
# Requires Chrome with remote debugging enabled:
# chrome://inspect/#remote-debugging
```

### Environment Variables
```bash
# opencli token (required for Tier 1/5)
export PLAYWRIGHT_MCP_EXTENSION_TOKEN="your_token_here"
```

## Directory Structure

```
smart-scraper/
├── SKILL.md                    # This file
├── scripts/
│   └── smart_scrape.sh         # Core script (7-tier decision engine)
├── chrome-cdp/                 # CDP engine (bundled, no install needed)
│   └── scripts/
│       └── cdp.mjs
└── logs/                       # Auto-generated at runtime
    ├── errors.json             # Failure log (for pattern detection)
    └── rules.json              # Auto-generated skip rules
```

## Agent Capability Matrix (verified 2026-03-17)

| Tier | Tool | claude-code | openclaw | antigravity |
|------|------|------------|---------|------------|
| 1 | opencli public | ✅ shell | ✅ shell | ✅ shell |
| 2 | web_fetch | ✅ WebFetch tool (preferred over curl) | ✅ curl/tool | ✅ read_url_content |
| 3 | yt-dlp | ✅ Bash tool | ✅ shell | ✅ shell |
| 4 | web_search | ✅ **WebSearch tool (bypass script)** | ✅ MCP tool | ✅ search_web |
| 5 | opencli cookie | ✅ shell | ✅ shell | ✅ shell |
| 6 | CDP | ✅ Bash tool | ✅ shell | ✅ dynamic probe |
| 7 | browser | ❌ not available | ✅ built-in | ✅ browser_subagent |

### claude-code Rules

**Do NOT use the script for Tier 2/4 — use native tools instead:**
- Tier 2 → call `WebFetch` tool directly (handles redirects/encoding better than curl)
- Tier 4 → call `WebSearch` tool directly (script is a no-op for this agent)
- Tier 7 → not available; escalate to openclaw or antigravity

**Script invocation (for Tier 1/3/5/6 only):**
```bash
PLAYWRIGHT_MCP_EXTENSION_TOKEN="$PLAYWRIGHT_MCP_EXTENSION_TOKEN" AGENT=claude-code \
  ~/.openclaw/skills/smart-scraper/scripts/smart_scrape.sh "URL"
```

## Built-in Features

### Error Tracking & Auto-escalation
- Logs every tier failure to `logs/errors.json`
- Same tier failing 3+ times → auto-generates a skip rule in `logs/rules.json`
- Script pre-checks `rules.json` before attempting a known-bad tier

### Token Cost Reference

| Tool / Scenario | Token Cost |
|----------------|------------|
| web_fetch (plain HTML) | ~100–500 |
| opencli (tweet) | ~200–700 |
| CDP (tweet via a11y tree) | ~700 |
| browser / OpenClaw full render | ~8000 ⚠️ |

> Source: [@runes_leo](https://x.com/runes_leo) benchmarks

## Related Projects

| Tool | GitHub |
|------|--------|
| opencli | https://github.com/jackwener/opencli |
| yt-dlp | https://github.com/yt-dlp/yt-dlp |
| chrome-cdp-skill | https://github.com/pasky/chrome-cdp-skill |
| x-cli | https://github.com/haloowhite/x-cli |
