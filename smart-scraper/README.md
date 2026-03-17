# smart-scraper

A 7-tier intelligent web scraping framework for AI agents. Starts with the fastest, cheapest method and automatically falls back to heavier tools on failure.

## How It Works

```
URL → detect content type → try tiers in order → auto-fallback → result
```

| Tier | Tool | Token Cost | Auth |
|------|------|-----------|------|
| 1 | opencli (public) | free | ❌ |
| 2 | web_fetch / curl | low | ❌ |
| 3 | yt-dlp | low | optional |
| 4 | web_search | low | ❌ |
| 5 | opencli (cookie) | medium | ✅ |
| 6 | CDP | medium | ✅ (reuses Chrome login) |
| 7 | browser | high (~8000 tokens) | optional |

## Quick Start

```bash
# Basic usage
~/.openclaw/skills/smart-scraper/scripts/smart_scrape.sh "https://news.ycombinator.com"

# Video
~/.openclaw/skills/smart-scraper/scripts/smart_scrape.sh "https://youtube.com/watch?v=..." -t video

# With opencli token
PLAYWRIGHT_MCP_EXTENSION_TOKEN="your_token" ./scripts/smart_scrape.sh "https://x.com/..."
```

## Requirements

```bash
npm install -g @jackwener/opencli   # Tier 1/5
brew install yt-dlp                  # Tier 3
# CDP is bundled — no install needed
```

## Related

- [opencli](https://github.com/jackwener/opencli)
- [chrome-cdp-skill](https://github.com/pasky/chrome-cdp-skill)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
