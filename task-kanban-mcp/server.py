#!/usr/bin/env python3
"""
Task-kanban MCP Server
操作 Obsidian Task Kanban 看板
"""

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# 設定
KANBAN_DIR = Path.home() / "repos" / "Obsidian Vault" / "Task Kanban"
KANBAN_FILE = KANBAN_DIR / "Kanban.md"
TASK_DIR = KANBAN_DIR / "task"
JOB_SCRIPT = Path.home() / ".openclaw" / "skills" / "task-kanban-mcp" / "scripts" / "job.sh"

# 狀態對應
STATUS_MAP = {
    "backlog": "📥 Backlog",
    "todo": "📅 Todo",
    "running": "🚀 In Progress",
    "review": "👀 Review",
    "done": "✅ Done",
    "canceled": "❌ Canceled",
    "waiting": "💬 Waiting",
    "blocked": "🚫 Blocked"
}

def get_board():
    """取得看板所有欄位的任務"""
    if not KANBAN_FILE.exists():
        return {"error": "Kanban file not found"}
    
    content = KANBAN_FILE.read_text()
    board = {}
    
    for status, title in STATUS_MAP.items():
        # 找欄位
        pattern = rf"## {re.escape(title)}.*?(?=## |$)"
        match = re.search(pattern, content, re.DOTALL)
        
        if match:
            section = match.group(0)
            tasks = re.findall(r'- \[([ x])\] \[\[([^\]]+)\]\]', section)
            board[status] = [{"title": t[1], "done": t[0] == 'x'} for t in tasks]
        else:
            board[status] = []
    
    return board


def get_task(task_id):
    """取得單一任務"""
    task_file = TASK_DIR / f"{task_id}.md"
    
    if not task_file.exists():
        return {"error": f"Task {task_id} not found"}
    
    content = task_file.read_text()
    
    # 解析 YAML
    yaml_match = re.search(r'^---\n(.*?)\n---', content, re.DOTALL)
    if yaml_match:
        yaml_content = yaml_match.group(1)
        task = {}
        for line in yaml_content.split('\n'):
            if ':' in line:
                key, value = line.split(':', 1)
                task[key.strip()] = value.strip()
    
    # 描述
    desc_match = re.search(r'^---.*?---\n(.*)', content, re.DOTALL)
    if desc_match:
        task['description'] = desc_match.group(1).strip()
    
    return task


def next_task_id():
    """自動產生下一個 TASK ID"""
    files = list(TASK_DIR.glob("TASK-*.md"))
    nums = []
    for f in files:
        m = re.match(r"TASK-(\d+)", f.name)
        if m:
            nums.append(int(m.group(1)))
    return f"TASK-{(max(nums, default=0) + 1):05d}"


def create_task(title, assignee, description="", task_id=None, step1=None, step2=None, step3=None, step4=None):
    """建立新任務（task_id 可選，不傳則自動遞增）"""
    if not task_id:
        task_id = next_task_id()

    filename = f"{task_id}-{title}"
    task_file = TASK_DIR / f"{filename}.md"

    if task_file.exists():
        return {"error": f"{filename} already exists"}

    s1 = step1 or assignee
    steps = f"step1: {s1}\n"
    if step2: steps += f"step2: {step2}\n"
    if step3: steps += f"step3: {step3}\n"
    if step4: steps += f"step4: {step4}\n"
    has_steps = bool(step2 or step3 or step4)

    content = f"""---
assignee: {assignee}
{"current_step: 1" if has_steps else ""}
{steps.rstrip()}
---

{description}

## 💬 討論與備註

"""
    task_file.write_text(content)
    add_to_board(filename, "todo")

    return {"ok": True, "task_id": filename}


def move_card(task_id, to_status):
    """搬移卡片"""
    if to_status not in STATUS_MAP:
        return {"error": f"Invalid status: {to_status}"}
    
    content = KANBAN_FILE.read_text()
    
    # 從所有欄位移除
    content = re.sub(rf'^- \[.\] \[\[{re.escape(task_id)}\]\]\n?', '', content, flags=re.MULTILINE)
    
    # 加入目標欄位
    target = STATUS_MAP[to_status]
    content = re.sub(
        rf'(## {re.escape(target)})',
        rf'\1\n\n- [ ] [[{task_id}]]',
        content
    )
    
    KANBAN_FILE.write_text(content)
    
    # task_id 可能是完整檔名或純 ID，都嘗試找到對應檔案
    matches = list(TASK_DIR.glob(f"{task_id}*.md"))
    if matches:
        matches[0].write_text(matches[0].read_text())
    
    return {"ok": True, "task_id": task_id, "to_status": to_status}


