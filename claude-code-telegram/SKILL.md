---
name: claude-code-telegram
description: |
  管理 Claude Code Telegram Bot 的運行狀態。
  使用 claude-telegram-bot (cct) 將 Claude Code 接入 Telegram，
  讓用戶能透過 Telegram 與 Claude Code 進行互動式對話（串流回應、session 持續）。
  
  適用場景：
  - 用戶問「cct 有沒有在跑」、「Telegram bot 狀態」
  - 需要重啟、停止、查看 log
  - 需要修改 ALLOWED_PATHS 或其他 cct 設定
  - 重新安裝或更新 cct
---

# Claude Code Telegram Bot

> [!info] 概述
> 將 Claude Code 接入 Telegram，透過 Bot 進行互動式對話。

---

## 為什麼需要

| 傳統方式 | Telegram 方式 |
|----------|---------------|
| 只能在本機 Terminal | 隨時隨地用手機聊 |
| 出門無法使用 | 通勤也能用 |
| 無法串流回應 | 支援串流回應 |
| session 不持續 | session 持續對話 |

---

## 現有設定

| 項目 | 路徑/值 |
|------|---------|
| Bot | @your_bot |
| Workspace | `~/.cct/` |
| 設定檔 | `~/.cct/.env` |
| Log | `~/.cct/cct.log` |
| launchd plist | `~/Library/LaunchAgents/com.yourname.claude-code-telegram.plist` |
| cct binary | `~/.local/bin/cct` |
| 源碼 | 自行 clone cct 源碼 |

---

## 常用操作

### 查看狀態
```bash
launchctl list | grep claude-code-telegram
tail -20 ~/.cct/cct.log
```

### 重啟
```bash
launchctl unload ~/Library/LaunchAgents/com.yourname.claude-code-telegram.plist
launchctl load ~/Library/LaunchAgents/com.yourname.claude-code-telegram.plist
```

### 手動跑（測試用）
```bash
cd ~/.cct && env -u CLAUDECODE ~/.local/bin/cct .
```

---

## 重要坑點

### 1. CLAUDECODE 環境變數

> [!warning] Nested Session 問題
> 在 Claude Code TUI 內跑 cct 會被保護機制擋住（nested session）。

- launchd 不繼承此變數 → 服務模式沒問題
- 手動跑要加 `env -u CLAUDECODE`

### 2. CLAUDE_CODE_PATH

> [!warning] Binary 找不到
> cct 編譯版找不到 claude binary。

在 `.env` 設定：
```
CLAUDE_CODE_PATH=~/.local/bin/claude
```

### 3. ALLOWED_PATHS

> [!warning] 路徑限制
> cct 預設只允許 workspace 目錄。

在 `.env` 設定：
```
ALLOWED_PATHS=~/repos,~/.claude,/tmp
```

---

## 更新 cct binary

```bash
# 1. 進入源碼目錄（自行調整路徑）
cd ~/repos/claude-telegram-bot

# 2. 安裝依賴
~/.bun/bin/bun install

# 3. 編譯
~/.bun/bin/bun build --compile src/cli/index.ts --outfile ~/.local/bin/cct

# 4. 重啟服務
launchctl unload ~/Library/LaunchAgents/com.yourname.claude-code-telegram.plist
launchctl load ~/Library/LaunchAgents/com.yourname.claude-code-telegram.plist
```

---

## 相關連結

- Claude Code GitHub: https://github.com/anthropics/claude-code
- cct 源碼: https://github.com/GoatWang/claude-telegram-bot
