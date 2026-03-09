# task-kanban-mcp

Obsidian Task Kanban 自動化系統。watcher.sh 監聽看板變化，job.sh 依序派任務給各 agent。

## 架構

```
Obsidian Kanban UI → Kanban.md → watcher.sh (fswatch) → job.sh → Agent
```

## 任務 YAML Schema

```yaml
---
assignee: claude-code      # 當前負責人（單步）或當前步驟 agent（多步）
retry_count: 0             # 失敗自動累計，超過 3 次推到 Blocked

# 多步驟接力（可選）
current_step: 1
step1: antigravity
step2: claude-code
step3: openclaw
step4: Alan                # Alan = 需要人工，job.sh 會推到 Blocked
---

**User (YYYY-MM-DD HH:mm):**
> 任務描述
```

## 狀態流轉

| 動作 | 從 | 到 | 誰負責 |
|------|----|----|--------|
| 排程執行 | Backlog | Todo | Alan（拖曳） |
| AI 開始跑 | Todo | In Progress | job.sh（自動） |
| AI 做完 | In Progress | Review | job.sh（自動） |
| 需要人工 | In Progress | Blocked | job.sh（assignee: Alan） |
| Alan 確認 | Review | Done | Alan（手動） |

## 多步驟接力邏輯

- job.sh 在同一個 run 內依序跑完所有 step，卡片全程在 In Progress
- 同步 agent（claude-code、antigravity）：跑完後自動 advance 到下一步
- 非同步 agent（openclaw）：加入 queue 後離開，等小歐完成後另行處理
- 全部步驟完成 → Review

---

## Task Queue（OpenCLAW 專用）

openclaw 是非同步 agent，採用 queue + Heartbeat 模式處理任務，避免重複開 session 浪費 token。

### 流程

```
job.sh → 加入 pending.json → 搬到 In Progress
                    ↓
         (Watcher 只偵測 Todo 變化)
                    ↓
    Heartbeat 發現 → 執行 → task_done.sh → 搬到 Blocked/Review
```

### 腳本

| 腳本 | 功能 |
|------|------|
| `add_task.sh` | job.sh 呼叫，加入任務到 queue |
| `heartbeat_process.sh` | 小歐 Heartbeat 呼叫，取出待執行任務 |
| `task_done.sh` | 小歐執行完後呼叫，更新 YAML + 搬卡片 |

### Queue 檔案

```
~/.openclaw/task-queue/
├── pending.json    # 待處理任務
├── done.json       # 已完成記錄
├── heartbeat_process.sh
├── task_done.sh
└── add_task.sh
```

### Heartbeat 觸發

每次 Heartbeat（~30分鐘）會自動：
1. 執行 `heartbeat_process.sh` 檢查 queue
2. 如有 pending 任務 → 取出執行 → 呼叫 `task_done.sh`
3. 狀態邏輯：
   - 下一步是 agent → 搬回 **Todo**（job.sh 會繼續）
   - 下一步是 Alan/user/human → 搬到 **Blocked**（等待人工）
   - 無下一步 → 搬到 **Review**

### 測試命令

```bash
# 手動觸發（小歐 Heartbeat）
openclaw agent --message "請檢查任務隊列" --agent main

# 或直接執行腳本
bash ~/.openclaw/task-queue/heartbeat_process.sh
```

---

## Agent Prompt 格式

```
任務檔案：/full/path/to/TASK-XXXXX.md

請讀取任務檔案，完成 User 的需求，並將你的回覆以下列格式追加到檔案末尾：

**{assignee} (YYYY-MM-DD HH:mm):**
> 你的回覆
```

## 關鍵技術細節

- **claude-code dispatch**：需用 `script -q /dev/null` 包一層 PTY，否則卡住
  ```bash
  (cd "$HOME" && script -q /dev/null claude -c -p "$prompt" --permission-mode bypassPermissions)
  ```
- **antigravity dispatch**：`python3 /tmp/ask_antigravity.py "$prompt"`
- **watcher 觸發條件**：Todo 欄位卡片數量**增加**時才觸發 job.sh

## 腳本位置

| 腳本 | 路徑 |
|------|------|
| job.sh | `~/.openclaw/skills/task-kanban-mcp/scripts/job.sh` |
| watcher.sh | `~/.openclaw/skills/task-kanban-mcp/scripts/watcher.sh` |
| watcher plist | `~/Library/LaunchAgents/com.clawdbot520.kanban-watcher.plist` |

### Task Queue 腳本

| 腳本 | 路徑 |
|------|------|
| add_task.sh | `~/.openclaw/task-queue/add_task.sh` |
| heartbeat_process.sh | `~/.openclaw/task-queue/heartbeat_process.sh` |
| task_done.sh | `~/.openclaw/task-queue/task_done.sh` |

## watcher 管理

```bash
# 重啟 watcher（修改腳本後必做）
launchctl unload ~/Library/LaunchAgents/com.clawdbot520.kanban-watcher.plist
launchctl load ~/Library/LaunchAgents/com.clawdbot520.kanban-watcher.plist

# 查看 log
tail -f ~/.openclaw/skills/task-kanban-mcp/logs/watcher.log
tail -f ~/.openclaw/skills/task-kanban-mcp/logs/job.log
```

## MCP Tools

| Tool | 說明 |
|------|------|
| `get_board()` | 取得看板所有欄位狀態 |
| `get_task(task_id)` | 取得任務詳情 |
| `create_task(...)` | 建立新任務 |
| `move_card(task_id, to_status)` | 搬移卡片 |
| `trigger_job()` | 觸發 job.sh 執行 |
| `list_tasks_by_status(status)` | 列出特定狀態任務 |

## 接入 Claude Code

```json
{
  "mcpServers": {
    "task-kanban": {
      "command": "python3",
      "args": ["~/.openclaw/skills/task-kanban-mcp/server.py"]
    }
  }
}
```
