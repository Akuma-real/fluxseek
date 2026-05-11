# 本地 Workflow 系统

`.trellis/workflow.md` 是用户项目内 Trellis workflow 的事实来源。AI 不需要 Trellis source code 就能理解当前项目应如何推进 tasks；这个文件足够。

## 文件职责

`.trellis/workflow.md` 有三个职责：

1. **解释 workflow phases**：Plan、Execute、Finish。
2. **定义 skill routing**：当用户表达特定 intent 时，AI 应使用哪个 skill 或 agent。
3. **提供 workflow-state prompt blocks**：hooks 可以把当前 state 的 prompt block 注入对话。

## 当前 Phase 模型

```text
Phase 1: Plan    -> 澄清要构建什么，产出 prd.md 和必要 research
Phase 2: Execute -> 根据 PRD 和 specs 实现，然后 check
Phase 3: Finish  -> 最终验证，保存经验并收尾
```

每个 phase 包含编号 steps，例如 `1.3 Configure context`。这些数字不是 `task.json` 中的 runtime fields；它们是供 AI 和人类阅读的 workflow 结构。

## Skill 路由

`workflow.md` 按平台能力区分 routing：

- 支持 sub-agent 的平台：实现默认 dispatch `trellis-implement`，检查 dispatch `trellis-check`。
- 不支持 sub-agent 的平台：main session 读取 `trellis-before-dev` 等 skills，然后直接执行。

修改本地 AI 行为时，先更新 `workflow.md` 中的 routing 描述，然后检查对应的平台 skill、command 或 agent 文件是否需要同步。

## Workflow-State Prompt Blocks

`workflow.md` 底部可以包含这样的 state blocks：

```text
[workflow-state:no_task]
...
[/workflow-state:no_task]
```

Hooks 根据当前 task status 选择正确 block 并注入对话。常见 states 包括：

| State | 含义 |
| --- | --- |
| `no_task` | 当前 session 没有 active task。 |
| `planning` | task 仍在需求、research 或 context 配置阶段。 |
| `in_progress` | task 已进入实现和检查。 |
| `completed` | task 已完成，等待 wrap-up 或 archive。 |

如果用户想修改“无 task 时是否创建 task”“何时可跳过 task 创建”或“是否要求 sub-agents”等策略，编辑这些 state blocks 及其上方 routing table。

## 本地修改模式

常见变更：

| 目标 | 编辑点 |
| --- | --- |
| 添加 phase | 更新 Phase Index、phase body、routing 和 state blocks。 |
| 修改 task 创建策略 | 更新 `no_task` state block 和 Phase 1 描述。 |
| 修改默认 implementation/check 路径 | 更新 Phase 2 和 skill routing。 |
| 修改 wrap-up flow | 更新 Phase 3 和 `finish-work` 相关描述。注意当前拆分：Phase 3.4 = AI-driven code commits（批量、用户确认），Phase 3.5 = `/finish-work`（archive + record session）。如果 working tree dirty，`/finish-work` 会拒绝运行。 |
| 修改平台差异 | 更新按平台分组的 routing 描述。 |

编辑后，让 AI 重新读取 `.trellis/workflow.md`；不要假设旧对话中的 flow 仍然有效。

## 与平台文件的关系

`workflow.md` 是本地 workflow 的语义中心，但每个平台也可能有自己的入口文件：

- skills，例如 `trellis-brainstorm` 和 `trellis-check`。
- commands/prompts/workflows，例如 continue 和 finish-work。
- hooks，例如 session-start 或 workflow-state injection。

如果只修改 `workflow.md`，平台入口文件可能仍包含旧描述。当用户想改变“AI 实际做什么”时，也要检查相关平台目录。
