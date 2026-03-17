---
name: git-push-review
description: >
  Review and publish a local OpenClaw skill to awesome-openclaw-skills on GitHub.
  Handles translation, sensitive data scrubbing, folder structure validation, and push.
  Trigger: user says "publish skill XXX", "push XXX to awesome-openclaw-skills", "發布 XXX 到 git".
---

# git-push-review

A checklist-driven workflow for safely publishing a local OpenClaw skill to the public
[awesome-openclaw-skills](https://github.com/clawdbot520/awesome-openclaw-skills) repo.

---

## Workflow

### Step 1 — Scan for sensitive data

Before anything else, check the skill directory for credentials:

```bash
SKILL_DIR="$HOME/.openclaw/skills/<skill-name>"

# Check for hardcoded secrets
grep -rn "token\|api_key\|password\|secret\|PLAYWRIGHT_MCP" "$SKILL_DIR" \
  --include="*.sh" --include="*.js" --include="*.ts" --include="*.json" \
  | grep -v "\.git" | grep -v "your_token_here"
```

**Must NOT publish:**
- `auth-profiles.json` — contains API keys (MiniMax, etc.)
- `device-auth.json` — contains device tokens
- `credentials/` — Telegram bot tokens, etc.
- `logs/` — may contain URLs or user data
- `MEMORY_LANCEDB.md` — internal LanceDB directives
- `.DS_Store`
- Any file with hardcoded tokens/passwords

**Safe to publish:**
- `SKILL.md`
- `scripts/*.sh` — as long as secrets come from env vars, not hardcoded
- `chrome-cdp/`, `src/`, `lib/` — source code
- `README.md`

---

### Step 2 — Translate to English

All user-facing content must be in English for the public repo.

Files to translate:
1. **SKILL.md** — description, tables, usage examples
2. **Script comments** — Chinese `#` comments in `.sh` / `.js` files
3. **README.md** — write a new one if it doesn't exist

Keep internal variable names as-is (no need to rename Chinese variables).

Translation checklist:
- [ ] SKILL.md frontmatter description → English
- [ ] All section headings → English
- [ ] Script `# 注释` → English `# comment`
- [ ] Log messages (`log_info "..."`) → English

---

### Step 3 — Validate folder structure

Required structure for every skill:

```
<skill-name>/
├── SKILL.md          ← required: name, description, usage
├── README.md         ← required: quick start for GitHub viewers
├── scripts/          ← required if there are executable scripts
│   └── *.sh
└── .gitignore        ← recommended: exclude logs/, .DS_Store, node_modules/
```

Optional but common:
```
├── chrome-cdp/       ← bundled CDP engine
├── src/ or lib/      ← source code
└── examples/         ← usage examples
```

**Do NOT include:**
```
logs/                 ← runtime data, excluded by .gitignore
node_modules/         ← reinstallable
*.env                 ← credentials
MEMORY_LANCEDB.md     ← internal only
auth-profiles.json    ← credentials
```

---

### Step 4 — Prepare staging directory

```bash
SKILL="smart-scraper"
STAGING="/tmp/${SKILL}-pub"

mkdir -p "$STAGING/scripts"

# Copy files (excluding sensitive/runtime files)
rsync -av \
  --exclude='.git' \
  --exclude='logs/' \
  --exclude='node_modules/' \
  --exclude='.DS_Store' \
  --exclude='MEMORY_LANCEDB.md' \
  --exclude='auth-profiles.json' \
  --exclude='*.env' \
  "$HOME/.openclaw/skills/$SKILL/" "$STAGING/"
```

---

### Step 5 — Push to awesome-openclaw-skills

```bash
REPO="$HOME/repos/awesome-openclaw-skills"
SKILL="smart-scraper"
DESCRIPTION="7-tier intelligent web scraping framework"

# Ensure repo is up to date
cd "$REPO" && git pull

# Copy staged files (no nested .git)
cp -r "$STAGING" "$REPO/$SKILL"

# Update README table
# Add row: | [skill](./skill/) | description |
# Add install line: cp -r skill ~/.openclaw/skills/

# Commit and push
git add "$SKILL/" README.md
git commit -m "Add $SKILL skill: $DESCRIPTION"
git push
```

---

### Step 6 — Update README.md

Add the skill to the table in `awesome-openclaw-skills/README.md`:

```markdown
| [skill-name](./skill-name/) | One-line English description |
```

And add the install command:
```bash
cp -r skill-name ~/.openclaw/skills/
```

---

## Quick Reference — What to Exclude

| File / Pattern | Reason |
|---------------|--------|
| `auth-profiles.json` | API keys |
| `identity/device-auth.json` | Device tokens |
| `credentials/` | Bot tokens |
| `logs/` | Runtime data, may contain URLs |
| `MEMORY_LANCEDB.md` | Internal LanceDB directive |
| `.DS_Store` | macOS metadata |
| `node_modules/` | Reinstallable |
| Hardcoded tokens | Use env vars instead |

## Private vs Public

If a skill has **sensitive dependencies or credentials that can't be removed**, publish it to
`private-openclaw-skills` (private repo) instead of `awesome-openclaw-skills` (public repo).

Examples of private-only skills:
- Skills that embed specific API keys in logic
- Skills tied to personal infrastructure
- Skills with proprietary prompts
