---
name: trellis-start
description: "通过读取 .trellis/ 中的 workflow 指南、开发者身份、git 状态、active tasks 和项目指南来初始化 AI 开发 session。对传入任务分类，并路由到 brainstorm、直接编辑或 task workflow。开始新编码 session、恢复工作、启动新 task 或重建项目 context 时使用。"
---

# 启动 Session

初始化 Trellis 管理的开发 session。此平台没有 session-start hook，因此按以下步骤手动加载等效 context（每一步都对应 hook 原本会注入的 section）。

---

## 第 1 步：当前状态
身份、git 状态、current task、active tasks、journal 位置。

```bash
python3 ./.trellis/scripts/get_context.py
```

如果输出包含以 `Trellis update available:` 开头的行，汇总 session context 时逐字复制整行。不要缩短操作命令提示。

## 第 2 步：Workflow 概览
Phase Index + skill routing table + DO-NOT-skip rules。

```bash
python3 ./.trellis/scripts/get_context.py --mode phase
```

完整指南在 `.trellis/workflow.md`（按需读取）。

## 第 3 步：Guideline 索引
发现 packages + spec layers，然后读取每个相关 index file。

```bash
python3 ./.trellis/scripts/get_context.py --mode packages
cat .trellis/spec/guides/index.md
cat .trellis/spec/<package>/<layer>/index.md   # for each relevant layer
```

Index files 会列出实际开始编码时要读取的具体 guideline docs。

## 第 4 步：决定下一步 action
通过第 1 步你已知道 current task。检查 task 目录：

- **Active task status `planning` + 无 `prd.md`** → Phase 1.1。加载 `trellis-brainstorm` skill。
- **Active task status `planning` + `prd.md` 存在** → 留在 Phase 1。轻量 tasks 可以 PRD-only；复杂 tasks 需要 `design.md` + `implement.md`。在 `task.py start` 前加载相关 Phase 1 step 详情。
- **Active task status `in_progress`** → Phase 2 step 2.1。加载 step 详情：
  ```bash
  python3 ./.trellis/scripts/get_context.py --mode phase --step 2.1 --platform codex
  ```
- **No active task** → 先分类。简单对话 / 小任务只询问本轮是否要创建 Trellis task。复杂工作则询问是否可以创建 Trellis task 并进入 planning。如果用户说不，本 session 跳过 Trellis。

---

## Skill 路由（快速参考）

| 用户意图 | Skill |
|---|---|
| 新功能 / 需求不清楚 | `trellis-brainstorm` |
| 准备写代码 | `trellis-before-dev` |
| 已完成编码 / 质量检查 | `trellis-check` |
| 卡住 / 同一 bug 修复多次 | `trellis-break-loop` |
| 学到值得沉淀的内容 | `trellis-update-spec` |

完整规则 + anti-rationalization table 在 `.trellis/workflow.md`。
