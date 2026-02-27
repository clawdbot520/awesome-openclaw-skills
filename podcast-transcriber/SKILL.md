---
name: podcast-transcriber
description: Automatically transcribe Podcast audio to text. Use when user says "transcribe", "transcript", "generate notes" for Podcast audio, or "convert OOO to text".
---

# Podcast Transcriber

Automatically convert Podcast audio to text (full transcript or key points summary).

## User Input (Interactive)

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| Channel Name | ✅ | - | Podcast name, e.g., "股癌" |
| Episode | ❌ | Latest | Specific episode, e.g., "EP639" or "639" |
| Format | ❌ | `full` | `full`=full text, `summary`=key points only |

## Output Format

| Format | Description |
|--------|-------------|
| **full** | Whisper output, all content preserved |
| **summary** | Filtered: ads/promos removed, core content only (good for investment/tech) |

## Workflow

```
1. Apple Podcasts API Search → Get feedUrl
2. yt-dlp Download audio (.mp3)
3. faster-whisper Transcribe (.txt)
4. Key points filter (if summary selected)
```

## Usage

### Conversation Example

```
User: Transcribe 股癌

AI: Which episode? (Press Enter for latest)
User: EP639

AI: Full text or key points summary?
User: Key points

→ Auto-process → Output transcript
```

### Command Line

```bash
# Latest episode + full text
python3 scripts/transcribe.py --podcast "<podcast_name>"

# Specific episode
python3 scripts/transcribe.py --podcast "<podcast_name>" --episode 639

# Key points summary
python3 scripts/transcribe.py --podcast "<podcast_name>" --format summary
```

## Tech Stack

| Layer | Tool |
|-------|------|
| Search | Apple Podcasts API |
| Download | yt-dlp |
| Transcribe | faster-whisper (tiny model) |
| Output | .txt file |

## Installation Requirements

- `yt-dlp` → `brew install yt-dlp`
- `ffmpeg` → `brew install ffmpeg`
- `faster-whisper` → Python venv (`/tmp/whisper-venv`)

## Output Location

Default: `/tmp/podcast-transcribe/`

- `<podcast_name>.txt` - Full text
- `<podcast_name>_摘要.txt` - Key points summary

## Supported Platforms

- SoundOn
- Firstory
- Apple Podcasts
- Any Podcast with RSS feed
