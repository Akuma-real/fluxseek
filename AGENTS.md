<!-- TRELLIS:START -->
# Trellis 指令

这些指令适用于在本项目中工作的 AI 助手。

本项目由 Trellis 管理。你需要的工作知识位于 `.trellis/`：

- `.trellis/workflow.md` — 开发阶段、何时创建任务、技能路由
- `.trellis/spec/` — 按 package 和 layer 组织的编码指南（在某个 layer 写代码前先读）
- `.trellis/workspace/` — 每位开发者的日志和会话轨迹
- `.trellis/tasks/` — 活跃和归档任务（PRD、研究、jsonl 上下文）

如果当前平台提供 Trellis 命令（例如 `/trellis:finish-work`、`/trellis:continue`），优先使用命令而不是手动步骤。并非每个平台都会暴露所有命令。

如果你使用 Codex 或其他支持 agent 的工具，额外的项目级辅助文件可能位于：
- `.agents/skills/` — 可复用的 Trellis skills
- `.codex/agents/` — 可选的自定义 subagents

由 Trellis 管理。本区块外的编辑会保留；本区块内的编辑可能在未来 `trellis update` 时被覆盖。

<!-- TRELLIS:END -->

## 沟通

与用户沟通时使用中文。
