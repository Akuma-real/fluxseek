# 本地自定义概览

本目录面向在用户项目中工作的本地 AI，该项目通过 npm 安装 Trellis 且已运行 `trellis init`。AI 应修改项目内生成的 `.trellis/` 和平台目录，而不是 Trellis CLI upstream source code。

## 先确定用户真正想改变什么

| 用户说法 | 先读 |
| --- | --- |
| “修改 Trellis flow / phases / next prompt” | `change-workflow.md` |
| “修改 task creation、status、archive 或 hooks” | `change-task-lifecycle.md` |
| “AI 没有读取 context / 修改注入内容” | `change-context-loading.md` |
| “某个平台 hook 行为不符合预期” | `change-hooks.md` |
| “修改 implement/check/research agent 行为” | `change-agents.md` |
| “添加 skill/command/workflow/prompt” | `change-skills-or-commands.md` |
| “调整项目 spec 结构” | `change-spec-structure.md` |
| “添加团队 conventions 和 local notes” | `add-project-local-conventions.md` |

## 通用操作顺序

1. **确认平台和目录**：检查哪些目录存在，例如 `.claude/`、`.codex/`、`.cursor/`。
2. **确认当前 active task**：运行 `python3 ./.trellis/scripts/task.py current --source`。
3. **读取本地事实来源**：优先 `.trellis/workflow.md`、`.trellis/config.yaml` 和相关平台文件。
4. **窄范围修改**：只编辑与用户请求相关的文件。
5. **同步语义**：如果 shared flow 变化，检查平台入口点是否也需要变更；如果平台入口变化，检查 `.trellis/workflow.md` 是否仍一致。

## 本地文件优先级

| Layer | 文件 |
| --- | --- |
| Workflow | `.trellis/workflow.md` |
| Project configuration | `.trellis/config.yaml` |
| Task material | `.trellis/tasks/<task>/` |
| Project specs | `.trellis/spec/` |
| Runtime scripts | `.trellis/scripts/` |
| Platform integration | `.claude/`、`.codex/`、`.cursor/`、`.opencode/` 以及类似目录 |
| Shared skill | `.agents/skills/` |

## 默认不要做的事

- 不要编辑全局 npm install 目录。
- 不要编辑 `node_modules/@mindfoldhq/trellis`。
- 不要假设用户有 Trellis GitHub repository。
- 不要用默认 templates 覆盖用户已修改的本地文件。
- 不要把团队项目规则放入 public `trellis-meta`；项目规则属于 `.trellis/spec/` 或 local skill。

## 何时检查 Upstream Source

只有当用户明确表达以下目标之一时，才切换到 upstream source-code 视角：

- "I want to open a PR to Trellis"
- "I want to change npm package publish contents"
- "I want to fork Trellis"
- "I want to modify the generation logic for `trellis init/update`"

否则，默认修改用户项目内的本地 Trellis 文件。
