#!/bin/bash
# =============================================================================
# Smart Scraper - 7-tier decision engine
# =============================================================================
# Usage: smart_scrape <url> [options]
#   -t, --type     content type: text, image, video, audio, auto
#   -o, --output   output format: json, text
#   -v, --verbose  verbose output
# =============================================================================

# Not using set -e — this is a fallback machine; tier failures should not abort the script. 


# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT="${AGENT:-openclaw}"
LOG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/logs"
ERROR_LOG="$LOG_DIR/errors.json"
RULES_FILE="$LOG_DIR/rules.json"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Error tracking & pattern recognition
# -----------------------------------------------------------------------------
# Log a failure
log_error_to_file() {
    local url="$1"
    local tier="$2"
    local error="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Build error entry
    local error_entry=$(cat <<EOF
{
    "url": "$url",
    "tier": $tier,
    "error": "$error",
    "timestamp": "$timestamp"
}
EOF
)
    
    # Append to error log (JSONL)
    echo "$error_entry" >> "$ERROR_LOG"
    
    # Check whether to promote to a skip rule
    check_and_upgrade_rule "$url" "$tier" "$error"
}

# Promote failure to skip rule (quantified escalation pattern)
check_and_upgrade_rule() {
    local url="$1"
    local tier="$2"
    local error="$3"
    
    # Extract error pattern (simplified: grab error type)
    local error_pattern=$(echo "$error" | grep -oE "401|403|404|429|timeout|Unauthorized|Forbidden" | head -1)
    [[ -z "$error_pattern" ]] && error_pattern="other"
    
    # 統計這個 tier + error_pattern 的出現次數
    local count=$(grep -E "\"tier\":[[:space:]]*$tier" "$ERROR_LOG" 2>/dev/null | wc -l | xargs)
    
    # Threshold: same tier fails 3 times
    if [[ $count -ge 3 ]]; then
        log_warn "Tier $tier failed $count times — generating skip rule..."
        
        # Generate rule
        local rule_entry=$(cat <<EOF
{
    "tier": $tier,
    "pattern": "$error_pattern",
    "count": $count,
    "action": "skip_tier_$tier",
    "reason": "repeated failures — auto-skip"
}
EOF
)
        
        # Append to rules file
        echo "$rule_entry" >> "$RULES_FILE"
        
        # Update tier availability flags
        case $tier in
            1) tier1_available=false ;;
            2) tier2_available=false ;;
            3) tier3_available=false ;;
            4) tier4_available=false ;;
            5) tier5_available=false ;;
            6) tier6_available=false ;;
            7) tier7_available=false ;;
        esac
        
        log_info "Auto-generated rule: skip Tier $tier"
    fi
}

# Check if any skip rule applies to this tier
check_rules() {
    local tier="$1"
    
    if [[ ! -f "$RULES_FILE" ]]; then
        return 0
    fi
    
    # 检查是否有跳过此 tier 的规则
    if grep -q "\"action\":\"skip_tier_$tier\"" "$RULES_FILE" 2>/dev/null; then
        log_warn "Tier $tier disabled by auto-generated rule"
        return 1
    fi
    
    return 0
}

# -----------------------------------------------------------------------------
# Unified output format (JSON)
# -----------------------------------------------------------------------------
# Output format:
# {
#   "status": "success|error|partial",
#   "tier_used": 1-7,
#   "tool": "tool_name",
#   "content": "...",
#   "error": "error message if any",
#   "tokens": 1234,
#   "duration_ms": 1234,
#   "metadata": {}
# }

# -----------------------------------------------------------------------------
# Utility functions
# -----------------------------------------------------------------------------
log_info() { echo -e "${BLUE}[INFO]${NC} $1" 1>&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" 1>&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" 1>&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" 1>&2; }

# Parse arguments
parse_args() {
    URL=""
    CONTENT_TYPE="auto"
    OUTPUT_FORMAT="json"
    VERBOSE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--type) CONTENT_TYPE="$2"; shift 2 ;;
            -o|--output) OUTPUT_FORMAT="$2"; shift 2 ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -h|--help) usage; exit 0 ;;
            *) URL="$1"; shift ;;
        esac
    done

    if [[ -z "$URL" ]]; then
        log_error "URL is required"
        usage
        exit 1
    fi
}

