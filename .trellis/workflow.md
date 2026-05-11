# 开发工作流

---

## 核心原则

1. **先计划再编码** — 开始前先弄清楚要做什么
2. **通过 spec 注入，而不是靠记忆** — 指南由 hook/skill 注入，不从记忆中回忆
3. **一切持久化** — 研究、决策和经验都写入文件；对话会被压缩，文件不会
4. **增量开发** — 一次只做一个 task
5. **沉淀学习** — 每个 task 后复盘，并把新知识写回 spec

---

## Trellis 系统

### 开发者身份

首次使用时初始化你的身份：

```bash
python3 ./.trellis/scripts/init_developer.py <your-name>
```

创建 `.trellis/.developer`（gitignored）和 `.trellis/workspace/<your-name>/`。

### Spec 系统

`.trellis/spec/` 保存按 package 和 layer 组织的编码指南。

- `.trellis/spec/<package>/<layer>/index.md` — 入口文件，包含 **开发前检查清单** 和 **质量检查**。实际指南位于它指向的 `.md` 文件中。
- `.trellis/spec/guides/index.md` — 跨 package 的思考指南。

```bash
python3 ./.trellis/scripts/get_context.py --mode packages   # 列出 packages / layers
```

**何时更新 spec**：发现新 pattern/convention · 需要固化 bug-fix 预防措施 · 作出新技术决策。

### Task 系统

每个 task 都有自己的目录 `.trellis/tasks/{MM-DD-name}/`，其中保存 `task.json`、`prd.md`、可选的 `design.md`、可选的 `implement.md`、可选的 `research/`，以及供支持 sub-agent 的平台使用的 context manifests（`implement.jsonl`、`check.jsonl`）。

```bash
# Task 生命周期
python3 ./.trellis/scripts/task.py create "<title>" [--slug <name>] [--parent <dir>]
python3 ./.trellis/scripts/task.py start <name>          # 设置 active task（可用时按 session 作用域）
python3 ./.trellis/scripts/task.py current --source      # 显示 active task 和来源
python3 ./.trellis/scripts/task.py finish                # 清除 active task（触发 after_finish hooks）
python3 ./.trellis/scripts/task.py archive <name>        # 移动到 archive/{year-month}/
python3 ./.trellis/scripts/task.py list [--mine] [--status <s>]
python3 ./.trellis/scripts/task.py list-archive

# Code-spec context（通过 JSONL 注入 implement/check agents）。
# 对支持 sub-agent 的平台，`implement.jsonl` / `check.jsonl` 会在 `task create` 时生成种子行；
# AI 在 Phase 1.3 中整理真实 spec + research 条目。
python3 ./.trellis/scripts/task.py add-context <name> <action> <file> <reason>
python3 ./.trellis/scripts/task.py list-context <name> [action]
python3 ./.trellis/scripts/task.py validate <name>

# Task 元数据
python3 ./.trellis/scripts/task.py set-branch <name> <branch>
python3 ./.trellis/scripts/task.py set-base-branch <name> <branch>    # PR 目标
python3 ./.trellis/scripts/task.py set-scope <name> <scope>

# 层级（parent/child）
python3 ./.trellis/scripts/task.py add-subtask <parent> <child>
python3 ./.trellis/scripts/task.py remove-subtask <parent> <child>

# PR 创建
python3 ./.trellis/scripts/task.py create-pr [name] [--dry-run]
```

> 运行 `python3 ./.trellis/scripts/task.py --help` 查看权威的最新列表。

**Current-task 机制**：`task.py create` 创建 task 目录，并在 session identity 可用时自动设置 per-session active-task pointer，让 planning breadcrumb 立即触发。`task.py start` 写入同一个 pointer（如果已设置则幂等），并将 `task.json.status` 从 `planning` 切换到 `in_progress`。状态存储在 `.trellis/.runtime/sessions/` 下。如果 hook input、`TRELLIS_CONTEXT_ID` 或平台原生 session 环境变量都无法提供 context key，则没有 active task，`task.py start` 会带 session identity 提示失败。`task.py finish` 删除当前 session file（status 不变）。`task.py archive <task>` 写入 `status=completed`，将目录移动到 `archive/`，并删除任何仍指向已归档 task 的 runtime session files。

### Workspace 系统

在 `.trellis/workspace/<developer>/` 下记录每个 AI session，便于跨 session 跟踪。

- `journal-N.md` — session log。**每个文件最多 2000 行**；超过后自动创建新的 `journal-(N+1).md`。
- `index.md` — 个人索引（总 sessions、最后活跃时间）。

```bash
python3 ./.trellis/scripts/add_session.py --title "Title" --commit "hash" --summary "Summary"
```

### Context 脚本

