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

- `status=planning` + 没有 `prd.md` → **1.1**（加载 `trellis-brainstorm` 并创建中文 PRD）
- `status=planning` + `prd.md` 存在 + `implement.jsonl` 未整理（只有种子 `_example` 行） → **1.3**
- `status=planning` + `prd.md` + 已整理 `implement.jsonl` → **1.4**（运行 `task.py start` 进入 Phase 2）
- `status=in_progress` + implementation 尚未开始 → **2.1**
- `status=in_progress` + implementation 完成但尚未 check → **2.2**
- `status=in_progress` + check passed → **3.1**
- `status=completed`（少见；通常立即 archived） → archive flow

Phase 规则（完整详情在 `.trellis/workflow.md`）：

1. 在 phase 内**按顺序**运行 steps — `[required]` steps 不得跳过
2. 如果输出已存在，则 `[once]` steps 已完成（例如 1.1 的 `prd.md`；1.3 中带 curated entries 的 `implement.jsonl`）— 跳过它们
3. 如果发现情况需要，可以回到更早的 phase

## 第 4 步：加载具体 Step

一旦知道要从哪个 step 继续：

```bash
python3 ./.trellis/scripts/get_context.py --mode phase --step <X.X> --platform opencode
```

遵循加载的说明。每个 `[required]` step 完成后，移动到下一步。

---

## 参考

完整 workflow、skill routing table 和 DO-NOT-skip table 位于 `.trellis/workflow.md`。此命令只是入口 — 规范指南在那里。
