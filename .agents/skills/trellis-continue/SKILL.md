---
name: trellis-continue
description: "恢复当前 task 的工作。加载 workflow Phase Index，判断该从哪个 phase/step 继续，然后通过 get_context.py --mode phase 拉取 step 级详情。回到进行中的 task 且需要知道下一步做什么时使用。"
---

# 继续当前 Task

恢复当前 task 的工作 — 在 `.trellis/workflow.md` 中从正确 phase/step 继续。

---

## 第 1 步：加载当前 Context

```bash
python3 ./.trellis/scripts/get_context.py
```

确认：current task、git state、recent commits。

## 第 2 步：加载 Phase Index

```bash
python3 ./.trellis/scripts/get_context.py --mode phase
```

显示 Phase Index（Plan / Execute / Finish）及 routing + skill mapping。

## 第 3 步：判断当前位置

`get_context.py` 显示 active task 的 `status` 字段。按 `status` + artifact 是否存在路由：

- `status=planning` + 无 `prd.md` → **1.1**（加载 `trellis-brainstorm`）
- `status=planning` + 只有 `prd.md` → 判断 task 是轻量还是复杂。轻量可以进入 **1.4** review；复杂返回 **1.1** 补充 `design.md` + `implement.md`。
- `status=planning` + 复杂 artifacts 已完成 + sub-agent jsonl 未整理（只有种子 `_example` 行） → **1.3**
- `status=planning` + 所需 artifacts 已完成 + 所需 jsonl 已整理或 inline mode → **1.4**（请求 start review；仅在用户确认后运行 `task.py start`）
- `status=in_progress` + implementation 未开始 → **2.1**
- `status=in_progress` + implementation 已完成但尚未检查 → **2.2**
- `status=in_progress` + check 已通过 → **3.1**
- `status=completed`（少见；通常立即 archived） → archive flow

Phase 规则（完整详情在 `.trellis/workflow.md`）：

1. 在 phase 内**按顺序**运行 steps — `[required]` steps 不得跳过
2. 如果输出已存在，则 `[once]` steps 已完成。单独 `prd.md` 只对轻量 tasks 足够；复杂 tasks 还需要 `design.md` 和 `implement.md`。
3. 如果发现情况需要，可以回到更早的 phase

## 第 4 步：加载具体 Step

一旦知道要从哪个 step 继续：

```bash
python3 ./.trellis/scripts/get_context.py --mode phase --step <X.X> --platform codex
```

遵循加载的说明。每个 `[required]` step 完成后，移动到下一步。

---

## 参考

完整 workflow、skill routing table 和 DO-NOT-skip table 位于 `.trellis/workflow.md`。此命令只是入口 — 规范指南在那里。
