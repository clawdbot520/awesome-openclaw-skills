# git-push-review

A checklist and safety scanner for publishing local OpenClaw skills to
[awesome-openclaw-skills](https://github.com/clawdbot520/awesome-openclaw-skills).

## What it does

1. **Scans** for hardcoded secrets, API keys, and sensitive files
2. **Checks** translation status (Chinese → English)
3. **Validates** folder structure
4. **Guides** the staging and push process

## Quick Start

```bash
# Install
cp -r git-push-review ~/.openclaw/skills/

# Run safety check on a skill
bash ~/.openclaw/skills/git-push-review/scripts/review.sh smart-scraper
```

## Publish Checklist

| Step | Action |
|------|--------|
| 1 | Run `review.sh <skill>` — fix any FAIL items |
| 2 | Translate SKILL.md and script comments to English |
| 3 | Stage with rsync (exclude logs/, .DS_Store, MEMORY_LANCEDB.md) |
| 4 | Copy to `~/repos/awesome-openclaw-skills/<skill>/` |
| 5 | Update README.md table + install instructions |
| 6 | `git add && git commit && git push` |

## Private vs Public

Use `private-openclaw-skills` (private repo) instead for skills with:
- Credentials that can't be removed from logic
- Personal infrastructure dependencies
- Proprietary prompts
