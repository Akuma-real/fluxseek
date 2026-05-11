# 本地 Workspace Memory 系统

`.trellis/workspace/` 存储 cross-session memory。它的目的是让 AI 和人类理解不同窗口、不同日期之前发生过什么。

## 目录结构

```text
.trellis/workspace/
├── index.md
└── <developer>/
    ├── index.md
    ├── journal-1.md
    └── journal-2.md
```

| 文件 | 用途 |
| --- | --- |
| `.trellis/.developer` | 当前 developer identity。 |
| `.trellis/workspace/index.md` | Global workspace overview。 |
| `.trellis/workspace/<developer>/index.md` | 某 developer 的 session index。 |
| `.trellis/workspace/<developer>/journal-N.md` | Session journal。 |

## 开发者身份

首次运行：

```bash
python3 ./.trellis/scripts/init_developer.py <name>
```

这会创建 `.trellis/.developer` 和对应 workspace directory。AI 不应随意更改 developer identity；如果身份错误，先确认当前项目的使用者是谁。

## Journal

`journal-N.md` 记录每个 session 中已完成或部分完成的工作。默认每个 journal 约 2000 行；超过后轮转到下一个文件。

记录 session 的常用命令：

```bash
python3 ./.trellis/scripts/add_session.py \
  --title "Session title" \
  --summary "What changed" \
  --commit "abc1234"
```

没有 commit 的 planning 或 review 工作也可以通过 `--no-commit` 或空 commit 值记录。

## Workspace Memory 与 Tasks 的关系

| 系统 | 存储内容 |
| --- | --- |
| `.trellis/tasks/` | 特定 task 的 requirements、design、research 和 state。 |
| `.trellis/workspace/` | 跨 tasks 和 sessions 的工作记录。 |
| `.trellis/spec/` | 作为长期 conventions 保留的工程知识。 |

如果信息只对当前 task 有用，放入 task directory。
如果信息描述当前 session 发生了什么，放入 workspace journal。
如果信息应在未来每次写代码时遵循，放入 spec。

## 本地自定义点

| 需求 | 编辑位置 |
| --- | --- |
| 修改最大 journal 行数 | `.trellis/config.yaml` 中的 `max_journal_lines`。 |
| 修改 session auto-commit message | `.trellis/config.yaml` 中的 `session_commit_message`。 |
| 修改 session content format | `.trellis/scripts/add_session.py`。 |
| 修改 workspace 在 context 中的显示方式 | `.trellis/scripts/common/session_context.py`。 |

## AI 使用规则

AI 不应把 workspace 当作唯一事实来源。恢复 task 时，先读取当前 task，然后用 workspace 作为背景。Task 完成后，将重要过程记录到 workspace；如果产生长期规则，则更新 spec。