```bash
python3 ./.trellis/scripts/get_context.py                            # 完整 session runtime
python3 ./.trellis/scripts/get_context.py --mode packages            # 可用 packages + spec layers
python3 ./.trellis/scripts/get_context.py --mode phase --step <X.Y>  # 某个 workflow step 的详细指南
```

---

<!--
  WORKFLOW-STATE BREADCRUMB CONTRACT（编辑下方 tag blocks 前先读）

  嵌入下方 ## 阶段索引 section 的 [workflow-state:STATUS] blocks，是每个受支持
  AI 平台 UserPromptSubmit hook 读取的每轮 `<workflow-state>` breadcrumb 的唯一事实来源。
  inject-workflow-state.py（Python 平台）和 inject-workflow-state.js（OpenCode plugin）
  只解析这些 blocks — v0.5.0-rc.0 之后，scripts 中不再内置 fallback dict。

  STATUS 字符集：[A-Za-z0-9_-]+。当 hook 找不到 tag 时，会降级为通用
  "Refer to workflow.md for current step." 行 — 这是有意保持可见的，
  方便用户注意并修复损坏的 workflow.md。

  INVARIANT（test/regression.test.ts）：
    每个标记为 `[required · once]` 的 workflow-walkthrough step，必须在
    其 phase 的 [workflow-state:*] block 中有匹配的 enforcement line。
    Breadcrumb 是唯一的每轮通道；如果 mandatory step 未在其中提及，AI 会
    静默跳过它（Phase 1.3 jsonl curation skip 和 Phase 3.4 commit skip
    都曾通过这个 gap 出现）。

  TAG ↔ PHASE 作用域：
    [workflow-state:no_task]      → 无 active task；Phase 1 之前
    [workflow-state:planning]     → 整个 Phase 1（status='planning'）
    [workflow-state:planning-inline] → Codex inline 的 Phase 1 变体
    [workflow-state:in_progress]  → Phase 2 + Phase 3.1-3.4
                                    （从 task.py start 到 task.py archive，status 一直是 'in_progress'）
    [workflow-state:in_progress-inline] → Codex inline 的 Phase 2/3 变体
    [workflow-state:completed]    → 当前 DEAD：cmd_archive 在同一次调用中切换 status 并移动目录，
                                    因此 resolver 会丢失 pointer（保留此 block 供未来显式
                                    in_progress→completed transition 使用）

  编辑检查清单：
    - 修改 [workflow-state:STATUS] block 时，也检查对应 phase 的
      `[required · once]` walkthrough steps 是否同步
    - 编辑后运行 `trellis update`，将新正文推送到 downstream user projects
      （block-level managed replacement）
    - 完整 runtime contract：
      .trellis/spec/cli/backend/workflow-state-contract.md
-->

## 阶段索引

```
Phase 1: Plan    → 明确要做什么（brainstorm + research → 中文 prd.md）
Phase 2: Execute → 编写代码并通过质量检查
Phase 3: Finish  → 提炼经验并收尾
```

### 请求分流

- 简单对话或小任务：只询问本轮是否需要创建 Trellis task。如果用户说不需要，本 session 跳过 Trellis。
- 复杂任务：询问是否可以创建 Trellis task 并进入 planning。如果用户说不，不要做大范围 inline 实现；改为解释、澄清 scope 或建议拆小。
- 用户批准创建 task 不等于批准开始实现。必须先完成 planning。

### Planning Artifacts（规划产物）

- `prd.md` — 需求、约束和验收标准。不要把技术设计或执行 checklist 放在这里。PRD 必须使用中文撰写；仅保留 commands、paths、placeholders、专有名词或用户原文中必须逐字保留的内容。
- `design.md` — 复杂 tasks 的技术设计：边界、contracts、data flow、tradeoffs、兼容性、rollout / rollback 形态。
- `implement.md` — 复杂 tasks 的执行计划：有序 checklist、验证命令、review gates 和 rollback points。
- `implement.jsonl` / `check.jsonl` — sub-agent context 使用的 spec 和 research manifests。它们不能替代 `implement.md`。
- 轻量 tasks 可以只有 PRD。复杂 tasks 必须在 `task.py start` 前具备 `prd.md`、`design.md` 和 `implement.md`。

<!-- 每轮 breadcrumb：无 active task 时显示（Phase 1 前） -->

