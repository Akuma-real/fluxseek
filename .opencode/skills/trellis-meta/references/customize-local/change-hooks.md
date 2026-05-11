# 修改本地 Hooks

Hooks 是连接平台与 Trellis 的自动化层。当用户想修改“何时注入 context”“shell commands 如何继承 session”或“agent 启动前读取哪些文件”时，hooks 通常是编辑点。

## 先读这些文件

1. 目标平台 settings/config，例如 `.claude/settings.json`、`.codex/hooks.json`、`.cursor/hooks.json`
2. 目标平台 hooks directory
3. `.trellis/scripts/common/active_task.py`
4. `.trellis/scripts/common/session_context.py`
5. `.trellis/workflow.md`

## 常见 Hook 类型

| Hook | 用途 |
| --- | --- |
| session-start | session starts、clears 或 compacts 时注入 Trellis overview。 |
| workflow-state | 每次用户输入时注入 state hint。 |
| sub-agent context | agent 启动前注入 PRD/spec/research。 |
| shell session bridge | 让 shell 中的 `task.py` commands 看到同一个 session identity。 |

## 修改步骤

1. 在 settings/config 中找到 hook registration。
2. 确认已注册 script path 存在。
3. 读取 hook script，识别 inputs、outputs 和被调用的 `.trellis/scripts/`。
4. 修改 hook 行为。
5. 如果 hook 依赖 workflow content，同步 `.trellis/workflow.md`。

## 示例：修改 New-Session 注入内容

先找到 session-start hook：

```text
.claude/settings.json
.claude/hooks/session-start.py
```

如果 hook 最终调用 `.trellis/scripts/get_context.py` 或 `session_context.py`，编辑本地 script 通常比在 hook 中硬编码内容更稳健。

## 示例：Agent 没有读取 JSONL

先确认：

```bash
python3 ./.trellis/scripts/task.py current --source
python3 ./.trellis/scripts/task.py validate <task>
```

如果 task 和 JSONL 正确，判断平台使用 hook push 还是 agent pull。对于 hook push，编辑 `inject-subagent-context`；对于 agent pull，编辑 agent file。

## 说明

- Settings 负责 registration，hook scripts 负责 behavior；两者一起检查。
- 不同平台支持不同 hook events。不要直接复制另一个平台的 settings。
- Hooks 应读取项目本地 `.trellis/`；不应依赖 Trellis upstream source paths。
- Hook failures 应产生可见错误，避免 AI 静默丢失 context。
