#!/bin/bash
# Task Kanban Job Script
# 掃描 Todo → 依序執行所有 steps → 進 Review
# 多步驟任務在同一個 run 內完成，卡片全程在 In Progress

set -e

KANBAN_DIR="$HOME/repos/Obsidian Vault/Task Kanban"
KANBAN_FILE="$KANBAN_DIR/Kanban.md"
TASK_DIR="$KANBAN_DIR/task"
QUEUE_SCRIPT="$HOME/.openclaw/task-queue/add_task.sh"
CLAUDE="${CLAUDE_CODE_BIN:-$HOME/.local/bin/claude}"
LOG_FILE="$HOME/.openclaw/skills/task-kanban-mcp/logs/job.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

get_yaml_field() {
    local file="$1" field="$2"
    sed -n "s/^${field}: *//p" "$file" | head -1
}

get_todo_tasks() {
    local in_todo=false
    while IFS= read -r line; do
        [[ "$line" == *"## 📅 Todo"* ]] && in_todo=true && continue
        [[ "$in_todo" == true && "$line" =~ \[\[([^\]]+)\]\] ]] && echo "${BASH_REMATCH[1]}"
        [[ "$in_todo" == true && "$line" =~ ^## ]] && break
    done < "$KANBAN_FILE"
}

move_card() {
    local task_name="$1" to_status="$2" target_section=""
    case "$to_status" in
        "running") target_section="## 🚀 In Progress" ;;
        "review")  target_section="## 👀 Review" ;;
        "done")    target_section="## ✅ Done" ;;
        "blocked") target_section="## 🚫 Blocked" ;;
        "todo")    target_section="## 📅 Todo" ;;
        *) log "Unknown status: $to_status"; return 1 ;;
    esac
    sed -i '' "s/^- \[ \] \[\[$task_name\]\]$//" "$KANBAN_FILE"
    sed -i '' "s/^- \[x\] \[\[$task_name\]\]$//" "$KANBAN_FILE"
    sed -i '' "/$target_section/a\\
- [ ] [[$task_name]]" "$KANBAN_FILE"
}

# 推進到下一步，更新 YAML
# 返回 0 = 有下一步；返回 1 = 已是最後一步
advance_task() {
    local task_file="$1"
    local current_step next_step next_assignee

    current_step=$(get_yaml_field "$task_file" "current_step")
    [[ -z "$current_step" ]] && return 1  # 無 step 設定 → 單步任務，直接完成

    next_step=$((current_step + 1))
    next_assignee=$(get_yaml_field "$task_file" "step${next_step}")

    if [[ -n "$next_assignee" ]]; then
        sed -i '' "s/^assignee: .*/assignee: $next_assignee/" "$task_file"
        sed -i '' "s/^current_step: .*/current_step: $next_step/" "$task_file"
        log "NEXT: step${next_step} → $next_assignee"
        return 0
    else
        return 1
    fi
}

# 執行單一步驟
# 返回 0 = 同步完成，可繼續 advance
# 返回 2 = 非同步（openclaw），留在 In Progress 由外部完成
# 返回 3 = 需要人工，推到 Blocked
dispatch_step() {
    local task="$1" task_file="$2"
    local assignee
    assignee=$(get_yaml_field "$task_file" "assignee")

    local prompt
    prompt="任務檔案：$task_file

請讀取任務檔案，完成 User 的需求，並將你的回覆以下列格式追加到檔案末尾：

**${assignee} ($(date '+%Y-%m-%d %H:%M')):**
> 你的回覆"

    case "$assignee" in
        "claude-code")
            log "Dispatching to Claude Code: $task"
            unset CLAUDECODE
            (cd "$HOME" && script -q /dev/null $CLAUDE -c -p "$prompt" --permission-mode bypassPermissions) 2>&1 | tee -a "$LOG_FILE"
            return 0
            ;;
        "openclaw")
            if grep -q "$task" ~/.openclaw/task-queue/pending.json 2>/dev/null; then
                log "SKIP: $task already in queue"
            else
                bash "$QUEUE_SCRIPT" "$task" "$prompt"
                log "QUEUED: $task"
            fi
            return 2  # 非同步，留在 In Progress
            ;;
        "antigravity")
            log "Dispatching to Antigravity: $task"
            python3 /tmp/ask_antigravity.py "$prompt" 2>&1 | tee -a "$LOG_FILE"
            return 0
            ;;
        "Alan")
            log "BLOCKED: $task (assignee: Alan, needs human)"
            return 3
            ;;
        *)
            log "SKIP: $task (assignee: $assignee, not handled)"
            return 1
            ;;
    esac
}

main() {
    log "=== Task Kanban Job Started ==="

    local tasks=()
    while IFS= read -r task; do
        [[ -n "$task" ]] && tasks+=("$task")
    done < <(get_todo_tasks)

    if [[ ${#tasks[@]} -eq 0 ]]; then
        log "No tasks in Todo"
        exit 0
    fi

    log "Found ${#tasks[@]} tasks in Todo"

    for task in "${tasks[@]}"; do
        log "=== Processing: $task ==="
        local task_file="$TASK_DIR/$task.md"

        if [[ ! -f "$task_file" ]]; then
            log "ERROR: Task file not found: $task_file"
            continue
        fi

        move_card "$task" "running"

        # 依序執行所有步驟，全程在 In Progress
        local step_rc
        while true; do
            set +e
            dispatch_step "$task" "$task_file"
            step_rc=$?
            set -e

            case $step_rc in
                0)  # 同步完成，嘗試推進下一步
                    if advance_task "$task_file"; then
                        continue  # 有下一步，繼續 loop
                    else
                        move_card "$task" "review"
                        log "DONE: $task → Review"
                        break
                    fi
                    ;;
                2)  # 非同步（openclaw），留在 In Progress
                    log "ASYNC: $task → waiting for openclaw"
                    break
                    ;;
                3)  # 需要人工
                    move_card "$task" "blocked"
                    log "BLOCKED: $task → Blocked"
                    break
                    ;;
                *)  # 未知 assignee，skip
                    move_card "$task" "review"
                    log "SKIP: $task → Review"
                    break
                    ;;
            esac
        done
    done

    log "=== Task Kanban Job Finished ==="
}

main "$@"
