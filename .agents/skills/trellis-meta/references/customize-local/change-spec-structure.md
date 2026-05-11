# 修改本地 Spec 结构

当用户想修改 AI 遵循的工程 conventions、添加新 spec layers，或调整 monorepo package mapping 时，编辑 `.trellis/spec/` 和 `.trellis/config.yaml`。

## 先读这些文件

1. `.trellis/config.yaml`
2. `.trellis/spec/`
3. `.trellis/workflow.md` Phase 1.3 和 Phase 3.3
4. 当前 task 的 `implement.jsonl` / `check.jsonl`

## 常见需求

| 需求 | 编辑位置 |
| --- | --- |
| 添加 backend/frontend/docs/test spec layer | `.trellis/spec/<layer>/` 或 `.trellis/spec/<package>/<layer>/` |
| 添加共享 thinking guides | `.trellis/spec/guides/` |
| 调整 monorepo packages | `.trellis/config.yaml` 中的 `packages` |
| 修改 default package | `.trellis/config.yaml` 中的 `default_package` |
| 控制 spec scanning scope | `.trellis/config.yaml` 中的 `spec_scope` |
| 让某 task 读取新 spec | Task `implement.jsonl` / `check.jsonl` |

## 添加 Spec Layer

单仓示例：

```text
.trellis/spec/security/
├── index.md
└── auth.md
```

Monorepo 示例：

```text
.trellis/spec/webapp/security/
├── index.md
└── auth.md
```

`index.md` 应包括：

- 此 layer 适用于哪些代码。
- 开发前检查清单。
- 质量检查。
- 指向具体 guideline files 的 links。

## 更新 Context

添加 spec 不意味着每个 task 都会自动读取它。当前 task 必须在 JSONL 中引用它：

```bash
python3 ./.trellis/scripts/task.py add-context <task> implement ".trellis/spec/webapp/security/index.md" "Security conventions"
python3 ./.trellis/scripts/task.py add-context <task> check ".trellis/spec/webapp/security/index.md" "Security review rules"
```

## 修改 Monorepo Packages

`.trellis/config.yaml` 示例：

```yaml
packages:
  webapp:
    path: apps/web
  api:
    path: apps/api
default_package: webapp
```

编辑后运行：

```bash
python3 ./.trellis/scripts/get_context.py --mode packages
```

用此输出确认 AI 能看到正确 packages 和 spec layers。

## 说明

- Specs 是用户项目 conventions，可根据项目需求修改。
- 不要把临时 task 信息放入 specs；临时信息放在 task 中。
- 不要只把长期 conventions 放在 agents 或 commands 中；将其保存在 specs。
- 修改 spec 结构后，检查现有 task JSONL files 是否仍指向存在的文件。
