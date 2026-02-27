# Podcast Transcriber Skill - podcast-transcriber

> Automatically convert Podcast audio to text (full transcript or key points summary)

---

## 🎯 Purpose

**Let users just say the Podcast name, and automatically generate the transcript.**

Previously required:
1. Manually search RSS
2. Download audio
3. Transcribe with Whisper
4. Filter ads/chitchat

**Now**: Tell AI which Podcast to transcribe, and it handles everything automatically.

---

## 📋 Features

### Input Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `podcast` | ✅ | - | Podcast channel name (e.g., 股癌, 豬探長推理故事集) |
| `episode` | ❌ | Latest | Specific episode (e.g., EP639, 636) |
| `format` | ❌ | `full` | `full`=full text, `summary`=key points |

### Output

- **full**: Whisper output, all content preserved
- **summary**: Filtered ads/promos/chitchat, core knowledge only

### Supported Platforms

- SoundOn
- Firstory
- Apple Podcasts
- Any Podcast with RSS feed

---

## 🔧 Tech Stack

| Layer | Tool |
|-------|------|
| RSS Search | Apple Podcasts API |
| Audio Download | yt-dlp |
| Transcription | faster-whisper (tiny model) |
| Output | .txt file |

### Installation

- `yt-dlp` → `brew install yt-dlp`
- `ffmpeg` → `brew install ffmpeg`
- `faster-whisper` → Python venv (`/tmp/whisper-venv`)

---

## 📁 File Structure

```
podcast-transcriber/
├── SKILL.md                    # Skill trigger conditions & workflow
├── podcast-transcriber-skill.md # Detailed documentation
└── scripts/
    └── transcribe.py            # Core transcription script
```

**Output location**: `/tmp/podcast-transcribe/`

---

## 🚀 Usage

### Conversation Example

```
User: 股癌 EP637 give me a 300-word summary

AI:
→ Search RSS for "股癌"
→ Download EP637 audio
→ Whisper transcription
→ Generate key points
→ Output result
```

### Command Line

```bash
# Latest episode + full text
python3 scripts/transcribe.py --podcast "股癌"

# Specific episode
python3 scripts/transcribe.py --podcast "股癌" --episode 637

# Key points summary (good for investment/tech content)
python3 scripts/transcribe.py --podcast "股癌" --format summary
```

---

## 📝 Use Cases

### ✅ Good For

- **Investment Podcasts**: 股癌, Mirror → Generate investment key points
- **Tech Podcasts**: Industry trends, tech analysis
- **Children Stories**: 豬探長推理故事集 → Story content

### ⚠️ Notes

1. **Processing time**: ~3-5 minutes (depends on audio length)
2. **Whisper accuracy**: ~90-95%, some accents/technical terms may be wrong
3. **Key points filter**: Simple keyword-based, may have false positives

---

## 🔄 Future Plans

- [ ] Auto-upload to NotebookLM
- [ ] Cron job for weekly auto-fetch
- [ ] More accurate key points filtering (using LLM)
- [ ] Translation support (EN→ZH)

---

## 📊 Test Cases

| Podcast | Platform | Episode | Status |
|---------|----------|---------|--------|
| 股癌 | SoundOn | EP637 | ✅ Transcribed |
| 股癌 | SoundOn | EP636 | ✅ Transcribed |
| 豬探長推理故事集 | Firstory | EP120 | ✅ Downloadable |

---

## 💡 How to Trigger

When user says:
- "transcribe"
- "transcript"
- "generate notes"
- "convert OOO to text"
- "generate key points for OOO"

---

## 📌 Quick Commands

```bash
# Navigate to skill
cd podcast-transcriber

# Test run
python3 scripts/transcribe.py --podcast "test" --help
```

---

> **Created**: 2026-02-27
> **Author**: 2nd Brain (第二大腦)
> **Skill**: podcast-transcriber v1.0
> **License**: Apache 2.0
