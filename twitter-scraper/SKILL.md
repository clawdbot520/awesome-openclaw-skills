---
name: twitter_scraper
description: >
  Daily Twitter/X trending tweets scraping and NotebookLM upload. Use when user says "scrape Twitter", "抓推文", or "Twitter trends".
---

# Twitter Scraper

Daily trending tweets extraction and NotebookLM sync.

## User Input (Interactive)

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| Date | ❌ | Yesterday | Format: YYYY-MM-DD |

## Workflow

```
1. Open browser (openclaw profile, no extension needed)
2. Login to Twitter (account: username, session persisted)
3. Scrape trending tweets from For You + Following (past 24h)
4. Summarize key points (not full text)
5. Save as YYYY-MM-DD_twitter-trends.md
6. Upload to NotebookLM Marketing notebook
7. Send summary to Telegram
```

## Usage

### Conversation Example

```
User: scrape Twitter

AI: → Auto-scrape yesterday's tweets
    → Save to workspace
    → Upload to NotebookLM
    → Send summary
```

### Command Line

```bash
# Manual execution (via cron)
# Runs daily at 7:00 AM (Asia/Taipei)
```

## Output Location

```
~/.openclaw/workspace-2nd-brain/YYYY-MM-DD_twitter-trends.md
```

Example: `2026-02-28_twitter-trends.md`

## NotebookLM

- Target notebook: **Marketing**
- Upload command:
  ```bash
  source ~/.openclaw/skills/notebooklm-py/.venv/bin/activate
  notebooklm use Marketing
  notebooklm source add ~/.openclaw/workspace-2nd-brain/2026-02-28_twitter-trends.md
  ```

## Tech Stack

| Layer | Tool |
|-------|------|
| Browser | OpenClaw browser (openclaw profile) |
| Login | username (session persisted) |
| Summarization | LLM |
| Storage | Local MD file |
| Sync | notebooklm-cli |

## Browser Configuration

- Uses `openclaw` profile (no Chrome extension required)
- Session persisted - no re-login needed

## Cron Schedule

- Time: 7:00 AM daily (Asia/Taipei)
- Expression: `0 7 * * *`

## Example Output

```markdown
# X/Twitter Trending Summary (2026-02-28)

> Source: Twitter/X For You + Following
> Date: 2026-02-28

---

## 🔥 Top Topics

### 1. [Title]
- **Source**: @username
- **Content**: Summary...
- **Views**: XXK
- **Tags**: #AI #...

---

## 📊 Summary

Today's highlights:
- Point 1
- Point 2
- Point 3
```
