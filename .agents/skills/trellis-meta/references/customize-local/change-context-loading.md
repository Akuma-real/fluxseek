# 修改本地 Context Loading

Context loading 决定 AI 何时读取 workflow、task、spec、research、workspace 和 git status。当用户说“AI 不知道 current task”“agent 没有读 specs”或“context 太多/太少”时，读取本页。

## 先读这些文件

1. `.trellis/workflow.md`
2. `.trellis/scripts/get_context.py`
3. `.trellis/scripts/common/session_context.py`
4. `.trellis/scripts/common/task_context.py`
5. `.trellis/scripts/common/active_task.py`
6. 当前平台 hooks 或 agent files
7. 当前 task 的 `implement.jsonl` / `check.jsonl`

## Context 来源

| 来源 | 用途 |
| --- | --- |
| `.trellis/workflow.md` | Workflow 和 next-action hints。 |
| `.trellis/tasks/<task>/prd.md` | Current task requirements. |
| `.trellis/tasks/<task>/design.md` | Complex task technical design. |
| `.trellis/tasks/<task>/implement.md` | Complex task execution plan. |
| `.trellis/tasks/<task>/implement.jsonl` | Spec/research to read before implementation. |
| `.trellis/tasks/<task>/check.jsonl` | Spec/research to read during checking. |
| `.trellis/spec/` | Project specs. |
| `.trellis/workspace/` | Session records. |
| git status | Current working tree changes. |

## 常见需求与编辑点

| 需求 | 编辑点 |
| --- | --- |
| 在新 sessions 中注入更多/更少信息 | `session_context.py` 或平台 `session-start` hook。 |
| 修改每次用户输入的 hints | `.trellis/workflow.md` 中的 `[workflow-state:STATUS]` block。`inject-workflow-state` hook 仅是 parser，并逐字读取 block。 |
| Agent 没有读取 specs | Task JSONL、agent prelude、`inject-subagent-context` hook。 |
| Active task 丢失 | `active_task.py` 和平台 session identity propagation。 |
| 修改 JSONL validation rules | `task_context.py`。 |

## JSONL 规则

`implement.jsonl` / `check.jsonl` 是关键 context loading interface：

```jsonl
{"file": ".trellis/spec/backend/index.md", "reason": "Backend conventions"}
{"file": ".trellis/tasks/04-28-x/research/api.md", "reason": "API research"}
```

只包含 spec/research files。不要把即将修改的 code files 放入这些 manifests；agents 会在 implementation 期间自行读取 code files。

## 修改 Session Context

如果用户希望每个新 session 看到更多 project state，编辑：

- `.trellis/scripts/common/session_context.py`
- the corresponding platform `session-start` hook

Context 不能无限增长。优先注入 indexes 和 paths，让 AI 可按需读取详细文件。

## 修改 Sub-Agent Context

先判断平台使用哪种模式：

- hook push：编辑 `inject-subagent-context` hook。
- agent pull：编辑对应 `trellis-implement` / `trellis-check` agent file 中的读取步骤。

两种模式下，都确保 agent 最终读取：

1. active task
2. the corresponding JSONL
3. spec/research referenced by the JSONL
4. `prd.md`
5. `design.md` if present
6. `implement.md` if present

## 故障排查顺序

```bash
python3 ./.trellis/scripts/task.py current --source
python3 ./.trellis/scripts/task.py list-context <task>
python3 ./.trellis/scripts/task.py validate <task>
python3 ./.trellis/scripts/get_context.py --mode packages
```

编辑 hooks/agents 前，确认 task 和 JSONL 正确。
