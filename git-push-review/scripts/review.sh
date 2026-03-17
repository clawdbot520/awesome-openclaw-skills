#!/bin/bash
# =============================================================================
# git-push-review — Pre-publish safety check for OpenClaw skills
# =============================================================================
# Usage: review.sh <skill-name>
#   Scans ~/.openclaw/skills/<skill-name>/ for sensitive data before publishing.
#
# Exit codes:
#   0 = clean, safe to publish
#   1 = issues found, review required
# =============================================================================

set -euo pipefail

SKILL="${1:?Usage: review.sh <skill-name>}"
SKILL_DIR="$HOME/.openclaw/skills/$SKILL"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC}  $1"; }
log_info() { echo -e "${BLUE}[INFO]${NC}  $1"; }

ISSUES=0

echo ""
log_info "=== git-push-review: $SKILL ==="
echo ""

# --- 1. Directory exists ---
if [[ ! -d "$SKILL_DIR" ]]; then
    log_fail "Skill directory not found: $SKILL_DIR"
    exit 1
fi
log_ok "Skill directory found: $SKILL_DIR"

# --- 2. Required files ---
[[ -f "$SKILL_DIR/SKILL.md" ]] && log_ok "SKILL.md exists" || { log_fail "SKILL.md missing"; ISSUES=$((ISSUES+1)); }

# --- 3. Dangerous files ---
echo ""
log_info "Checking for sensitive files..."

DANGEROUS_FILES=(
    "auth-profiles.json"
    "device-auth.json"
    "MEMORY_LANCEDB.md"
)
for f in "${DANGEROUS_FILES[@]}"; do
    if find "$SKILL_DIR" -name "$f" | grep -q .; then
        log_fail "Found sensitive file: $f — MUST exclude from publish"
        ISSUES=$((ISSUES+1))
    fi
done

# credentials/ directory
if [[ -d "$SKILL_DIR/credentials" ]]; then
    log_fail "Found credentials/ directory — MUST exclude"
    ISSUES=$((ISSUES+1))
fi

# --- 4. Hardcoded secrets in code ---
echo ""
log_info "Scanning for hardcoded secrets..."

SECRET_PATTERNS=(
    "PLAYWRIGHT_MCP_EXTENSION_TOKEN=['\"][^$]"
    "api_key\s*=\s*['\"][a-zA-Z0-9]"
    "password\s*=\s*['\"][^']"
    "Bearer [a-zA-Z0-9_\-]"
    "sk-[a-zA-Z0-9]"
    "tvly-[a-zA-Z0-9]"
)

for pattern in "${SECRET_PATTERNS[@]}"; do
    MATCHES=$(grep -rn --include="*.sh" --include="*.js" --include="*.ts" \
        --include="*.json" --include="*.md" \
        -E "$pattern" "$SKILL_DIR" 2>/dev/null \
        | grep -v "\.git" | grep -v "your_token" | grep -v "example" | grep -v "placeholder" || true)
    if [[ -n "$MATCHES" ]]; then
        log_fail "Possible hardcoded secret (pattern: $pattern):"
        echo "$MATCHES" | head -3 | sed 's/^/         /'
        ISSUES=$((ISSUES+1))
    fi
done

# --- 5. Chinese content check ---
echo ""
log_info "Checking for untranslated Chinese content in SKILL.md..."
if grep -qP "[\x{4e00}-\x{9fff}]" "$SKILL_DIR/SKILL.md" 2>/dev/null; then
    log_warn "SKILL.md contains Chinese characters — translate before publishing"
    ISSUES=$((ISSUES+1))
else
    log_ok "SKILL.md appears to be in English"
fi

# --- 6. Logs directory ---
if [[ -d "$SKILL_DIR/logs" ]]; then
    log_warn "logs/ directory found — ensure it's in .gitignore"
fi

# --- 7. .gitignore check ---
if [[ -f "$SKILL_DIR/.gitignore" ]]; then
    log_ok ".gitignore exists"
else
    log_warn ".gitignore missing — recommend adding one"
fi

# --- Summary ---
echo ""
if [[ $ISSUES -eq 0 ]]; then
    log_ok "=== CLEAN — safe to publish to awesome-openclaw-skills ==="
    echo ""
    echo "  Next steps:"
    echo "  1. Translate any remaining Chinese comments in scripts"
    echo "  2. cp -r $SKILL_DIR /tmp/${SKILL}-pub (exclude logs/, .DS_Store)"
    echo "  3. cp -r /tmp/${SKILL}-pub ~/repos/awesome-openclaw-skills/$SKILL"
    echo "  4. Update README.md table"
    echo "  5. git add && git commit && git push"
    exit 0
else
    log_fail "=== $ISSUES ISSUE(S) FOUND — fix before publishing ==="
    exit 1
fi
