# 本地 Task 系统

Trellis task 系统完全存储在用户项目的 `.trellis/tasks/` 下。每个 task 都是一个目录，包含需求、context、research、state 和关系信息。

## Task 目录结构

```text
.trellis/tasks/
├── 04-28-example-task/
│   ├── task.json
│   ├── prd.md
│   ├── design.md
│   ├── implement.md
│   ├── implement.jsonl
│   ├── check.jsonl
│   └── research/
└── archive/
    └── 2026-04/
```

| 文件 | 用途 |
| --- | --- |
| `task.json` | Task metadata: status, assignee, priority, branch, parent/child tasks, and similar fields. |
| `prd.md` | Requirements, constraints, and acceptance criteria. Lightweight tasks may be PRD-only. |
| `design.md` | Technical design for complex tasks: boundaries, contracts, data flow, compatibility, tradeoffs. |
| `implement.md` | Execution plan for complex tasks: ordered checklist, validation commands, review gates, rollback points. |
| `implement.jsonl` | List of spec/research files the implement agent must read first. |
| `check.jsonl` | List of spec/research files the check agent must read first. |
| `research/` | Research artifacts. Complex findings should not live only in chat. |

## `task.json`

`task.json` 记录 task status 和 metadata。常见字段：

| 字段 | 含义 |
| --- | --- |
| `id` / `name` / `title` | Task identity 和 title。 |
| `status` | `planning`、`in_progress`、`review` 或 `completed` 等 status。 |
| `priority` | `P0`、`P1`、`P2`、`P3`。 |
| `creator` / `assignee` | Creator 和 assignee。 |
| `package` | monorepo 中的 target package；可为空。 |
| `branch` / `base_branch` | Working branch 和 PR target branch。 |
| `children` / `parent` | Parent/child task relationships。 |
| `commit` / `pr_url` | 完成后的 Commit 和 PR 信息。 |
| `meta` | 扩展字段。 |

AI 不应把 phase numbers 当作 task status。Task 进度主要由 `status`、`prd.md`、JSONL context 是否已配置，以及 `workflow.md` 中的 phase 描述决定。

## Active Task

用户看到的是“current task”，但 Trellis 按 session 存储 active task state。

```text
.trellis/.runtime/sessions/<context-key>.json
```

`task.py start` 将 task path 写入当前 session 的 runtime session file。`task.py current --source` 显示 current task 及其来源。不同 AI 窗口可以指向不同 tasks，且不会互相覆盖。

如果平台或 shell environment 没有稳定 session identity，`task.py start` 可能无法设置 active task。AI 应读取错误、检查平台 hook/session environment，而不是 fallback 到共享 global pointer。

## JSONL Context

`implement.jsonl` 和 `check.jsonl` 是 sub-agents 必须优先读取的 context manifests。

格式：

```jsonl
{"file": ".trellis/spec/cli/backend/index.md", "reason": "Backend conventions"}
{"file": ".trellis/tasks/04-28-example/research/api.md", "reason": "API research"}
```

规则：

- 包含 spec 和 research files。
- 不要包含即将修改的 code files。
- 不要把聊天中的临时结论当成唯一 context。
- 种子行没有 `file` 字段；它们只提示 AI 填入真实条目。

## 常用命令

```bash
python3 ./.trellis/scripts/task.py create "<title>" --slug <slug>
python3 ./.trellis/scripts/task.py start <task>
python3 ./.trellis/scripts/task.py current --source
python3 ./.trellis/scripts/task.py add-context <task> implement <file> <reason>
python3 ./.trellis/scripts/task.py validate <task>
python3 ./.trellis/scripts/task.py finish
python3 ./.trellis/scripts/task.py archive <task>
```

修改 task system 时，AI 应优先使用 script commands 维护结构。只有 scripts 无法覆盖需求时才直接编辑 JSON/Markdown。

## 本地自定义点

| 需求 | 编辑位置 |
| --- | --- |
| 修改默认 task template | `.trellis/scripts/common/task_store.py` 和 task creation instructions。 |
| 修改 status 语义 | `.trellis/workflow.md`、workflow-state hook logic 和 task usage conventions。 |
| 添加 task lifecycle actions | `.trellis/config.yaml` 中的 `hooks.after_*`。 |
| 修改 context rules | `.trellis/workflow.md` 中的 Phase 1.3 和相关 platform agent/hook instructions。 |
| 修改 archive policy | `.trellis/scripts/common/task_store.py` / `task_utils.py`。 |

这些是用户项目中的本地文件。除非用户想贡献 upstream，否则不要默认编辑 Trellis CLI source code。