usage() {
    echo "Usage: smart_scrape <url> [options]"
    echo ""
    echo "Options:"
    echo "  -t, --type TYPE   Content type: text, image, video, audio, auto (default: auto)"
    echo "  -o, --format FMT  Output format: json, text (default: json)"
    echo "  -v, --verbose     Verbose output"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Examples:"
    echo "  smart_scrape \"https://x.com/user/status/123\""
    echo "  smart_scrape \"https://youtube.com/watch?v=xxx\" -t video"
}

# -----------------------------------------------------------------------------
# Tier definitions and capability detection
# -----------------------------------------------------------------------------
# Initialize tier availability flags
tier1_available=false
tier2_available=false
tier3_available=false
tier4_available=false
tier5_available=false
tier6_available=false
tier7_available=false

# Detect agent capabilities
detect_agent_capabilities() {
    # Tier 1: opencli (public) — requires install + token
    if command -v opencli &> /dev/null && [[ -n "$PLAYWRIGHT_MCP_EXTENSION_TOKEN" ]]; then
        tier1_available=true
        log_info "Tier 1 (opencli public): available"
    else
        tier1_available=false
        log_warn "Tier 1 (opencli public): not available (not installed or no token)"
    fi
    
    # Tier 2: web_fetch — always available via curl
    tier2_available=true
    log_info "Tier 2 (web_fetch): available"
    
    # Tier 3: yt-dlp
    if command -v yt-dlp &> /dev/null; then
        tier3_available=true
        log_info "Tier 3 (yt-dlp): available"
    else
        tier3_available=false
        log_warn "Tier 3 (yt-dlp): not available"
    fi
    
    # Tier 4: web_search — only available in MCP environments (openclaw/antigravity)
    case "$AGENT" in
        openclaw|antigravity)
            tier4_available=true
            log_info "Tier 4 (web_search): available (MCP tool)"
            ;;
        *)
            tier4_available=false
            log_warn "Tier 4 (web_search): not available for $AGENT (MCP-only)"
            ;;
    esac
    
    # Tier 5: opencli (cookie) — requires install + login
    if command -v opencli &> /dev/null; then
        tier5_available=true
        log_info "Tier 5 (opencli cookie): available"
    else
        tier5_available=false
        log_warn "Tier 5 (opencli cookie): not available"
    fi
    
    # Tier 6: CDP — check bundled chrome-cdp first
    tier6_available=false
    if [[ -f "$SCRIPT_DIR/../chrome-cdp/scripts/cdp.mjs" ]]; then
        tier6_available=true
        log_info "Tier 6 (CDP): available (local)"
    elif [[ -d "$HOME/.openclaw/skills/chrome-cdp-skill" ]]; then
        tier6_available=true
        log_info "Tier 6 (CDP): available (skill)"
    else
        log_warn "Tier 6 (CDP): not available"
    fi
    
    # Tier 7: browser — built-in for openclaw/antigravity only
    case "$AGENT" in
        openclaw|antigravity)
            tier7_available=true
            log_info "Tier 7 (browser): available"
            ;;
        claude-code|codex)
            tier7_available=false
            log_warn "Tier 7 (browser): not available for $AGENT"
            ;;
    esac
}

# Determine tier priority order based on content type
get_priority_tiers() {
    local url="$1"
    local content_type="$2"
    
    # --- Platform-specific fast paths (skip known-bad tiers) ---
    if [[ "$url" == *facebook.com* || "$url" == *instagram.com* ]]; then
        # FB/IG: opencli has limited effect; jump straight to Tier 6 (CDP)
        echo "6 7"
        return
    fi

    case "$content_type" in
        video|audio)
            # Video/audio: prefer yt-dlp
            echo "3 2 6 7 4"  # yt-dlp > web_fetch > CDP > browser > web_search
            ;;
        image)
            # Images: prefer web_fetch
            echo "2 6 7 4 1 5"  # web_fetch > CDP > browser > web_search > opencli
            ;;
        *)
            # Text (default): prefer web_fetch → web_search → opencli
            echo "2 4 1 5 6 7 3"  # web_fetch > web_search > opencli > CDP > browser > yt-dlp
            ;;
    esac
}

