# 本地 Spec 系统

`.trellis/spec/` 是用户项目特定的工程 spec library。Trellis 不是让 AI 记住 conventions；它会注入相关 specs，或要求 AI 在正确时机读取它们。

## 目录模型

常见单仓结构：

```text
.trellis/spec/
├── backend/
│   ├── index.md
│   └── ...
├── frontend/
│   ├── index.md
│   └── ...
└── guides/
    ├── index.md
    └── ...
```

常见 monorepo 结构：

```text
.trellis/spec/
├── cli/
│   ├── backend/
│   │   ├── index.md
│   │   └── ...
│   └── unit-test/
│       ├── index.md
│       └── ...
├── docs-site/
│   └── docs/
│       ├── index.md
│       └── ...
└── guides/
    ├── index.md
    └── ...
```

`index.md` 是每个 layer 的入口。它应列出 开发前检查清单 和 质量检查。具体 guidelines 位于同目录的其他 Markdown 文件中。

## Package 配置

`.trellis/config.yaml` 可以声明 packages：

```yaml
packages:
  cli:
    path: packages/cli
  docs-site:
    path: docs-site
    type: submodule
default_package: cli
```

AI 可以运行：

```bash
python3 ./.trellis/scripts/get_context.py --mode packages
```

此命令列出当前项目的 packages 和 spec layers。配置 context JSONL 时以此输出为参考。

## Specs 如何进入 Tasks

Task 进入 implementation 前，Phase 1.3 应将相关 specs 写入 `implement.jsonl` / `check.jsonl`：

```jsonl
{"file": ".trellis/spec/cli/backend/index.md", "reason": "CLI backend conventions"}
{"file": ".trellis/spec/cli/unit-test/conventions.md", "reason": "Test expectations"}
```

Sub-agents 或 platform preludes 读取这些 JSONL 文件并加载引用的 specs。在没有 sub-agent 支持的平台上，AI 应根据 workflow 直接读取相关 specs。

## Specs 应包含什么

Specs 应包含项目的可执行工程 conventions，而不是通用 best practices：

- 文件应该放在哪里。
- Error handling 应如何表达。
- APIs、hooks 和 commands 的 input/output contracts。
- 禁止的 patterns。
- 需要 tests 的情况。
- 项目特定 pitfalls 以及如何避免。

当 AI 在 implementation 或 debugging 中学到新规则时，应更新 `.trellis/spec/`，而不是只在聊天中总结。

## 本地自定义点

| 需求 | 编辑位置 |
| --- | --- |
| 添加新 spec layer | `.trellis/spec/<package>/<layer>/index.md` 和对应 guideline files。 |
| 修改 monorepo spec mapping | `.trellis/config.yaml` 中的 `packages` / `default_package` / `spec_scope`。 |
| 修改 AI 在 implementation 前读取哪些 specs | task 的 `implement.jsonl`。 |
| 修改 AI 在 checking 时读取哪些 specs | task 的 `check.jsonl`。 |
| 修改何时应更新 specs | `.trellis/workflow.md` 中的 Phase 3.3 和 `trellis-update-spec` skill。 |

## 边界

`.trellis/spec/` 是用户的项目 specification，不是 Trellis built-in templates 的永久副本。AI 应鼓励用户根据实际项目代码更新它，而不是把 Trellis default templates 视为不可变文档。
