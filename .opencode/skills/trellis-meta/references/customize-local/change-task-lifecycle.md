# 修改本地 Task 生命周期

Task lifecycle 包括 creation、start、context configuration、finish、archive、parent/child tasks 和 lifecycle hooks。默认自定义目标是 `.trellis/tasks/`、`.trellis/config.yaml` 和 `.trellis/scripts/`。

## 先读这些文件

1. `.trellis/workflow.md`
2. `.trellis/config.yaml`
3. `.trellis/scripts/task.py`
4. `.trellis/scripts/common/task_store.py`
5. `.trellis/scripts/common/task_utils.py`
6. 当前 task 的 `.trellis/tasks/<task>/task.json`

## 常见需求与编辑点

| 需求 | 编辑点 |
| --- | --- |
| task creation 后自动同步外部系统 | `.trellis/config.yaml` 中的 `hooks.after_create`。 |
| task start 后自动更新 status | `.trellis/config.yaml` 中的 `hooks.after_start`。 |
| task finish 后运行 script | `.trellis/config.yaml` 中的 `hooks.after_finish`。 |
| archive 后清理外部资源 | `.trellis/config.yaml` 中的 `hooks.after_archive`。 |
| 修改默认 task fields | `.trellis/scripts/common/task_store.py`。 |
| 修改 task parsing/search | `.trellis/scripts/common/task_utils.py`。 |
| 修改 active task behavior | `.trellis/scripts/common/active_task.py`。 |

## lifecycle hooks

`.trellis/config.yaml` 支持：

```yaml
hooks:
  after_create:
    - "python3 .trellis/scripts/hooks/my_sync.py create"
  after_start:
    - "python3 .trellis/scripts/hooks/my_sync.py start"
  after_finish:
    - "python3 .trellis/scripts/hooks/my_sync.py finish"
  after_archive:
    - "python3 .trellis/scripts/hooks/my_sync.py archive"
```

Hook commands 会收到 `TASK_JSON_PATH` environment variable，指向当前 task 的 `task.json`。Hook failures 通常应 warning，但不阻塞主 task 操作。

## 修改 Task Fields

如果用户想添加 project-local fields，优先将它们放在 `task.json` 的 `meta` 下，以避免破坏 existing scripts 对 standard fields 的假设。

示例：

```json
"meta": {
  "linearIssue": "ENG-123",
  "risk": "high"
}
```

如果确实需要修改 standard fields，检查每个读取 `task.json` 的本地 script。

## 修改 Active Task

Active task 是存储在 `.trellis/.runtime/sessions/` 的 session-level state。不要 fallback 到 global `.current-task` 模型。如果用户想修改 active task behavior，编辑：

- `.trellis/scripts/common/active_task.py`
- platform hooks or shell session bridges
- active task descriptions in `.trellis/workflow.md`

### `task.py create` 设置 Active Pointer

`.trellis/scripts/common/task_store.py` 中的 `cmd_create` 在写入新 task 目录后 best-effort 调用 `set_active_task`。行为：

- 当调用 shell 带有 session identity（`TRELLIS_CONTEXT_ID` env var，或 `resolve_context_key` 能识别的任何平台特定 session env — 见 `active_task.py:_ENV_SESSION_KEYS`）时，`.trellis/.runtime/sessions/<context_key>.json` 中的 per-session pointer 会被重写为指向新 task。task 的 `status=planning` 和 `[workflow-state:planning]` 会在下一个 `UserPromptSubmit` 立即触发。
- 当 session identity 不可用时（AI session 外的原始 CLI 调用，或不向 shell 传播 identity 的平台），task directory 仍会创建并写入 `status=planning`，但 active pointer 保持不变。用户回到 AI session 后，可稍后用 `task.py start <dir>` 关联该 task。

这让 `[workflow-state:planning]` 成为 `task.py create` 之后 brainstorm 和 JSONL curation 工作期间的 live breadcrumb。pre-R7 行为会让 breadcrumb 在 `task.py start` 前卡在 `no_task`，因此 planning block 实际上是死文本。

如果你 fork `task.py` 以添加新的 creation path（例如绕过 `cmd_create` 的外部 import），审计你的路径是否也调用 `set_active_task`。没有该调用时，你创建的 tasks 不会显示为 active。完整 status writer table 在 `.trellis/spec/cli/backend/workflow-state-contract.md`。

## 修改步骤

1. 用 `python3 ./.trellis/scripts/task.py current --source` 确认当前 task。
2. 读取当前 task 的 `task.json` 并确认 status 和 fields。
3. 对配置需求，先编辑 `.trellis/config.yaml`。
4. 对 script 行为需求，再编辑 `.trellis/scripts/`。
5. 如果 AI flow 改变，同步 `.trellis/workflow.md`。

## 不要

- 不要直接编辑 `.trellis/.runtime/sessions/` 来“修复”业务状态。
- 不要把项目私有 fields 硬编码到 scripts；优先使用 `meta`。
- 不要默认要求用户 fork Trellis CLI。
