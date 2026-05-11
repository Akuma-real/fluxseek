# Skills、Commands、Prompts 与 Workflows

Skills 和 commands 是用户与 Trellis 交互的文本入口点。不同平台使用不同名称，但核心目的相同：当用户表达某种 intent 时，告诉 AI 如何进入 Trellis flow。

## 概念差异

| 类型 | Trigger mode | 最适合 |
| --- | --- | --- |
| skill | AI auto-match 或用户显式提及 | 长期能力、workflow rules、修改指南。 |
| command | 用户显式调用 | 清晰操作入口，例如 continue 和 finish-work。 |
| prompt | 用户显式调用或平台选择 | 类似 command，但使用平台 prompt 格式。 |
| workflow | 用户显式选择或平台 auto-match | 没有 sub-agent/hook 时引导 main session。 |

Trellis workflow skills 通常共享同一语义集合：brainstorm、before-dev、check、update-spec、break-loop。`trellis-meta` 等多文件 built-in skills 使用分层 references。

## 常见路径

| 平台 | 常见入口 |
| --- | --- |
| Claude Code | `.claude/skills/`, `.claude/commands/` |
| Cursor | `.cursor/skills/`, `.cursor/commands/` |
| OpenCode | `.opencode/skills/`, `.opencode/commands/` |
| Codex | `.agents/skills/`, `.codex/skills/` |
| Kilo | `.kilocode/skills/`, `.kilocode/workflows/` |
| Kiro | `.kiro/skills/` |
| Gemini CLI | `.agents/skills/`, `.gemini/commands/` |
| Antigravity | `.agent/skills/`, `.agent/workflows/` |
| Windsurf | `.windsurf/skills/`, `.windsurf/workflows/` |
| Qoder | `.qoder/skills/`, `.qoder/commands/` |
| CodeBuddy | `.codebuddy/skills/`, `.codebuddy/commands/` |
| GitHub Copilot | `.github/skills/`, `.github/prompts/` |
| Factory Droid | `.factory/skills/`, `.factory/commands/` |
| Pi Agent | `.pi/skills/` |

在用户项目中，以 init 实际生成的文件为权威。

## Skill 结构

常见 skill 是一个目录：

```text
trellis-meta/
├── SKILL.md
└── references/
```

`SKILL.md` 应告诉 AI：

- 何时使用此 skill。
- 当前 task 应先读哪个 reference。
- 不要做什么。

References 保存更长解释，避免入口文件包含所有内容。

## Command/Prompt/Workflow 结构

Commands、prompts 和 workflows 通常是单文件。其内容应包括：

- 何时使用。
- 要读取哪些 `.trellis/` 文件。
- 要运行哪些 scripts。
- 完成后如何报告。

它们不应存储 task state；task state 属于 `.trellis/tasks/` 和 `.trellis/.runtime/`。

## 本地变更场景

| 用户需求 | 编辑位置 |
| --- | --- |
| 修改 AI auto-trigger rules | 对应 skill 的 frontmatter description。 |
| 修改用户 command 行为 | 对应 command/prompt/workflow 文件。 |
| 添加 project-local skill | 平台 skill directory，或共享 `.agents/skills/`。 |
| 让多个平台共享一个能力 | 在每个平台 skill directory 写等价 skills，或在支持的平台上使用 `.agents/skills/` 共享 layer。 |
| 修改 finish/continue 入口点 | 平台 commands/prompts/workflows。 |

## 修改原则

1. **保持入口文件简短；长内容放在 references**。这对 `trellis-meta` 等多文件 skills 尤其重要。
2. **让 trigger descriptions 具体**。描述太宽会误触发；太窄可能不触发。
3. **跨平台保持同一语义一致**。文件格式可以不同，但行为描述应匹配。
4. **将项目特定能力放在 local skills 中**。不要把团队私有 flows 放入 public `trellis-meta`。

如果用户只是希望本地 AI 多知道一条项目规则，通常创建 project-local skill 或更新 `.trellis/spec/`，而不是修改 Trellis built-in workflow skill。
