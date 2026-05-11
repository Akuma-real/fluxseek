# Agents

Trellis agent files 定义专门角色。用户项目中的常见 Trellis agents 包括：

- `trellis-research`
- `trellis-implement`
- `trellis-check`

文件位置和格式因平台而异，但职责边界应保持一致。

## Agent 职责

| Agent | 职责 |
| --- | --- |
| `trellis-research` | 调研问题，并将 findings 写入当前 task 的 `research/`。 |
| `trellis-implement` | 根据 `prd.md`、可选的 `design.md` / `implement.md`、`implement.jsonl` 和相关 spec/research 实现。 |
| `trellis-check` | Review changes，修复发现的问题，并运行必要检查。 |

Agent files 不应变成通用聊天 prompts。它们应定义 input sources、write boundaries、是否可修改代码，以及如何报告结果。

## 常见路径

| 平台 | Agent 路径 |
| --- | --- |
| Claude Code | `.claude/agents/trellis-*.md` |
| Cursor | `.cursor/agents/trellis-*.md` |
| OpenCode | `.opencode/agents/trellis-*.md` |
| Codex | `.codex/agents/trellis-*.toml` |
| Kiro | `.kiro/agents/trellis-*.json` |
| Gemini CLI | `.gemini/agents/trellis-*.md` |
| Qoder | `.qoder/agents/trellis-*.md` |
| CodeBuddy | `.codebuddy/agents/trellis-*.md` |
| Factory Droid | `.factory/droids/trellis-*.md` |
| Pi Agent | `.pi/agents/trellis-*.md` |

GitHub Copilot agent/prompt 支持由 `.github/agents/`、`.github/prompts/` 和 `.github/skills/` 等目录组合提供；检查用户项目中实际生成的文件。

Kilo、Antigravity 和 Windsurf 等 main-session workflow 平台可能没有 Trellis sub-agent files。它们通常依赖 workflows/skills 引导 main session。

## 两种 Context Loading 模式

### hook push

平台 hook 在 agent 启动前注入 task context。Agent file 本身可以更专注于职责和边界。

常见于支持 agent hooks 的平台。

### agent pull

Agent file 指示 agent 启动后读取：

- `python3 ./.trellis/scripts/task.py current --source`
- `implement.jsonl` or `check.jsonl`
- spec/research files referenced by JSONL
- current task `prd.md`
- `design.md` if present
- `implement.md` if present

此模式适用于 hooks 无法可靠重写 sub-agent prompts 的平台。

## 本地变更场景

| 用户需求 | 编辑位置 |
| --- | --- |
| Implement agent 必须遵循额外限制 | 平台的 `trellis-implement` agent file。 |
| Check agent 必须运行项目特定命令 | `trellis-check` agent file，必要时还有 `.trellis/spec/`。 |
| Research agent 必须输出固定格式 | `trellis-research` agent file。 |
| Agent 无法读取 task context | Agent prelude 或 `inject-subagent-context` hook。 |
| 添加项目特定 agent | 平台 agent directory + 相关 workflow/command/skill 入口点。 |

## 修改原则

1. **保持职责单一**。不要把 research、implement 和 check 职责混进一个 agent。
2. **指定读取顺序**。Agents 必须知道从 active task 开始，然后找到 PRD 和 JSONL。
3. **指定写入边界**。Research 通常只写 `research/`；implement 可写代码；check 可修复问题。
4. **在多平台项目中保持语义同步**。如果用户同时配置了 Claude、Codex 和 Cursor，判断某个平台 agent 的变更是否也需要应用到其他平台。

## 不要默认编辑 Upstream Templates

本地 AI 应默认修改用户项目内的平台 agent files。只有当用户明确想把变更贡献回 Trellis 时，才讨论 upstream template source。