[workflow-state:no_task]
没有 active task。**A 直接回答** — 纯 Q&A / 解释 / 查询 / 聊天；不写文件 + 单行回答 + repo 读取 ≤ 2 个文件 → AI 自行判断，无需 override。
**B 创建 task** — 任何实现 / 代码变更 / 构建 / 重构工作。进入顺序：(1) `python3 ./.trellis/scripts/task.py create "<title>"` 创建 task（status=planning，breadcrumb 切换到 [workflow-state:planning] 以提供 brainstorm + jsonl 阶段指导）→ (2) 加载 `trellis-brainstorm` skill，与用户讨论需求并用中文迭代 prd.md → (3) prd 完成且 jsonl 整理好后，运行 `task.py start <task-dir>` 进入 [workflow-state:in_progress] 实现骨架。**“看起来很小”不是把 B 降级为 A 或 C 的理由**。
**C Inline change**（仅当前轮，B 的逃生口）— 用户当前消息必须包含以下之一："skip trellis" / "no task" / "just do it" / "don't create a task" / "跳过 trellis" / "别走流程" / "小修一下" / "直接改" / "先别建任务" → 简短确认（"ok, skipping trellis flow this turn"），然后 inline。**没看到这些短语之一时，不得自行 inline**；不要编造用户从未说过的 override。
[/workflow-state:no_task]

### Phase 1: Plan
- 1.0 创建 task `[required · once]`（只运行 `task.py create`；status 进入 planning）
- 1.1 需求探索 `[required · repeatable]`（`prd.md`；复杂 tasks 还需要 `design.md` + `implement.md`）
- 1.2 Research `[optional · repeatable]`
- 1.3 配置 context `[conditional · once]` — Claude Code, Cursor, OpenCode, Codex, Kiro, Gemini, Qoder, CodeBuddy, Copilot, Droid, Pi
- 1.4 激活 task `[required · once]`（review gate，然后运行 `task.py start`；status → in_progress）
- 1.5 完成标准

<!-- 每轮 breadcrumb：Phase 1 期间显示（status='planning'） -->

[workflow-state:planning]
加载 `trellis-brainstorm` skill，并与用户用中文迭代 prd.md。
轻量 task：`prd.md` 可以足够。复杂 task：完成 `prd.md`、`design.md` 和 `implement.md`，并在 `task.py start` 前请求 review。Sub-agent mode：start 前整理 `implement.jsonl` 和 `check.jsonl` 作为 spec/research manifests。
然后运行 `task.py start <task-dir>` 将 status 切换为 in_progress。
[/workflow-state:planning]

<!-- 每轮 breadcrumb：codex.dispatch_mode=inline 时在 Phase 1 期间显示。
     Codex-only opt-in 作为 [workflow-state:planning] 的替代。main agent
     会在 Phase 2 直接编辑代码，因此跳过 jsonl curation —
     inline workflow 加载 `trellis-before-dev`，而不是向 sub-agent 注入 JSONL。 -->

[workflow-state:planning-inline]
加载 `trellis-brainstorm` skill，并与用户用中文迭代 prd.md。
轻量 task：`prd.md` 可以足够。复杂 task：完成 `prd.md`、`design.md` 和 `implement.md`，并在 `task.py start` 前请求 review。Inline mode：跳过 jsonl curation；Phase 2 通过 `trellis-before-dev` 读取 artifacts/specs。
然后运行 `task.py start <task-dir>` 将 status 切换为 in_progress。
[/workflow-state:planning-inline]

### Phase 2: Execute
- 2.1 实现 `[required · repeatable]`
- 2.2 质量检查 `[required · repeatable]`
- 2.3 回滚 `[on demand]`

<!-- 每轮 breadcrumb：status='in_progress' 时显示。
     范围：整个 Phase 2 + Phase 3.1-3.4（从 task.py start 到 task.py archive，
     status 都保持 'in_progress'；只有 archive 会切换它）。因此正文必须覆盖
     从实现到 commit 的所有 required step，包括 Phase 3.3 spec update 和 Phase 3.4 commit。 -->

Sub-agent dispatch protocol 适用于所有平台和所有 sub-agents，包括 class-2 Codex/Copilot/Gemini/Qoder 以及 `trellis-research`：每个 dispatch prompt 都必须在角色专属说明前，以 `Active task: <task path from task.py current>` 开头。

[workflow-state:in_progress]
Flow：`trellis-implement` -> `trellis-check` -> `trellis-update-spec` -> commit (Phase 3.4) -> `/trellis:finish-work`。
Main-session default：dispatch implement/check sub-agents。Sub-agent 自豁免：如果已经作为 `trellis-implement` 运行，不要 spawn 另一个 `trellis-implement` 或 `trellis-check`；如果已经作为 `trellis-check` 运行，不要 spawn 另一个 `trellis-check` 或 `trellis-implement`。Dispatch 只能由 main session 执行。
Dispatch prompt 以 `Active task: <task path from task.py current>` 开头。读取 context 的顺序：jsonl entries -> `prd.md` -> `design.md if present` -> `implement.md if present`。
[/workflow-state:in_progress]

