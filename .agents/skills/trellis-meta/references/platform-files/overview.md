# 平台文件概览

Trellis 将同一本地架构连接到不同 AI tools。`.trellis/` 存储共享 runtime；平台目录存储 adapter files，用来定义每个 AI tool 如何进入 Trellis。

当本地 AI 修改 Trellis 时，应先区分两类文件：

- **共享文件**：`.trellis/workflow.md`、`.trellis/tasks/`、`.trellis/spec/`、`.trellis/scripts/`。
- **平台文件**：`.claude/`、`.codex/`、`.cursor/`、`.opencode/`、`.kiro/`、`.gemini/`、`.qoder/`、`.codebuddy/`、`.github/`、`.factory/`、`.pi/`、`.kilocode/`、`.agent/`、`.windsurf/` 以及类似目录。

平台文件不存储业务状态。它们让对应 AI tool 读取 Trellis state、调用 Trellis scripts，并加载 Trellis skills/agents/hooks。

## 平台文件类别

| 类别 | 常见路径 | 用途 |
| --- | --- | --- |
| settings/config | `.claude/settings.json`, `.codex/hooks.json`, `.qoder/settings.json` | 注册 hooks、plugins、extensions 或平台行为。 |
| hooks/plugins/extensions | `.claude/hooks/`, `.opencode/plugins/`, `.pi/extensions/` | 在 session start、user input、agent startup、shell execution 等事件注入 context。 |
| agents | `.claude/agents/`, `.codex/agents/`, `.kiro/agents/` | 定义 `trellis-research`、`trellis-implement` 和 `trellis-check`。 |
| skills | `.claude/skills/`, `.agents/skills/`, `.qoder/skills/` | 可自动触发或按需读取的能力描述。 |
| commands/prompts/workflows | `.cursor/commands/`, `.github/prompts/`, `.windsurf/workflows/` | 用户显式调用的入口点。 |

## 三种平台集成模式

### 1. Hook / Extension 驱动

这些平台可以在特定事件触发 scripts 或 plugins，并主动向 AI 注入 Trellis context。

常见能力：

- `.trellis/` overview 的 session-start injection。
- 每个用户回合的 workflow-state hints。
- sub-agents 启动时注入 PRD/spec/research。
- Shell commands 继承 session identity。

要改变“AI 何时知道什么”，先检查 hooks/plugins/extensions 和 settings。

### 2. Agent Prelude / Pull-Based

有些平台无法可靠地让 hooks 重写 sub-agent prompts，因此 agent file 本身会指示 agent 启动后读取 active task、PRD 和 JSONL context。

要改变 sub-agents 如何加载 context，检查 agent files 本身。

### 3. Main-Session Workflow

有些平台没有 Trellis sub-agent 或 hook 能力。它们依赖 workflows/skills/commands 引导 main-session AI 读取文件、运行 scripts 并推进 tasks。

要改变行为，检查平台 workflows/skills/commands 和 `.trellis/workflow.md`。

## 本地修改顺序

当用户要求自定义某个平台的行为时，AI 应按此顺序检查文件：

1. 读取 `.trellis/workflow.md` 确认共享 flow。
2. 读取目标平台 settings/config，查看注册了哪些 hooks/agents/skills/commands。
3. 读取目标平台 agents/skills/commands/hooks。
4. 修改最接近用户需求的本地文件。
5. 如果变更影响共享 flow，同步 `.trellis/workflow.md` 或 `.trellis/spec/`。

不要只修改平台文件而忘记共享 workflow。也不要只修改 `.trellis/workflow.md` 而忘记平台入口点可能仍包含旧描述。
