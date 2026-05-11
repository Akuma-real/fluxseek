# 本地 Context Injection 系统

Trellis context injection 的目标是让 AI 在正确时间读取正确文件，而不是依赖模型记忆。在用户项目中，injection 由 `.trellis/` scripts 以及平台 hooks、agents 和 skills 共同实现。

## 注入的 Context 类型

| 类型 | 来源 | 用途 |
| --- | --- | --- |
| session context | `.trellis/scripts/get_context.py` | Current developer、git status、active task、active tasks、journal、packages。 |
| workflow context | `.trellis/workflow.md` | 当前 Trellis flow 和 next action。 |
| spec context | `.trellis/spec/` + task JSONL | implementation/checking 期间必须遵循的 specs。 |
| task context | `.trellis/tasks/<task>/prd.md`、`design.md`、`implement.md`、`research/` | 当前 task requirements、design、execution plan 和 research。 |
| platform context | Platform hooks/settings/agents | 让不同 AI tools 通过各自机制读取上述文件。 |

## session-start

支持 session-start 的平台会在 session starts、clears、compacts 或类似事件时注入 Trellis overview。注入内容通常包括：

- workflow summary。
- current task status。
- active tasks。
- spec index paths。
- developer identity 和 git status。

如果用户觉得 AI 在新 session 中不知道 current task，先检查平台 session-start hook 或等效机制是否已安装并运行。

## workflow-state

workflow-state 是在每个用户回合附近注入的轻量提示。它根据当前 task status 从 `.trellis/workflow.md` 选择 block，例如 `no_task`、`planning`、`in_progress` 或 `completed`。

如果用户想改变“AI 在某个 state 下一步该做什么”，先编辑 `.trellis/workflow.md` 中对应 state block。

## sub-agent context

Implement 和 check agents 需要 task context。Trellis 有两种加载模式：

1. **hook push**：agent 启动前，平台 hook 注入 `prd.md` 以及 `implement.jsonl` / `check.jsonl` 引用的文件。
2. **agent pull**：agent 定义指示 agent 在启动后读取 active task、PRD 和 JSONL context。

两种模式下，task directory 中的 JSONL 文件都是关键接口。

## JSONL 读取规则

`implement.jsonl` 和 `check.jsonl` 每行包含一个 JSON object：

```jsonl
{"file": ".trellis/spec/backend/index.md", "reason": "Backend rules"}
```

Readers 应跳过没有 `file` 字段的种子行。配置 JSONL 时，AI 只应包含 spec/research files，不要预注册即将修改的 code files。

## Active Task 与 Context Key

Active task state 位于 `.trellis/.runtime/sessions/`，并按 session 隔离。Hooks 尝试从 platform events、environment variables、transcript paths 或 `TRELLIS_CONTEXT_ID` 解析 context key。

如果 shell commands 看不到同一 context key，`task.py current --source` 可能报告没有 active task。此时检查平台是否将 session identity 传入 shell，而不是手写 global current-task file。

## 本地自定义点

| 需求 | 编辑位置 |
| --- | --- |
| 修改 session-start 注入内容 | 平台的 `session-start` hook 或 plugin file。 |
| 修改每轮 workflow-state 规则 | `.trellis/workflow.md` 中的 `[workflow-state:STATUS]` block。平台 workflow-state hook 逐字解析这些 blocks，不嵌入 fallback text。 |
| 修改 sub-agents 如何读取 context | Platform agent definitions、`inject-subagent-context` hook 或 agent preludes。 |
| 修改 JSONL validation/display | `.trellis/scripts/common/task_context.py`。 |
| 修改 active task resolution | `.trellis/scripts/common/active_task.py`。 |

修改 context injection 时，验证两件事：新 sessions 能看到正确 task，且 sub-agents 能看到正确 PRD/spec/research。