<!-- 每轮 breadcrumb：codex.dispatch_mode=inline 且 status='in_progress' 时显示。
     Codex-only opt-in 作为 [workflow-state:in_progress] 的替代。
     main session 直接编辑代码，而不是 dispatch sub-agents。 -->

[workflow-state:in_progress-inline]
**Flow**（inline mode）：main session 加载 `trellis-before-dev` → main session 编辑代码 → main session 加载 `trellis-check` → 运行 lint / type-check / tests → fix → `trellis-update-spec` → commit (Phase 3.4) → `/trellis:finish-work`。
**Main-session default（inline dispatch_mode）**：main agent 直接编辑代码。不要 dispatch `trellis-implement` / `trellis-check` sub-agents。写代码前加载 `trellis-before-dev` skill；报告完成前加载 `trellis-check` skill。
Phase 3.4 commit（required, once）：在 `trellis-update-spec` 后，或实现已可验证完成时，main agent **负责驱动 commit** — 先用面向用户的文字说明 commit plan，再运行 `git commit` — 然后才建议 `/trellis:finish-work`。`/finish-work` 会拒绝在 dirty working tree 上运行（`.trellis/workspace/` 和 `.trellis/tasks/` 之外的路径）。
[/workflow-state:in_progress-inline]

### Phase 3: Finish
- 3.1 质量验证 `[required · repeatable]`
- 3.2 Debug 复盘 `[on demand]`
- 3.3 Spec 更新 `[required · once]`
- 3.4 Commit changes `[required · once]`
- 3.5 收尾提醒

<!-- 每轮 breadcrumb：status='completed' 时显示。
     当前在正常流程中是 DEAD：cmd_archive 在移动 task dir 到 archive/ 的同一次调用中
     写入 status='completed'，因此 active-task resolver 会丢失 pointer，hook 不会在
     archived tasks 上触发。保留该 block 供未来 status-transition 重新设计使用（例如显式
     in_progress→completed command）。通过与 live blocks 相同的 spec channel 编辑。 -->

[workflow-state:completed]
代码已 committed。运行 `/trellis:finish-work`；如果 working tree 仍 dirty，先返回 Phase 3.4。
[/workflow-state:completed]

### 规则

1. 识别当前处于哪个 Phase，然后从该 Phase 的下一步继续
2. 在每个 Phase 内按顺序运行 steps；`[required]` steps 不能跳过
3. Phases 可以回滚（例如 Execute 发现 prd 缺陷 → 返回 Plan 修复，再重新进入 Execute）
4. 标记为 `[once]` 的 steps 如果输出已存在则跳过；不要重复运行
5. Artifact 是否存在会决定下一步；缺少 `design.md` / `implement.md` 对轻量 tasks 是有效状态，对复杂 tasks 则表示 planning 未完成。

### Skill 路由

当用户请求匹配以下 intent 之一时，先加载对应 skill（或 dispatch 对应 sub-agent）— 不要跳过 skills。

[Claude Code, Cursor, OpenCode, codex-sub-agent, Kiro, Gemini, Qoder, CodeBuddy, Copilot, Droid, Pi]

- Planning 或需求不清晰 -> `trellis-brainstorm`。
- `in_progress` implementation/check -> dispatch `trellis-implement` / `trellis-check`。
- 重复 debugging -> `trellis-break-loop`；spec updates -> `trellis-update-spec`。

[/Claude Code, Cursor, OpenCode, codex-sub-agent, Kiro, Gemini, Qoder, CodeBuddy, Copilot, Droid, Pi]

[codex-inline, Kilo, Antigravity, Windsurf]

- Planning 或需求不清晰 -> `trellis-brainstorm`。
- 编辑前 -> `trellis-before-dev`；编辑后 -> `trellis-check`。
- 重复 debugging -> `trellis-break-loop`；spec updates -> `trellis-update-spec`。

[/codex-inline, Kilo, Antigravity, Windsurf]

### 不要跳过 skills

- 批准创建 task 不等于批准 implementation；implementation 必须等 artifact review 后运行 `task.py start`。
- PRD-only 对轻量 tasks 有效；复杂 tasks 需要 `design.md` + `implement.md`。
- Planning 必须持久化到 task artifacts；报告完成前必须运行 checks。

### 加载 Step 详情

每一步运行此命令获取详细指南：

```bash
python3 ./.trellis/scripts/get_context.py --mode phase --step <step>
# e.g. python3 ./.trellis/scripts/get_context.py --mode phase --step 1.1
```

---

## Phase 1: Plan

目标：弄清楚要构建什么，产出清晰的中文需求文档和实现所需 context。

#### 1.0 创建 task `[required · once]`

创建 task 目录（status 进入 `planning`；当 session identity 可用时，session active-task pointer 自动指向新 task）：

```bash
python3 ./.trellis/scripts/task.py create "<task title>" --slug <name>
```

