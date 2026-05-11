# Init 后生成的本地文件

`trellis init` 将 Trellis runtime 写入用户项目。之后，`trellis update` 会尝试更新 Trellis-managed template files，但它使用 `.trellis/.template-hashes.json` 判断哪些文件已被用户修改。

本页只描述用户项目内可见且可编辑的文件。

## `.trellis/`

```text
.trellis/
├── workflow.md
├── config.yaml
├── .developer
├── .version
├── .template-hashes.json
├── .runtime/
├── scripts/
├── spec/
├── tasks/
└── workspace/
```

| 路径 | 通常可编辑？ | 说明 |
| --- | --- | --- |
| `.trellis/workflow.md` | 是 | 本地 workflow documentation 和 AI routing rules。 |
| `.trellis/config.yaml` | 是 | Project configuration、hooks、packages、journal line limits 和相关 settings。 |
| `.trellis/spec/` | 是 | Project specs，预期由用户和 AI 定期更新。 |
| `.trellis/tasks/` | 是 | Task material 和 research artifacts，由 task workflow 维护。 |
| `.trellis/workspace/` | 是 | Session records，通常由 `add_session.py` 写入。 |
| `.trellis/scripts/` | 谨慎 | Local runtime。可以自定义，但只能在理解 call chain 后进行。 |
| `.trellis/.runtime/` | 否 | Runtime state，通常由 hooks/scripts 自动写入。 |
| `.trellis/.developer` | 谨慎 | 当前 developer identity。 |
| `.trellis/.version` | 否 | update/migration logic 使用的 Trellis version record。 |
| `.trellis/.template-hashes.json` | 否 | Template hash record。不要在这里手写 business rules。 |

## 平台目录

不同平台生成不同目录。常见类别：

| 类别 | 示例路径 | 用途 |
| --- | --- | --- |
| hooks | `.claude/hooks/`, `.codex/hooks/`, `.cursor/hooks/` | 注入 session context、workflow-state 和 sub-agent context。 |
| settings | `.claude/settings.json`, `.codex/hooks.json`, `.qoder/settings.json` | 告诉平台何时运行 hooks 或 plugins。 |
| agents | `.claude/agents/`, `.codex/agents/`, `.kiro/agents/` | 定义 `trellis-research`、`trellis-implement` 和 `trellis-check` 等 agents。 |
| skills | `.claude/skills/`, `.agents/skills/`, `.qoder/skills/` | 可自动触发或可由 AI 读取的 skills。 |
| commands/prompts/workflows | `.cursor/commands/`, `.github/prompts/`, `.windsurf/workflows/` | 用户显式调用的 command 或 workflow 入口点。 |

修改平台目录时，也确认 `.trellis/workflow.md` 是否仍描述同一 flow。

## Template Hashes 的含义

`.trellis/.template-hashes.json` 记录 Trellis 上次写入 template file 时的 content hash。`trellis update` 用它区分三种情况：

| 情况 | 更新行为 |
| --- | --- |
| 用户未修改文件 | 可自动更新。 |
| 用户已修改文件 | 提示用户选择 overwrite、keep 或生成 `.new`。 |
| 文件不再是当前 template | 可按 migration rules 删除、重命名或保留。 |

当 AI 自定义本地 Trellis 文件时，不需要手动维护 hashes。Trellis update 将结果识别为 “modified by the user” 是正常现象。

## 本地自定义边界

默认可编辑：

- `.trellis/workflow.md`
- `.trellis/config.yaml`
- `.trellis/spec/**`
- `.trellis/scripts/**`
- Platform hooks, settings, agents, skills, commands, prompts, and workflows

默认不要编辑：

- 全局 npm install directory
- `node_modules/@mindfoldhq/trellis`
- Trellis GitHub repository source code
- `.trellis/.runtime/**` 下的具体 state files
- `.trellis/.template-hashes.json` 内的 hash contents

只有当用户明确想贡献 upstream 时，才切换到 Trellis CLI source-code 视角。
