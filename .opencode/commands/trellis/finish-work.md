# 完成工作

收尾当前 session：archive active task（以及用户想清理的其他已完成但未归档 tasks），并记录 session journal。代码 commits 不在这里完成 — 它们发生在调用此命令前的 workflow Phase 3.4。

## 第 1 步：调查当前状态

```bash
python3 ./.trellis/scripts/get_context.py --mode record
```

这会打印：

- **My active tasks** — review 除当前 task 外是否还有实际已完成（代码已 merged、AC met）且应在本轮归档的 task。
- **Git status** — 快速查看 dirty 内容。
- **Recent commits** — 第 4 步需要它们的 hashes 用于 `--commit`。

如果 `--mode record` 显示其他不属于当前 session 的已完成 tasks，用一次性确认告知用户："这些 N 个 tasks 看起来已完成 — 本轮也归档它们吗？[y/N]"。默认否；当前 active task 无论如何都会在第 3 步归档。

## 第 2 步：Sanity check — 分类 dirty paths

运行：

```bash
git status --porcelain
```

过滤掉 `.trellis/workspace/` 和 `.trellis/tasks/` 下的 paths — 它们由 `add_session.py` 和 `task.py archive` auto-commits 管理，会作为此 skill 自身工作的一部分显示为 dirty。

对每个剩余 dirty path，判断它属于**当前 task**还是**其他并行工作**（例如另一个终端窗口正在编辑同一 repo）。启发式：

- 当前 task 的 `prd.md` / `implement.jsonl` / `check.jsonl` 中引用的 paths → current task
- 与 task 声明 scope 匹配的 code areas 中的 paths，或你记得本 session 编辑过的 paths → current task
- 无关 areas 中且你不记得本 session 触碰过的 paths → other parallel work

然后路由：

- **任何剩余 path 看起来像 current-task work** — 退出并说明：
  > "Working tree 中存在来自此 task 的未 commit 代码变更：`<list>`。请返回 workflow Phase 3.4，在运行 `/finish-work`（Trellis command）前提交它们。"

  不要在这里运行 `git commit`。不要提示用户自行 commit。用户回到 Phase 3.4，由 AI 在那里驱动 batched commit。
- **所有剩余 paths 看起来都无关**（其他并行窗口工作）— 报告一次并继续第 3 步：
  > "提示：存在此 task scope 之外的 dirty files — 为其他窗口保留：`<list>`。"
- **确实不确定** — 询问用户一次："`<list>` 是我忘记提交的当前 task 工作，还是另一个窗口的工作？（commit / ignore）" — 然后按其回答路由。

## 第 3 步：Archive task(s)

```bash
python3 ./.trellis/scripts/task.py archive <task-name>
```

至少：当前 active task（如有）。再加上用户在第 1 步确认的任何额外 tasks。每次 archive 都通过脚本 auto-commit 产生一个 `chore(task): archive ...` commit。

如果没有 active task 且用户未确认任何 cleanup archives，跳过此 step。

## 第 4 步：记录 session journal

```bash
python3 ./.trellis/scripts/add_session.py \
  --title "Session Title" \
  --commit "hash1,hash2" \
  --summary "Brief summary"
```

对 `--commit` 使用 Phase 3.4 产生的 work-commit hashes（可在第 1 步 `Recent commits` 列表中看到，或通过 `git log --oneline` 查看）。不要包含第 3 步的 archive commit hashes。这会产生一个 `chore: record journal` commit。

最终 git log 顺序：`<work commits from 3.4>` → `chore(task): archive ...`（一个或多个）→ `chore: record journal`。