`--slug` 只是人类可读名称。**不要**包含 `MM-DD-` 日期前缀；`task.py create` 会自动添加该前缀。

此命令成功后，每轮 breadcrumb 自动切换到 `[workflow-state:planning]`，提示 AI 进入 brainstorm + jsonl curation 阶段。

⚠️ **这里只运行 `create` — 不要同时运行 `start`**。`start` 会把 status 切到 `in_progress`，导致 breadcrumb 在 brainstorm + jsonl 完成前切到实现阶段 — AI 会悄悄跳过它们。把 `start` 留到 step 1.4，在 jsonl curation 完成后再运行。

当 `python3 ./.trellis/scripts/task.py current --source` 已经指向一个 task 时跳过。

#### 1.1 需求探索 `[required · repeatable]`

加载 `trellis-brainstorm` skill，并按该 skill 指南与用户交互式探索需求。

brainstorm skill 会指导你：
- 一次只问一个问题
- 优先研究，而不是询问用户
- 优先提供选项，而不是开放式提问
- 每次用户回答后立即用中文更新 `prd.md`
- 保持 `prd.md` 聚焦 requirements 和 acceptance criteria
- 对复杂 tasks，在 implementation 开始前产出 `design.md` 和 `implement.md`

每当需求变化时，返回此 step 并用中文修订 `prd.md`。

#### 1.2 Research `[optional · repeatable]`

Research 可以在需求探索期间随时发生。它不限于本地代码 — 你可以使用任何可用工具（MCP servers、skills、web search 等）查找外部信息，包括第三方库文档、行业实践、API references 等。

[Claude Code, Cursor, OpenCode, codex-sub-agent, Kiro, Gemini, Qoder, CodeBuddy, Copilot, Droid, Pi]

Spawn research sub-agent：

- **Agent type**：`trellis-research`
- **Task description**：Research <specific question>
- **Key requirement**：Research output 必须持久化到 `{TASK_DIR}/research/`

[/Claude Code, Cursor, OpenCode, codex-sub-agent, Kiro, Gemini, Qoder, CodeBuddy, Copilot, Droid, Pi]

[codex-inline, Kilo, Antigravity, Windsurf]

在 main session 中直接做 research，并把 findings 写入 `{TASK_DIR}/research/`。（对 `codex-inline`，这避免了 `fork_turns="none"` 隔离导致 `trellis-research` sub-agents 无法解析 active task path。）

[/codex-inline, Kilo, Antigravity, Windsurf]

**Research artifact 约定**：
- 每个 research topic 一个文件（例如 `research/auth-library-comparison.md`）
- 在文件中记录第三方库 usage examples、API references、version constraints
- 记录你发现的相关 spec file paths，供后续参考

Brainstorm 和 research 可以自由交错 — 暂停去研究技术问题，然后回到与用户讨论。

**关键原则**：Research output 必须写入文件，不能只留在聊天中。对话会被压缩；文件不会。

#### 1.3 配置 context `[conditional · once]`

[Claude Code, Cursor, OpenCode, codex-sub-agent, Kiro, Gemini, Qoder, CodeBuddy, Copilot, Droid, Pi]

整理 `implement.jsonl` 和 `check.jsonl`，使 Phase 2 sub-agents 获得正确 spec context。这些文件在 `task create` 时已带一个自描述 `_example` 种子行；你在这里的工作是填入真实条目。

**位置**：`{TASK_DIR}/implement.jsonl` 和 `{TASK_DIR}/check.jsonl`（已存在）。

**格式**：每行一个 JSON object — `{"file": "<path>", "reason": "<why>"}`。路径相对于 repo root。

**应放入内容**：
- **Spec files** — `.trellis/spec/<package>/<layer>/index.md` 以及与此 task 相关的任何具体 guideline files（`error-handling.md`、`conventions.md` 等）
- **Research files** — sub-agent 需要查阅的 `{TASK_DIR}/research/*.md`

**不要放入内容**：
- Code files（`src/**`、`packages/**/*.ts` 等）— 这些由 sub-agent 在实现期间读取，不在这里预注册
- 你即将修改的文件 — 原因相同

**两个文件的分工**：
- `implement.jsonl` → implement sub-agent 正确写代码所需的 specs + research
- `check.jsonl` → check sub-agent 所需 specs（quality guidelines、check conventions，必要时包含同样 research）

这些 manifests 不能替代 `implement.md`。`implement.md` 是复杂 task 的人类可读执行计划；jsonl files 只列出要注入或加载的 context files。

**如何发现相关 specs**：

```bash
python3 ./.trellis/scripts/get_context.py --mode packages
```

列出每个 package 及其 spec layers 和路径。选择与此 task 领域匹配的条目。

**如何追加条目**：

