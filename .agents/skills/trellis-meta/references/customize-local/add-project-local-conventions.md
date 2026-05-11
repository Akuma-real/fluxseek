# 添加项目本地 Conventions

用户通常不需要修改 Trellis 机制；他们需要本地 AI 理解团队 conventions。此时优先使用 `.trellis/spec/` 或 project-local skill，而不是编辑 `trellis-meta`。

## 内容放在哪里

| 内容类型 | 位置 |
| --- | --- |
| 代码必须遵循的规则 | `.trellis/spec/<layer>/` |
| Cross-layer 思考方法 | `.trellis/spec/guides/` |
| 项目特定 flow 的 AI 能力 | Platform-local skill |
| 一次性 task material | `.trellis/tasks/<task>/` |
| Session summary | `.trellis/workspace/<developer>/journal-N.md` |

## 创建 Project-Local Skill

如果用户希望 AI 知道“此项目如何自定义 Trellis”，创建 local skill：

```text
.claude/skills/trellis-local/
└── SKILL.md
```

示例：

```md
---
name: trellis-local
description: "本 repository 的项目本地 Trellis 自定义。修改本项目的 Trellis workflow、hooks、local agents 或团队专属 conventions 时使用。"
---

# Trellis 本地规则

## 本地范围

此 skill 只记录本 repository 的 Trellis 自定义。

## 自定义 Workflow 规则

- ...

## 本地 Hook 变更

- ...

## 本地 Agent 变更

- ...
```

对于多平台项目，将等价版本放入其他平台 skill directories，或对支持 shared layer 的平台使用 `.agents/skills/`。

## 写入 `.trellis/spec/`

如果内容是 coding convention，写入 spec。示例：

```text
.trellis/spec/backend/error-handling.md
.trellis/spec/frontend/components.md
.trellis/spec/guides/cross-platform-thinking-guide.md
```

写入后，更新对应 `index.md`，让 AI 能从入口找到新规则。

## 让当前 Task 使用新 Conventions

写入 spec 后，将其添加到当前 task context：

```bash
python3 ./.trellis/scripts/task.py add-context <task> implement ".trellis/spec/backend/error-handling.md" "Error handling conventions"
python3 ./.trellis/scripts/task.py add-context <task> check ".trellis/spec/backend/error-handling.md" "Review error handling"
```

## 不要把项目私有规则存入 `trellis-meta`

`trellis-meta` 是用于理解 Trellis 架构和本地自定义入口点的 public skill。将项目私有内容放在：

- `.trellis/spec/`
- a project-local skill
- the current task
- workspace journal

这可以防止未来 Trellis built-in `trellis-meta` 更新覆盖团队自己的 conventions。
