# 平台文件映射

本页按平台列出用户项目中常见 Trellis 文件位置。实际项目中是否存在某个平台目录，取决于用户运行过哪些 `trellis init --<platform>` 命令。

## 矩阵

| 平台 | CLI flag | 主目录 | Skill 目录 | Agent 目录 | Hooks/extensions |
| --- | --- | --- | --- | --- | --- |
| Claude Code | `--claude` | `.claude/` | `.claude/skills/` | `.claude/agents/` | `.claude/hooks/` + `.claude/settings.json` |
| Cursor | `--cursor` | `.cursor/` | `.cursor/skills/` | `.cursor/agents/` | `.cursor/hooks.json` + `.cursor/hooks/` |
| OpenCode | `--opencode` | `.opencode/` | `.opencode/skills/` | `.opencode/agents/` | `.opencode/plugins/` |
| Codex | `--codex` | `.codex/` | `.agents/skills/` | `.codex/agents/` | `.codex/hooks/` + `.codex/hooks.json` |
| Kilo | `--kilo` | `.kilocode/` | `.kilocode/skills/` | Usually none | `.kilocode/workflows/` |
| Kiro | `--kiro` | `.kiro/` | `.kiro/skills/` | `.kiro/agents/` | `.kiro/hooks/` |
| Gemini CLI | `--gemini` | `.gemini/` | `.agents/skills/` | `.gemini/agents/` | `.gemini/settings.json` + `.gemini/hooks/` |
| Antigravity | `--antigravity` | `.agent/` | `.agent/skills/` | Usually none | `.agent/workflows/` |
| Windsurf | `--windsurf` | `.windsurf/` | `.windsurf/skills/` | Usually none | `.windsurf/workflows/` |
| Qoder | `--qoder` | `.qoder/` | `.qoder/skills/` | `.qoder/agents/` | `.qoder/hooks/` + `.qoder/settings.json` |
| CodeBuddy | `--codebuddy` | `.codebuddy/` | `.codebuddy/skills/` | `.codebuddy/agents/` | `.codebuddy/hooks/` + `.codebuddy/settings.json` |
| GitHub Copilot | `--copilot` | `.github/` | `.github/skills/` | `.github/agents/` | `.github/copilot/hooks/` + prompts |
| Factory Droid | `--droid` | `.factory/` | `.factory/skills/` | `.factory/droids/` | `.factory/hooks/` + settings |
| Pi Agent | `--pi` | `.pi/` | `.pi/skills/` | `.pi/agents/` | `.pi/extensions/trellis/` + `.pi/settings.json` |

## 能力分组

### Trellis Sub-Agent 支持

这些平台通常有 `trellis-research`、`trellis-implement` 和 `trellis-check` 文件：

- Claude Code
- Cursor
- OpenCode
- Codex
- Kiro
- Gemini CLI
- Qoder
- CodeBuddy
- GitHub Copilot
- Factory Droid
- Pi Agent

修改 implementation/check/research 行为时，先查找对应平台 agent files。

### Main-Session Workflow 平台

这些平台更依赖 workflows/skills 来引导 main session：

- Kilo
- Antigravity
- Windsurf

修改行为时，先检查 workflows 和 skills。不要假设 Trellis sub-agents 存在。

### 共享 `.agents/skills/`

Codex 写入共享 `.agents/skills/` layer。一些支持 agentskills.io 的工具也能读取此目录。如果用户希望多个兼容工具共享一个 skill，优先考虑 `.agents/skills/`，但不要假设每个平台都会读取它。

## 修改平台文件时的决策规则

1. 用户指定平台：只修改该平台目录，除非 shared workflow/spec files 也必须改变。
2. 用户说“所有平台都应这样”：逐平台同步等价入口点；不要只修改一个目录。
3. 用户只说“我的 AI”：检查项目中实际存在的配置目录，推断当前 AI 平台。
4. 用户想要项目规则：优先使用 `.trellis/spec/` 或 project-local skill。
5. 用户想要 Trellis 行为：编辑 `.trellis/workflow.md` 以及平台 hooks/agents/skills/commands。

## 当路径不一致时

平台生态会变化，用户项目也可能已自定义。如果此表与本地文件不一致，以用户项目中的实际 settings/config 为权威：

- 检查 settings 注册的 hook。
- 检查 command/prompt/workflow 指向的 script。
- 根据 agent file 当前写明的读取规则判断行为。

不要只因为某个自定义文件未列在此路径表中就删除它。