def add_to_board(task_id, status):
    """加入看板"""
    if status not in STATUS_MAP:
        return {"error": f"Invalid status: {status}"}
    
    content = KANBAN_FILE.read_text()
    target = STATUS_MAP[status]
    
    # 檢查是否已存在
    if f"[[{task_id}]]" in content:
        return {"ok": True, "message": "Task already on board"}
    
    # 加入
    content = re.sub(
        rf'(## {re.escape(target)})',
        rf'\1\n\n- [ ] [[{task_id}]]',
        content
    )
    
    KANBAN_FILE.write_text(content)
    return {"ok": True}


def trigger_job():
    """觸發 job.sh 執行"""
    if not JOB_SCRIPT.exists():
        return {"error": "job.sh not found"}
    
    try:
        result = subprocess.run(
            [str(JOB_SCRIPT)],
            capture_output=True,
            text=True,
            timeout=300,
        )
        
        return {
            "ok": True,
            "returncode": result.returncode,
            "stdout": result.stdout[-2000:] if result.stdout else "",
            "stderr": result.stderr[-500:] if result.stderr else ""
        }
    except subprocess.TimeoutExpired:
        return {"error": "Job timeout (>300s)"}
    except Exception as e:
        return {"error": str(e)}


def list_tasks_by_status(status):
    """列出特定狀態的任務"""
    board = get_board()
    return board.get(status, [])


# MCP 協議
def handle_request(request):
    method = request.get("method")
    params = request.get("params", {})
    
    if method == "tools/list":
        return {
            "result": {
                "tools": [
                    {"name": "get_board", "description": "取得看板狀態", "inputSchema": {"type": "object", "properties": {}}},
                    {"name": "get_task", "description": "取得任務詳情", "inputSchema": {"type": "object", "properties": {"task_id": {"type": "string"}}, "required": ["task_id"]}},
                    {"name": "create_task", "description": "建立新任務（task_id 可選，不傳自動遞增）", "inputSchema": {"type": "object", "properties": {"title": {"type": "string"}, "assignee": {"type": "string", "enum": ["claude-code", "openclaw", "antigravity", "Alan"]}, "description": {"type": "string"}, "task_id": {"type": "string"}, "step1": {"type": "string"}, "step2": {"type": "string"}, "step3": {"type": "string"}, "step4": {"type": "string"}}, "required": ["title", "assignee"]}},
                    {"name": "move_card", "description": "搬移卡片", "inputSchema": {"type": "object", "properties": {"task_id": {"type": "string"}, "to_status": {"type": "string", "enum": list(STATUS_MAP.keys())}}, "required": ["task_id", "to_status"]}},
                    {"name": "trigger_job", "description": "觸發任務執行", "inputSchema": {"type": "object", "properties": {}}},
                    {"name": "list_tasks_by_status", "description": "列出特定狀態任務", "inputSchema": {"type": "object", "properties": {"status": {"type": "string", "enum": list(STATUS_MAP.keys())}}, "required": ["status"]}},
                ]
            }
        }
    
    if method == "tools/call":
        tool = params.get("name")
        args = params.get("arguments", {})
        
        if tool == "get_board":
            return {"result": get_board()}
        elif tool == "get_task":
            return {"result": get_task(**args)}
        elif tool == "create_task":
            return {"result": create_task(**args)}
        elif tool == "move_card":
            return {"result": move_card(**args)}
        elif tool == "trigger_job":
            return {"result": trigger_job()}
        elif tool == "list_tasks_by_status":
            return {"result": list_tasks_by_status(**args)}
        else:
            return {"error": {"code": -32601, "message": f"Unknown: {tool}"}}
    
    return {"error": {"code": -32600, "message": "Invalid request"}}


if __name__ == "__main__":
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
            response = handle_request(request)
            print(json.dumps(response))
            sys.stdout.flush()
        except Exception as e:
            print(json.dumps({"error": {"code": -32603, "message": str(e)}}))
            sys.stdout.flush()