可以直接在编辑器中编辑 jsonl 文件，或使用：

```bash
python3 ./.trellis/scripts/task.py add-context "$TASK_DIR" implement "<path>" "<reason>"
python3 ./.trellis/scripts/task.py add-context "$TASK_DIR" check "<path>" "<reason>"
```

真实条目存在后删除种子 `_example` 行（可选 — consumers 会自动跳过它）。

跳过条件：`implement.jsonl` 和 `check.jsonl` 都已有 agent-curated 条目（仅有种子 `_example` 行不算）。

[/Claude Code, Cursor, OpenCode, codex-sub-agent, Kiro, Gemini, Qoder, CodeBuddy, Copilot, Droid, Pi]

[codex-inline, Kilo, Antigravity, Windsurf]

跳过此 step。Context 会在 Phase 2 由 `trellis-before-dev` skill 直接加载。

[/codex-inline, Kilo, Antigravity, Windsurf]

#### 1.4 激活 task `[required · once]`

Artifact review 通过后，将 task status 切换为 `in_progress`：

```bash
python3 ./.trellis/scripts/task.py start <task-dir>
```

轻量 tasks 可以只有 `prd.md`。复杂 tasks 必须在 start 前存在并 review `prd.md`、`design.md` 和 `implement.md`。在支持 sub-agent 的平台上，当需要额外 spec 或 research context 时整理 jsonl manifests；consumers 可容忍仅有种子行的 manifests。

此命令成功后，breadcrumb 自动切换为 `[workflow-state:in_progress]`，随后进入 Phase 2 / 3 的其余流程。

如果 `task.py start` 报 session-identity 相关错误（hook input、`TRELLIS_CONTEXT_ID` 或平台原生 session env 没有 context key），按错误提示设置 session identity，然后重试。

#### 1.5 Completion criteria

| 条件 | 必需 |
|------|:---:|
| `prd.md` 存在 | ✅ |
| 用户确认 task 应进入 implementation | ✅ |
| 已运行 `task.py start`（status = in_progress） | ✅ |
| `research/` 有 artifacts（复杂 tasks） | 推荐 |
| `design.md` 存在（复杂 tasks） | ✅ |
| `implement.md` 存在（复杂 tasks） | ✅ |

[Claude Code, Cursor, OpenCode, codex-sub-agent, Kiro, Gemini, Qoder, CodeBuddy, Copilot, Droid, Pi]

| 需要额外 spec 或 research context 时已整理 `implement.jsonl` / `check.jsonl` | 推荐 |

[/Claude Code, Cursor, OpenCode, codex-sub-agent, Kiro, Gemini, Qoder, CodeBuddy, Copilot, Droid, Pi]

---

## Phase 2: Execute

目标：将 prd 转化为通过质量检查的代码。

#### 2.1 实现 `[required · repeatable]`

[Claude Code, Cursor, OpenCode, Gemini, Qoder, CodeBuddy, Copilot, Droid, Pi]

Spawn implement sub-agent：

- **Agent type**：`trellis-implement`
- **Task description**：实现已 review 的 task artifacts，查阅 `{TASK_DIR}/research/` 下材料；最后运行项目 lint 和 type-check
- **Dispatch prompt guard**：告诉被 spawn 的 agent 它已经是 `trellis-implement` sub-agent，必须直接实现，不要 spawn 另一个 `trellis-implement` / `trellis-check`。

平台 hook/plugin 自动处理：
- 读取 `implement.jsonl`，并将引用的 spec files 注入 agent prompt
- 注入 `prd.md`、存在时的 `design.md` 和存在时的 `implement.md`

[/Claude Code, Cursor, OpenCode, Gemini, Qoder, CodeBuddy, Copilot, Droid, Pi]

[codex-sub-agent]

Spawn implement sub-agent：

- **Agent type**：`trellis-implement`
- **Task description**：实现已 review 的 task artifacts，查阅 `{TASK_DIR}/research/` 下材料；最后运行项目 lint 和 type-check
- **Dispatch prompt guard**：prompt 必须以 `Active task: <task path>` 开头，然后明确说明被 spawn 的 agent 已经是 `trellis-implement`，必须直接实现，不要 spawn 另一个 `trellis-implement` / `trellis-check`。

Codex sub-agent 定义会自动处理 context load 要求：
- 用 `task.py current --source` 解析 active task，然后读取 `prd.md`、存在时的 `design.md` 和存在时的 `implement.md`
- 读取 `implement.jsonl`，并要求 agent 在编码前加载每个引用的 spec/research file

[/codex-sub-agent]

[Kiro]

Spawn implement sub-agent：

