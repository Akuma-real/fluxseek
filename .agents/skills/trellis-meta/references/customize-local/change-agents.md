# 修改本地 Agents

当用户想修改 `trellis-research`、`trellis-implement` 或 `trellis-check` 行为时，编辑用户项目中的平台 agent files。

## 先读这些文件

1. 目标平台 agent directory
2. `.trellis/workflow.md` Phase 2 / research routing
3. 当前 task `prd.md`
4. 当前 task 的 `implement.jsonl` / `check.jsonl`
5. 相关 hook 或 agent prelude

## 常见路径

| 平台 | 路径 |
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

以用户项目中的实际路径为权威。

## 常见需求

| 需求 | 要编辑的 agent |
| --- | --- |
| Research 必须写文件，而不是只在聊天中回复 | `trellis-research` |
| 某些 local specs 必须在 implementation 前读取 | `trellis-implement` + `implement.jsonl` configuration rules |
| checking 期间必须运行特定 commands | `trellis-check` |
| Agent 不得修改某些目录 | 对应 agent 的 write boundary instructions |
| Agent output format 必须固定 | 对应 agent 的 final/reporting instructions |

## 修改原则

1. **保留角色边界**：research 调研并持久化；implement 写实现；check review 并修复。
2. **不要把项目 specs 硬编码进 agents**：长期 specs 属于 `.trellis/spec/`；agents 负责读取它们。
3. **明确读取顺序**：active task -> PRD -> info -> JSONL -> spec/research。
4. **明确写入边界**：哪些目录可以写，哪些不可以。
5. **跨平台同步**：当用户配置了多个平台时，判断只修改当前平台还是所有平台 agents。

## Agent Pull 平台

如果 agent file 包含“启动后读取 task/context”的 prelude，编辑时不要移除这些 steps。否则 agent 将只基于 chat context 工作，并绕过 Trellis 的核心机制。

## Hook Push 平台

如果 context 由 hook 注入，agent file 仍应保留职责边界。不要因为 hook 会注入 context 就从 agent 中移除 PRD/spec 要求。
