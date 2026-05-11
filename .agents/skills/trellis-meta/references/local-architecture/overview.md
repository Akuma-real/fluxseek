# 本地 Trellis 架构概览

`trellis-meta` 面向已经运行 `trellis init` 的用户项目。用户机器通常只有通过 npm 安装的 `trellis` 命令，以及项目内生成的 Trellis 文件；不一定有 Trellis CLI source code。

因此，当 AI 使用此 skill 时，默认自定义目标是用户项目内的本地文件：

- `.trellis/`：workflow、tasks、specs、memory、scripts 和 runtime state。
- 平台目录：`.claude/`、`.codex/`、`.cursor/`、`.opencode/`、`.kiro/`、`.gemini/`、`.qoder/`、`.codebuddy/`、`.github/`、`.factory/`、`.pi/`、`.kilocode/`、`.agent/`、`.windsurf/` 以及类似目录。
- 共享 skill layer：`.agents/skills/`。

不要默认引导用户 fork Trellis CLI repository。只有当用户明确表示想修改 Trellis upstream source、发布 npm package 或贡献 PR 时，才把 upstream source code 作为操作目标。

## 本地系统模型

Trellis 在用户项目中提供三层：

1. **Workflow layer**：`.trellis/workflow.md` 定义 phases、routing、next actions 和 prompt blocks。
2. **Persistence layer**：`.trellis/tasks/`、`.trellis/spec/` 和 `.trellis/workspace/` 存储 tasks、specs 和 session memory。
3. **Platform integration layer**：平台目录中的 hooks、settings、agents、skills、commands、prompts 和 workflows 将 Trellis workflow 连接到不同 AI tools。

三层都位于用户项目内，因此 AI 可以直接读取和修改它们。

## 核心路径

| 路径 | 用途 |
| --- | --- |
| `.trellis/workflow.md` | Workflow phases、skill routing 和 workflow-state prompt blocks。 |
| `.trellis/config.yaml` | Project configuration、task lifecycle hooks、monorepo package configuration 和 journal configuration。 |
| `.trellis/spec/` | 用户项目特定编码约定和 thinking guides。 |
| `.trellis/tasks/` | 每个 task 的 PRD、technical notes、research files 和 JSONL context。 |
| `.trellis/workspace/` | Per-developer journals 和 cross-session memory。 |
| `.trellis/scripts/` | commands、hooks 和 context injection 使用的本地 Python runtime。 |
| `.trellis/.runtime/` | Session-level runtime state，例如 current task pointer。 |
| `.trellis/.template-hashes.json` | Trellis-managed files 的 template hashes，update 用它判断本地文件是否已被用户修改。 |

## AI 自定义原则

1. **先找到本地事实来源**：不要凭记忆编辑。先读取 `.trellis/workflow.md`、`.trellis/config.yaml`、相关平台目录和相关 task files。
2. **编辑用户项目，而不是 npm package cache**：修改项目内生成的文件，不修改 `node_modules` 或全局 npm install 目录。
3. **保持平台文件与 `.trellis/` 对齐**：如果 workflow routing 变化，也检查平台 skills 或 commands 是否仍描述同一 flow。
4. **将项目特定规则放在 `.trellis/spec/` 或 local skill**：不要把团队 conventions 放入 `trellis-meta`。
5. **保留用户变更**：如果文件已经被本地修改，从当前内容继续工作，而不是用默认 template 覆盖。

## 如何使用本目录

- 要了解 init 后有哪些文件，读取 `generated-files.md`。
- 要修改 phases、routing 或 next actions，读取 `workflow.md`。
- 要修改 task model、JSONL context 或 active task behavior，读取 `task-system.md`。
- 要修改 coding convention injection，读取 `spec-system.md`。
- 要理解 journals 和 cross-session memory，读取 `workspace-memory.md`。
- 要修改 hooks 或 sub-agent context loading，读取 `context-injection.md`。