- **Agent type**：`trellis-implement`
- **Task description**：实现已 review 的 task artifacts，查阅 `{TASK_DIR}/research/` 下材料；最后运行项目 lint 和 type-check
- **Dispatch prompt guard**：告诉被 spawn 的 agent 它已经是 `trellis-implement` sub-agent，必须直接实现，不要 spawn 另一个 `trellis-implement` / `trellis-check`。

平台 prelude 自动处理 context load 要求：
- 读取 `implement.jsonl`，并将引用的 spec files 注入 agent prompt
- 注入 `prd.md`、存在时的 `design.md` 和存在时的 `implement.md`

[/Kiro]

[codex-inline, Kilo, Antigravity, Windsurf]

1. 加载 `trellis-before-dev` skill 读取项目指南
2. 读取 `{TASK_DIR}/prd.md`，然后读取存在时的 `design.md`，再读取存在时的 `implement.md`
3. 查阅 `{TASK_DIR}/research/` 下材料
4. 按需求实现代码
5. 运行项目 lint 和 type-check

[/codex-inline, Kilo, Antigravity, Windsurf]

#### 2.2 质量检查 `[required · repeatable]`

[Claude Code, Cursor, OpenCode, codex-sub-agent, Kiro, Gemini, Qoder, CodeBuddy, Copilot, Droid, Pi]

Spawn check sub-agent：

- **Agent type**：`trellis-check`
- **Task description**：根据 spec 和 prd review 所有 code changes；直接修复任何 findings；确保 lint 和 type-check 通过
- **Dispatch prompt guard**：告诉被 spawn 的 agent 它已经是 `trellis-check` sub-agent，必须直接 review/fix，不要 spawn 另一个 `trellis-check` / `trellis-implement`。

check agent 的职责：
- 根据 specs review code changes
- 根据 `prd.md`、存在时的 `design.md` 和存在时的 `implement.md` review code changes
- 自动修复它发现的问题
- 运行 lint 和 typecheck 验证

[/Claude Code, Cursor, OpenCode, codex-sub-agent, Kiro, Gemini, Qoder, CodeBuddy, Copilot, Droid, Pi]

[codex-inline, Kilo, Antigravity, Windsurf]

加载 `trellis-check` skill，并按其指南验证代码：
- Spec compliance
- lint / type-check / tests
- Cross-layer consistency（当变更跨 layers 时）

如果发现问题 → 修复 → 重新检查，直到 green。

[/codex-inline, Kilo, Antigravity, Windsurf]

#### 2.3 回滚 `[on demand]`

- `check` 暴露 prd 缺陷 → 返回 Phase 1，修复 `prd.md`，然后重做 2.1
- 实现走偏 → revert code，重做 2.1
- 需要更多 research → research（同 Phase 1.2），将 findings 写入 `research/`

---

## Phase 3: Finish

目标：确保代码质量，捕获经验，记录工作。

#### 3.1 质量验证 `[required · repeatable]`

加载 `trellis-check` skill 并进行最终验证：
- Spec compliance
- lint / type-check / tests
- Cross-layer consistency（当变更跨 layers 时）

如果发现问题 → 修复 → 重新检查，直到 green。

#### 3.2 Debug 复盘 `[on demand]`

如果此 task 涉及重复调试（同一问题被修复多次），加载 `trellis-break-loop` skill 来：
- 分类 root cause
- 解释早期 fixes 为什么失败
- 提出预防措施

目标是捕获调试经验，让同类问题不再重复发生。

#### 3.3 Spec 更新 `[required · once]`

加载 `trellis-update-spec` skill，并审查此 task 是否产生值得记录的新知识：
- 新发现的 patterns 或 conventions
- 遇到的 pitfalls
- 新技术决策

据此更新 `.trellis/spec/` 下文档。即使结论是“无需更新”，也要完成判断过程。

#### 3.4 Commit changes `[required · once]`

AI 驱动此 task 代码变更的批量 commit，使 `/finish-work` 后续能干净运行。目标：先产出 work commits，然后再落地 bookkeeping（archive + journal）commits — 永不交错。

**步骤**：

1. **检查 dirty state**：
   ```bash
   git status --porcelain
   ```
   快照每个 dirty path。如果 working tree 干净，跳到 3.5。

2. 从 recent history **学习 commit style**（让草拟 messages 融入项目风格）：
   ```bash
   git log --oneline -5
   ```
   注意 prefix convention（`feat:` / `fix:` / `chore:` / `docs:` ...）、语言（中文/English）和长度风格。

3. **将 dirty files 分成两组**：
   - **AI 本 session 编辑** — 本 session 中你通过 Edit/Write/Bash tool calls 写入/编辑的文件。你知道变更了什么和为什么。
   - **未识别** — 本 session 中你未触碰的 dirty files（可能是用户手动编辑、上一 session 遗留 WIP 或无关工作）。不要静默包含这些文件。

