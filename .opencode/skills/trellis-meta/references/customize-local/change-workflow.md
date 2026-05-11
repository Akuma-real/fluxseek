# 修改本地 Workflow

当用户想修改 Trellis phases、next-action hints、是否创建 tasks、是否使用 sub-agents，或何时 check/wrap up 时，先编辑 `.trellis/workflow.md`。

## 先读这些文件

1. `.trellis/workflow.md`
2. 当前平台的入口文件，例如 skills/commands/prompts/workflows
3. 当前 task 的 `task.json` 和 `prd.md`

## 常见需求与编辑点

| 需求 | 编辑点 |
| --- | --- |
| 修改 phase 名称或顺序 | `Phase Index` 和对应 Phase sections。 |
| 修改无 task 时是否创建 task | `[workflow-state:no_task]` state block。 |
| 修改 planning 期间的下一步 | Phase 1 和 `[workflow-state:planning]`。 |
| 修改 in_progress 期间是否要求 agent | Phase 2 和 `[workflow-state:in_progress]`。 |
| 修改完成后的 wrap-up | Phase 3 和 `[workflow-state:completed]`。 |
| 修改用户 intent 触发哪个 skill | `Skill Routing` table。 |

## 修改步骤

1. 在 `.trellis/workflow.md` 中找到相关 section。
2. 修改规则时，保留明确 trigger conditions 和 next actions。
3. 如果添加或重命名 skill/agent，同步平台目录中的对应文件。
4. Workflow-state 变更只需编辑 `.trellis/workflow.md` 中的 `[workflow-state:STATUS]` block。hook 仅是 parser — 它读取 block 中的任何内容。保持 opening 和 closing tags 的 STATUS strings 相同（`[workflow-state:foo]…[/workflow-state:foo]`）；不匹配的 STATUS pairs 会被静默丢弃。
5. 让 AI 重新读取 `.trellis/workflow.md`；不要继续使用旧对话中的规则。

## 示例：放宽 Task 创建要求

要修改何时可跳过 task creation，通常编辑 `[workflow-state:no_task]`：

```md
[workflow-state:no_task]
Task is not required when the answer is a one-reply explanation, no files are changed, and no research is needed.
[/workflow-state:no_task]
```

如果正式 Phase 1 flow 也需要变化，同步 Phase 1 section。

## 示例：某个平台不使用 Sub-Agents

如果用户只希望某个平台避免 sub-agents，先确认 workflow 中该平台是否有单独分组。然后修改该平台分组的 Phase 2 routing，而不是删除所有平台的 `trellis-implement` / `trellis-check` 说明。

## `/trellis:continue` 路由表

`/trellis:continue` 通过决定下一步加载哪个 phase step 来恢复 task。该决策结合 `task.json.status` 与 task 目录内 artifacts 是否存在。映射固定在 command 自身中；添加 custom statuses 的 forks 必须同时扩展 workflow.md tag block 和此表。

| `status` | Artifact state | Resume at |
| --- | --- | --- |
| `planning` | `prd.md` 缺失 | Phase 1.1（加载 `trellis-brainstorm`） |
| `planning` | `prd.md` 存在，`implement.jsonl` 只有种子 `_example` 行 | Phase 1.3（curate JSONL context） |
| `planning` | `prd.md` 存在，`implement.jsonl` 已整理 | Phase 1.4（运行 `task.py start`） |
| `in_progress` | conversation history 中无 implementation | Phase 2.1（`trellis-implement`） |
| `in_progress` | implementation 完成，未运行 `trellis-check` | Phase 2.2（`trellis-check`） |
| `in_progress` | check passed | Phase 3.1（verify quality + spec update） |
| `completed` | task 仍在 active tree | Phase 3.5（运行 `/trellis:finish-work` 以 archive） |

添加 custom status（例如 `in-review`）时，在 `.trellis/workflow.md` 中添加 `[workflow-state:in-review]` block 供每轮 breadcrumb 使用，并扩展此 route table — 通常通过编辑 `/trellis:continue` command file（`.{platform}/commands/trellis/continue.md` 或等价文件）添加一行，决定从哪里 resume。没有 route entry 时，`/trellis:continue` 会落入 default branch，用户不会进入你预期的 step。

## 说明

`.trellis/workflow.md` 是本地项目 workflow，不是不可变 template。用户可以按团队习惯调整它。编辑后，平台入口文件可能仍包含旧描述，因此也要检查它们。