# -----------------------------------------------------------------------------
# 各 Tier 实现
# -----------------------------------------------------------------------------

# Tier 1: opencli
tier1_opencli() {
    local url="$1"
    local start_time=$(date +%s000)
    
    log_info "Trying Tier 1: opencli"
    
    # Requires PLAYWRIGHT_MCP_EXTENSION_TOKEN
    if [[ -z "$PLAYWRIGHT_MCP_EXTENSION_TOKEN" ]]; then
        log_warn "Tier 1: No token"
        return 1
    fi
    
    # Infer platform and command from URL
    local platform=""
    local cmd=""
    
    case "$url" in
        *twitter.com*|*x.com*)
            platform="twitter"
            # Choose command based on URL path
            if [[ "$url" == *"/status/"* ]]; then
                cmd="thread"
            elif [[ "$url" == *"/search"* ]]; then
                cmd="search"
            else
                cmd="trending"
            fi
            ;;
        *youtube.com*)
            platform="youtube"
            cmd="search"
            ;;
        *bilibili.com*)
            platform="bilibili"
            if [[ "$url" == *"/video/"* ]]; then
                cmd="cascade" # No direct video view for Bilibili; use cascade
            else
                cmd="hot"
            fi
            ;;
        *reddit.com*)
            platform="reddit"
            # Reddit frontpage
            cmd="frontpage"
            ;;
        *news.ycombinator.com*)
            platform="hackernews"
            cmd="top"
            ;;
        *facebook.com*|*instagram.com*)
            # FB/IG: no dedicated opencli command, try cascade via extension
            platform="" 
            log_info "Tier 1: trying opencli cascade for $url"
            cmd="cascade"
            ;;
        *github.com*)
            platform="github"
            cmd="search"
            ;;
        *)
            log_warn "Tier 1: Unknown platform for opencli, trying cascade"
            cmd="cascade" # Unknown platform: try opencli cascade
            ;;
    esac
    
    if [[ -n "$platform" || "$cmd" == "cascade" ]]; then
        local output
        log_info "Executing: opencli ${platform:-""} $cmd for $url"
        
        # Build command
        if [[ "$cmd" == "cascade" ]]; then
            output=$(PLAYWRIGHT_MCP_EXTENSION_TOKEN="$PLAYWRIGHT_MCP_EXTENSION_TOKEN" opencli cascade "$url" 2>&1 || echo "")
        else
            output=$(PLAYWRIGHT_MCP_EXTENSION_TOKEN="$PLAYWRIGHT_MCP_EXTENSION_TOKEN" opencli "$platform" "$cmd" "$url" 2>&1 || echo "")
        fi
        
        local end_time=$(date +%s000)
        local duration=$((end_time - start_time))
        
        if [[ -n "$output" && ${#output} -gt 50 ]]; then
            echo "{\"status\":\"success\",\"tier_used\":1,\"tool\":\"opencli\",\"content\":\"${output:0:10000}\",\"tokens\":500,\"duration_ms\":$duration}"
            return 0
        fi
    fi
    
    return 1
}

# Tier 2: web_fetch
tier2_web_fetch() {
    local url="$1"
    local start_time=$(date +%s000)
    
    log_info "Trying Tier 2: web_fetch"

    # Antigravity: prefer native read_url_content tool over curl
    if [[ "$AGENT" == "antigravity" ]]; then
        log_info "Antigravity: prefer native read_url_content tool over this curl path"
    fi

    # claude-code: prefer WebFetch tool (handles redirects/encoding better than curl)
    if [[ "$AGENT" == "claude-code" ]]; then
        log_info "claude-code: prefer WebFetch tool in conversation over this curl path"
    fi
    
    # Fetch via curl (or Python fallback)
    local content
    if command -v curl &> /dev/null; then
        content=$(curl -s -L --max-time 30 "$url" 2>/dev/null || echo "")
    else
        # Python fallback
        content=$(python3 -c "
import urllib.request
import sys
try:
    req = urllib.request.Request('$url', headers={'User-Agent': 'Mozilla/5.0'})
    print(urllib.request.urlopen(req, timeout=30).read().decode('utf-8', errors='ignore'))
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
" 2>/dev/null || echo "")
    fi
    
    local end_time=$(date +%s000)
    local duration=$((end_time - start_time))
    
    if [[ -n "$content" && ${#content} -gt 100 ]]; then
        local tokens=$((${#content} / 4))
        echo "{\"status\":\"success\",\"tier_used\":2,\"tool\":\"web_fetch\",\"content\":\"${content:0:10000}\",\"tokens\":$tokens,\"duration_ms\":$duration}"
        return 0
    fi
    return 1
}

# Tier 3: yt-dlp
tier3_yt_dlp() {
    local url="$1"
    local start_time=$(date +%s000)
    
    log_info "Trying Tier 3: yt-dlp"
    
    # Only proceed for video/audio URLs
    if ! echo "$url" | grep -qE "youtube\.com|youtu\.be|podcast|mp3|wav|video"; then
        return 1
    fi
    
    if ! command -v yt-dlp &> /dev/null; then
        return 1
    fi
    
    local output
    output=$(yt-dlp --dump-json --no-download "$url" 2>/dev/null || echo "")
    
    local end_time=$(date +%s000)
    local duration=$((end_time - start_time))
    
    if [[ -n "$output" ]]; then
        echo "{\"status\":\"success\",\"tier_used\":3,\"tool\":\"yt-dlp\",\"content\":\"${output:0:10000}\",\"tokens\":500,\"duration_ms\":$duration}"
        return 0
    fi
    return 1
}

# Tier 4: web_search (需要 OpenClaw tool 或 Brave API)
tier4_web_search() {
    local url="$1"
    local start_time=$(date +%s000)
    
    log_info "Trying Tier 4: web_search"
    
    # web_search requires native MCP tool — shell cannot call it
    if [[ "$AGENT" == "antigravity" ]]; then
        log_info "antigravity: use native search_web tool instead"
        return 1
    fi
    if [[ "$AGENT" == "claude-code" ]]; then
        log_info "claude-code: use WebSearch tool directly in conversation"
        return 1
    fi
    log_warn "Tier 4: web_search requires MCP tool (openclaw/antigravity only)"
    return 1
}

# Tier 6: CDP
tier6_cdp() {
    local url="$1"
    local start_time=$(date +%s000)
    
    log_info "Trying Tier 6: CDP"
    
    # 優先使用腳本目錄下的路徑
    local cdp_script="$SCRIPT_DIR/../chrome-cdp/scripts/cdp.mjs"
    [[ ! -f "$cdp_script" ]] && cdp_script="$HOME/.openclaw/skills/chrome-cdp-skill/skills/chrome-cdp/scripts/cdp.mjs"
    
    if [[ ! -f "$cdp_script" ]]; then
        log_warn "Tier 6: CDP script not found at $cdp_script"
        return 1
    fi
    
    # 1. Open a new tab and navigate to the URL
    log_info "CDP: Opening new tab for $url..."
    local open_res
    open_res=$(node "$cdp_script" open "$url" 2>/dev/null)
    
    # Extract target ID from output (e.g. "Opened new tab: 56c18f02")
    local target_id
    target_id=$(echo "$open_res" | grep -oE "[a-f0-9]{8}" | head -1)
    
    if [[ -z "$target_id" ]]; then
        log_warn "Tier 6: Failed to open new tab via CDP"
        return 1
    fi
    
    # 2. Wait for page load (CDP open is non-blocking)
    log_info "CDP: Tab opened ($target_id), waiting for load..."
    sleep 3
    
    # 3. Get accessibility tree snapshot
    local output
    output=$(node "$cdp_script" snap "$target_id" 2>/dev/null | head -c 10000 || echo "")
    
    local end_time=$(date +%s000)
    local duration=$((end_time - start_time))
    
    if [[ -n "$output" && ${#output} -gt 50 ]]; then
        # 4. Optionally stop the daemon to save resources
        # node "$cdp_script" stop "$target_id" &> /dev/null
        
        echo "{\"status\":\"success\",\"tier_used\":6,\"tool\":\"cdp\",\"content\":\"${output:0:10000}\",\"tokens\":700,\"duration_ms\":$duration}"
        return 0
    fi
    
    # Cleanup on failure
    node "$cdp_script" stop "$target_id" &> /dev/null
    return 1
}

# Tier 7: browser (需要 OpenClaw)
tier7_browser() {
    local url="$1"
    local start_time=$(date +%s000)
    
    # Tier 7: browser
    if [[ "$AGENT" == "antigravity" ]]; then
        log_info "Antigravity detected: Delegating to 'browser_subagent' for complex rendering/auth."
        return 1
    fi
    
    # Call external browser script if available
    if [[ -f "$SCRIPT_DIR/tier_browser.sh" ]]; then
        local output
        output=$("$SCRIPT_DIR/tier_browser.sh" "$url" 2>/dev/null || echo "")
        
        local end_time=$(date +%s000)
        local duration=$((end_time - start_time))
        
        if [[ -n "$output" ]]; then
            echo "{\"status\":\"success\",\"tier_used\":7,\"tool\":\"browser\",\"content\":\"${output:0:10000}\",\"tokens\":8000,\"duration_ms\":$duration}"
            return 0
        fi
    fi
    
    return 1
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    
    log_info "Smart Scraper — 7-tier framework"
    log_info "Agent: $AGENT"
    log_info "URL: $URL"
    log_info "Content Type: $CONTENT_TYPE"
    echo ""
    
    # Detect capabilities
    detect_agent_capabilities
    
    # Get tier priority order
    PRIORITY_TIERS=$(get_priority_tiers "$URL" "$CONTENT_TYPE")
    log_info "Priority tiers: $PRIORITY_TIERS"
    echo ""
    
    # Try each tier
    for tier in $PRIORITY_TIERS; do
        local available=false
        
        case $tier in
            1) [[ "$tier1_available" == "true" ]] && available=true ;;
            2) [[ "$tier2_available" == "true" ]] && available=true ;;
            3) [[ "$tier3_available" == "true" ]] && available=true ;;
            4) [[ "$tier4_available" == "true" ]] && available=true ;;
            5) [[ "$tier5_available" == "true" ]] && available=true ;;
            6) [[ "$tier6_available" == "true" ]] && available=true ;;
            7) [[ "$tier7_available" == "true" ]] && available=true ;;
        esac
        
        if [[ "$available" != "true" ]]; then
            log_warn "Tier $tier: not available, skipping"
            continue
        fi

        # 檢查規則是否禁用此 tier
        if ! check_rules "$tier"; then
            continue
        fi
        
        log_info "=== Attempting Tier $tier ==="
        
        case $tier in
            1) result=$(tier1_opencli "$URL") ;;
            2) result=$(tier2_web_fetch "$URL") ;;
            3) result=$(tier3_yt_dlp "$URL") ;;
            4) result=$(tier4_web_search "$URL") ;;
            6) result=$(tier6_cdp "$URL") ;;
            7) result=$(tier7_browser "$URL") ;;
            *) 
                log_warn "Tier $tier: not implemented"
                continue
                ;;
        esac
        
        if [[ -n "$result" ]]; then
            log_success "Tier $tier succeeded"
            echo "$result"
            exit 0
        else
            log_warn "Tier $tier failed — trying next tier"
            # Log failure for pattern detection
            log_error_to_file "$URL" "$tier" "failed"
        fi
    done
    
    # All tiers failed
    log_error "All tiers failed!"
    log_error_to_file "$URL" 0 "all_failed"
    echo '{"status":"error","tier_used":null,"tool":null,"content":null,"error":"All 7 tiers failed","tokens":0,"duration_ms":0}'
    exit 1
}

# Run
main "$@"
