# Hooks 与 Settings

Hooks/settings 是连接平台与 Trellis 的入口层。它们决定平台在什么事件运行哪些 scripts、plugins 或 extensions。

## Settings 职责

settings/config files 通常注册：

- session-start hook：当新 session 开始或 context reset 时注入 Trellis overview。
- workflow-state hook：从 `.trellis/workflow.md` 解析 `[workflow-state:STATUS]` blocks，并在每次用户输入时输出与当前 task `status` 匹配的正文。仅 parser；script 不嵌入 fallback content。
- sub-agent context hook：implementation/check/research agents 启动时注入 task context。
- shell/session bridge：让 shell commands 看到同一个 Trellis session identity。
- platform plugin 或 extension entry points。

常见文件：

| 平台 | settings/config |
| --- | --- |
| Claude Code | `.claude/settings.json` |
| Cursor | `.cursor/hooks.json` |
| Codex | `.codex/hooks.json`, `.codex/config.toml` |
| OpenCode | `.opencode/package.json`, `.opencode/plugins/*` |
| Kiro | `.kiro/hooks/` + platform config |
| Gemini CLI | `.gemini/settings.json` |
| Qoder | `.qoder/settings.json` |
| CodeBuddy | `.codebuddy/settings.json` |
| GitHub Copilot | `.github/copilot/hooks.json` |
| Factory Droid | `.factory/settings.json` |
| Pi Agent | `.pi/settings.json`, `.pi/extensions/trellis/` |

项目中是否存在这些文件取决于用户运行过哪些 `trellis init --<platform>` flags。

## Hook Script 类型

| Script | 用途 |
| --- | --- |
| `session-start.py` | 生成 session-start context。 |
| `inject-workflow-state.py` | 解析 `.trellis/workflow.md` 中的 `[workflow-state:STATUS]` blocks，并输出与当前 task status 匹配的正文。不存在匹配 block 时 fallback 到 `Refer to workflow.md for current step.`。 |
| `inject-subagent-context.py` | 将 PRD、JSONL context 和相关 spec/research 注入 sub-agents。 |
| `inject-shell-session-context.py` | 让 shell commands 继承 Trellis session identity。 |

不是每个平台都有每种 hook。不要仅因某个平台缺少 hook 就从另一个平台复制文件；先确认该平台是否支持对应事件。

## 本地变更场景

| 用户需求 | 编辑位置 |
| --- | --- |
| AI 应在新 session 中看到更多/更少 context | 平台 `session-start` hook。 |
| 每轮 hint policy 需要变化 | `.trellis/workflow.md` 中的 `[workflow-state:STATUS]` block。hook 逐字解析 workflow.md — 不需要编辑 script。 |
| Sub-agent 无法读取 PRD/spec | `inject-subagent-context` hook 或 agent prelude。 |
| shell 中的 `task.py current` 没有 active task | Shell/session bridge hook 或平台环境变量配置。 |
| 禁用自动注入 | settings/config 中对应 hook registration。 |

## 修改原则

1. **Settings 负责接线；hooks 定义行为**。如果只改 hook，平台可能永远不调用它。如果只改 settings，行为可能不变。
2. **先确认平台 event names**。不同平台对 SessionStart、UserPromptSubmit、AgentSpawn、shell execution 等事件使用不同名称。
3. **Hooks 读取本地 `.trellis/`，不是 upstream source**。用户项目中的 `.trellis/scripts/` 和 `.trellis/workflow.md` 是默认目标。
4. **错误必须可见**。Hook failures 应告诉用户未注入什么，而不是静默让 AI 没有 context。

## 故障排查路径

如果用户说“AI 没有读取 Trellis state”：

1. 检查平台 settings 是否注册 hook。
2. 检查 hook file 是否存在。
3. 手动运行 hook 依赖的 `.trellis/scripts/get_context.py` 或 `task.py current --source` 命令。
4. 检查 active task state 是否存在于 `.trellis/.runtime/sessions/`。
5. 检查平台 shell 是否传递 session identity。
