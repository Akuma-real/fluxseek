# 修改本地 Skills、Commands、Prompts 与 Workflows

当用户想修改 AI entry points、auto-trigger rules 或显式 command 行为时，编辑本地平台目录中的 skills、commands、prompts 或 workflows。

## 先读这些文件

1. `.trellis/workflow.md`
2. 目标平台 skill/command/prompt/workflow 目录
3. 相关 agent 或 hook files
4. 项目规则是否已存在于 `.trellis/spec/`

## 选择哪种入口类型

| 目标 | 建议 |
| --- | --- |
| AI 应自动知道某能力 | 添加或修改 skill。 |
| 用户想用 command 手动触发 | 添加或修改 command/prompt/workflow。 |
| 团队项目 conventions | 优先使用 `.trellis/spec/` 或 project-local skill。 |
| 修改 Trellis flow 语义 | 同步 `.trellis/workflow.md`。 |

## 修改 Skill

Skill 通常是：

```text
<skill-name>/
├── SKILL.md
└── references/
```

`SKILL.md` 应保持简短，负责 triggering/routing。将长内容放在 `references/`，供 AI 按需读取。

frontmatter description 应指定何时使用该 skill。示例：

```yaml
description: "自定义本项目 deployment workflow 和 release checklist 时使用。"
```

不要写“helpful project skill”等模糊描述；它们可能误触发。

## 修改 Command/Prompt/Workflow

显式入口点应说明：

- 用户如何触发它。
- 要读取哪些 `.trellis/` 文件。
- 要运行哪些 scripts。
- 完成后如何报告。

如果 command 只是重复 workflow rules，优先让它引用/读取 `.trellis/workflow.md`，而不是维护第二份 flow 副本。

## 常见路径

| 平台 | 入口目录 |
| --- | --- |
| Claude Code | `.claude/skills/`, `.claude/commands/` |
| Cursor | `.cursor/skills/`, `.cursor/commands/` |
| OpenCode | `.opencode/skills/`, `.opencode/commands/` |
| Codex | `.agents/skills/`, `.codex/skills/` |
| GitHub Copilot | `.github/skills/`, `.github/prompts/` |
| Kilo / Antigravity / Windsurf | workflows + skills |

## 添加 Project-Local Skill

如果用户想记录团队私有 customizations，创建 project-local skill，例如：

```text
.claude/skills/project-trellis-local/
└── SKILL.md
```

对于多平台项目，在每个平台 skill directory 中添加等价版本，或在支持 shared layer 的平台上使用 `.agents/skills/`。

## 说明

- 不要把每个平台的语法混进一个文件。
- 不要只修改一个平台入口点却声称支持所有平台。
- 不要把长期工程 conventions 藏在 command 中；写入 `.trellis/spec/`。
