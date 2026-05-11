---
name: trellis-meta
description: "理解并自定义用户项目内的本地 Trellis 架构。修改 trellis init 生成的 .trellis 以及平台 hooks、settings、agents、skills、commands、prompts 或 workflows 时使用。"
---

# Trellis Meta

此 skill 面向已经在项目中运行 `trellis init` 的本地 Trellis 用户。读取后，AI 应理解该用户项目内的 Trellis 架构、运行模型和自定义入口点，然后按用户请求修改生成的 `.trellis/` 和平台目录文件。

默认操作范围是用户项目中的本地文件：

- `.trellis/`：workflow、config、tasks、spec、workspace、scripts 和 runtime state。
- 平台目录：`.claude/`、`.codex/`、`.cursor/`、`.opencode/`、`.kiro/`、`.gemini/`、`.qoder/`、`.codebuddy/`、`.github/`、`.factory/`、`.pi/`、`.kilocode/`、`.agent/`、`.windsurf/` 以及类似目录。
- 共享 skill layer：`.agents/skills/`。

不要假设用户拥有 Trellis source repository。不要默认修改全局 npm install 目录或 `node_modules`。

## 如何使用

1. 先读取 `references/local-architecture/overview.md`，建立本地 Trellis 系统模型。
2. 如果请求涉及特定 AI 工具，读取 `references/platform-files/platform-map.md` 和相关平台文件说明。
3. 如果用户想改变行为，读取 `references/customize-local/overview.md`，然后打开具体自定义主题。
4. 编辑前，读取用户项目中的实际文件，并将本地内容视为权威。

## 参考

### 本地架构

- `references/local-architecture/overview.md`：三层本地 Trellis 架构和自定义原则。
- `references/local-architecture/generated-files.md`：`trellis init` 生成的文件及其自定义边界。
- `references/local-architecture/workflow.md`：`.trellis/workflow.md` 中的 phases、routing 和 workflow-state blocks。
- `references/local-architecture/task-system.md`：Task directories、active tasks、JSONL context 和 task runtime。
- `references/local-architecture/spec-system.md`：`.trellis/spec/` 的组织和注入方式。
- `references/local-architecture/workspace-memory.md`：`.trellis/workspace/`、journals 和 cross-session memory。
- `references/local-architecture/context-injection.md`：Hooks、sub-agent preludes 和 context injection paths。

### 平台文件

- `references/platform-files/overview.md`：共享 `.trellis/` 文件与平台目录的关系。
- `references/platform-files/platform-map.md`：skills、agents、hooks 和 extensions 的平台目录与路径。
- `references/platform-files/hooks-and-settings.md`：settings/config files、hooks、plugins 和 extensions 如何连接到 Trellis。
- `references/platform-files/agents.md`：`trellis-research`、`trellis-implement` 和 `trellis-check` 的本地文件职责。
- `references/platform-files/skills-and-commands.md`：skills、commands、prompts 和 workflows 的区别，以及如何修改它们。

### 本地自定义

- `references/customize-local/overview.md`：为用户请求选择正确的本地自定义入口点。
- `references/customize-local/change-workflow.md`：修改 phases、routing、next actions 和 workflow-state。
- `references/customize-local/change-task-lifecycle.md`：修改 task creation、status、archive behavior 和 hooks。
- `references/customize-local/change-context-loading.md`：修改 tasks、specs、journals 和 hook context 的加载方式。
- `references/customize-local/change-hooks.md`：修改平台 hooks、settings 和 shell session bridges。
- `references/customize-local/change-agents.md`：修改 research、implement 和 check agent 行为。
- `references/customize-local/change-skills-or-commands.md`：添加或修改本地 skills、commands、prompts 和 workflows。
- `references/customize-local/change-spec-structure.md`：调整 `.trellis/spec/` 下的项目 spec 结构。
- `references/customize-local/add-project-local-conventions.md`：将团队规则放入项目本地 specs 或 local skills。

## 当前规则

- `.trellis/workflow.md` 是本地 workflow 事实来源。
- `.trellis/config.yaml` 是项目级 Trellis 配置和 task hook 配置入口。
- `.trellis/spec/` 存储用户项目特定的编码约定和设计约束。
- `.trellis/tasks/` 存储 task PRDs、technical notes、research files 和 JSONL context。
- `.trellis/workspace/` 存储 developer journals 和 cross-session memory。
- Platform settings/config files 决定哪些 hooks、agents、skills、commands、prompts 和 workflows 实际运行。
- `.trellis/.template-hashes.json` 和 `.trellis/.runtime/` 是 management/runtime state files。编辑前确认必要性。

## 不要

- 不要把 Trellis upstream source code 当作本地自定义的默认目标。
- 不要通过修改全局 npm install 目录或 `node_modules/@mindfoldhq/trellis` 来实现项目需求。
- 不要用默认 templates 覆盖用户已修改的本地文件。
- 不要把团队私有项目规则放入 public `trellis-meta`；项目规则应放在 `.trellis/spec/` 或 project-local skill 中。
- 不要把已移除的历史机制描述为当前 Trellis 行为。