4. **草拟 commit plan**。将 AI-edited files 组合为逻辑 commits（每个连贯变更单元一个 commit，而不是每个文件一个 commit）。每项包含：`<commit message>` + file list。未识别文件单独列在底部。

5. **只展示一次 plan，并请求一次性确认**。格式：
   ```
   Proposed commits (in order):
     1. <message>
        - <file>
        - <file>
     2. <message>
        - <file>

   Unrecognized dirty files (NOT in any commit — confirm include/exclude):
     - <file>
     - <file>

   Reply 'ok' / '行' to execute. Reply with edits, or '我自己来' / 'manual' to abort.
   ```

6. **确认后**：按顺序对每个 batch 运行 `git add <files>` + `git commit -m "<msg>"`。不要 amend。不要 push。

7. **拒绝时**（用户回复“ 不行” / “我自己来” / "manual" / 对 plan 有任何异议）：停止。不要尝试第二个 plan。用户会手动 commit；他们确认后你跳到 3.5。

**规则**：
- 任何地方都不要 `git commit --amend` — 三阶段三 commit 流（work commits → archive commit → journal commit）。
- 此 step 绝不 push 到 remote。
- 如果用户想改 message wording 但接受文件分组，修改 message 并重新确认一次 — 但如果他们拒绝分组，退出到 manual mode。
- 批量 plan 是一次提示；不要每个 commit 都提示。

#### 3.5 收尾提醒

完成上述步骤后，提醒用户可以运行 `/finish-work` 收尾（archive task，record session）。

---

## 自定义 Trellis（适用于 forks）

本节面向想修改 Trellis workflow 本身的开发者。所有自定义都通过编辑此文件完成；scripts 只负责解析。

### 修改某个 step 的含义

编辑上方 Phase 1 / 2 / 3 sections 中对应 step 的 walkthrough 正文。关键不变量：
- 无 active task 时必须先 triage，并在创建 Trellis task 前询问 task-creation consent。
- Planning 必须区分轻量 PRD-only tasks 与开始前需要 `prd.md`、`design.md` 和 `implement.md` 的复杂 tasks。
- 每条 required execution path 都必须让 Phase 3.4 commit reminder 在 `/trellis:finish-work` 前可达。

全部 4 个 tag blocks 都位于上方 `## 阶段索引` section 中，紧跟每个 phase summary 之后：

| 范围 | 对应 tag |
|---|---|
| 无 active task（Phase 1 前） | `[workflow-state:no_task]`（在 Phase Index ASCII art 后） |
| 整个 Phase 1（task created → ready for implementation） | `[workflow-state:planning]`（在 Phase 1 summary 后） |
| Codex inline Phase 1 | `[workflow-state:planning-inline]` |
| Phase 2 + Phase 3.1–3.4（implementation + check + wrap-up） | `[workflow-state:in_progress]`（在 Phase 2 summary 后） |
| Codex inline Phase 2 + Phase 3.1–3.4 | `[workflow-state:in_progress-inline]` |
| Phase 3.5 后（archived） | `[workflow-state:completed]`（在 Phase 3 summary 后；**当前 DEAD**） |

### 修改每轮 prompt 文本

直接编辑对应 `[workflow-state:STATUS]` block 的正文。编辑后运行 `trellis update`（如果你是 template maintainer），或重启 AI session（如果你在自定义自己的项目）— 不需要修改 scripts。

### 添加自定义 status

添加新 block：

```
[workflow-state:my-status]
your per-turn prompt text
[/workflow-state:my-status]
```

约束：
- STATUS 字符集：`[A-Za-z0-9_-]+`（允许 underscores 和 hyphens，例如 `in-review`、`blocked-by-team`）
- lifecycle hook 必须把 `task.json.status` 写为你的自定义值，否则该 tag 永远不会被读取
- lifecycle hooks 位于 `task.json.hooks.after_*`，并绑定到 `after_create / after_start / after_finish / after_archive` 之一

### 添加 lifecycle hook

向你的 `task.json` 添加 `hooks` 字段：

```json
{
  "hooks": {
    "after_finish": [
      "your-script-or-command-here"
    ]
  }
}
```

支持的 events：`after_create / after_start / after_finish / after_archive`。注意 `after_finish` ≠ status change（它只清除 active-task pointer）；“task is done” 通知请使用 `after_archive`。

### 完整契约

关于 workflow state machine 的 runtime contract、所有 status writers 的位置、pseudo-statuses（`no_task` / `stale_<source_type>`）、hook reachability matrix 和其他深入细节，见：

- `.trellis/spec/cli/backend/workflow-state-contract.md` — runtime contract + writer table + test invariants
- `.trellis/scripts/inject-workflow-state.py` — 实际 parser（只读取 workflow.md，没有嵌入文本）
