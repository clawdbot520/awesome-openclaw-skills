#!/bin/bash
# watcher.sh - 監聽 Kanban.md 變動，偵測 TODO 新增卡片時觸發 job.sh
#
# 觸發邏輯：
#   Todo 欄位卡片數量增加 → 有新任務進入 → 執行 job.sh
#
# 使用方式：
#   手動測試：bash watcher.sh
#   常駐服務：launchctl load ~/Library/LaunchAgents/com.clawdbot520.kanban-watcher.plist

KANBAN_DIR="$HOME/repos/Obsidian Vault/Task Kanban"
KANBAN_FILE="$KANBAN_DIR/Kanban.md"
JOB_SCRIPT="$HOME/.openclaw/skills/task-kanban-mcp/scripts/job.sh"
LOG_FILE="$HOME/.openclaw/skills/task-kanban-mcp/logs/watcher.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 取得 Todo 欄位的卡片數量
get_todo_count() {
    awk '/## 📅 Todo/{found=1; next} found && /^## /{found=0} found && /\[\[/' "$KANBAN_FILE" | wc -l | tr -d ' '
}

# 防止並發：job.sh 跑完之前不重複觸發
JOB_LOCK="/tmp/kanban-job.lock"

run_job() {
    if [[ -f "$JOB_LOCK" ]]; then
        log "job.sh already running (lock exists), skipping"
        return
    fi
    touch "$JOB_LOCK"
    log "Triggering job.sh..."
    bash "$JOB_SCRIPT" 2>&1 | while IFS= read -r line; do
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [job] $line" >> "$LOG_FILE"
    done
    rm -f "$JOB_LOCK"
    log "job.sh finished"
}

log "=== Kanban Watcher Started ==="
log "Watching: $KANBAN_FILE"

PREV_TODO=$(get_todo_count)
log "Initial Todo count: $PREV_TODO"

/opt/homebrew/bin/fswatch -0 --event=Updated --event=Created "$KANBAN_FILE" | while read -d "" event; do
    CURR_TODO=$(get_todo_count)

    if [[ "$CURR_TODO" -gt "$PREV_TODO" ]]; then
        log "Todo count: $PREV_TODO → $CURR_TODO (增加，觸發 job.sh)"
        run_job
    else
        log "Kanban changed (Todo: $PREV_TODO → $CURR_TODO, 無新任務)"
    fi

    PREV_TODO="$CURR_TODO"
done
