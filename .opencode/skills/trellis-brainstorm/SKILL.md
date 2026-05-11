---
name: trellis-brainstorm
description: "实现前引导协作式需求发现。创建 task 目录、初始化 PRD、一次提出一个高价值问题、研究技术选择，并收敛到 MVP scope。当需求不清晰、存在多种有效方案，或用户描述新功能/复杂 task 时使用。"
---

# Brainstorm - 需求发现（AI Coding 增强）

**CoreRule**：持续追问此计划的每个方面，直到我们达成共同理解。沿着 design tree 的每个分支推进，逐一解决决策之间的依赖。对每个问题，都提供你的推荐答案。

一次只问一个问题。

如果某个问题可以通过探索 codebase 回答，就改为探索 codebase。

---

在**实现前**引导 AI 进行协作式需求发现，并针对 AI coding workflows 优化：

* **Task-first**（立即捕获想法）
* **Action-before-asking**（减少低价值问题）
* 技术选择 **Research-first**（避免要求用户发明选项）
* **Diverge → Converge**（扩展思考，然后锁定 MVP）

---

## 使用时机

当用户描述开发 task 时，由 `start`（Trellis command）触发，尤其适用于：

* requirements 不清晰或仍在演化
* 存在多条有效 implementation paths
* 需要权衡（UX、reliability、maintainability、cost、performance）
* 用户可能一开始不知道最佳选项

---

## 核心原则（不可协商）

1. **Task-first（尽早捕获）**
   始终确保一开始就有 task，以便立即记录用户想法。

2. **先行动再提问**
   如果你能从 repo code、docs、configs、conventions 或快速 research 推导答案 — 先做。

3. **每条消息一个问题**
   不要用一串问题压垮用户。问一个、更新 PRD、重复。

4. **偏好具体选项**
   对 preference/decision 问题，提供 2–3 个可行、具体且带 trade-offs 的方案。

5. **技术选择 Research-first**
   如果决策依赖行业 conventions / 相似工具 / established patterns，先 research，再提出选项。

6. **Diverge → Converge**
   初步理解后，主动考虑未来演进、相关场景和 failure/edge cases — 然后收敛到有明确 out-of-scope 的 MVP。

7. **不要问 meta questions**
   不要问“我要搜索吗？”或“你能贴代码让我继续吗？”
   如果需要信息：search/inspect。如果被阻塞：问最小阻塞问题。

---

## 第 0 步：确保 Task 存在（始终）

任何 Q&A 前，确保 task 存在。如果没有，立即创建一个。

* 使用从用户消息派生的**临时工作标题**。
* 标题不完美没关系 — 稍后在 PRD 中细化。

```bash
TASK_DIR=$(python3 ./.trellis/scripts/task.py create "brainstorm: <short goal>" --slug <auto>)
```

使用不带日期前缀的 slug。`task.py create` 会自动添加 `MM-DD-`
目录前缀。

立即用已知内容创建/初始化 `prd.md`。本项目中的 PRD 必须使用中文撰写；仅保留 commands、paths、placeholders、专有名词或用户原文中必须逐字保留的内容。

```markdown
# brainstorm: <short goal>

## 目标

<一段话：做什么 + 为什么>

## 已知信息

* <来自用户消息的事实>
* <从 repo/docs 发现的事实>

## 临时假设

* <需要验证的假设>

## 待确认问题

* <仅保留阻塞性 / 偏好类问题；列表保持简短>

## 需求（迭代中）

* <从已知内容开始>

## 验收标准（迭代中）

* [ ] <可测试标准>

## 完成定义（团队质量门槛）

* 已添加/更新 tests（适用时包括 unit/integration）
* Lint / typecheck / CI 通过
* 行为变化时已更新 docs/notes
* 风险较高时已考虑 rollout/rollback

## 不在范围内（明确）

* <本 task 不会做什么>

## 技术备注

* <已检查文件、约束、links、references>
* <适用时填写 research notes 摘要>
```

---

## 第 1 步：Auto-Context（提问前先做）

在问“代码长什么样？”这类问题前，自行收集 context：

### Repo 检查清单

* 识别可能受影响的 modules/files
* 定位现有 patterns（相似 features、conventions、error handling style）
* 检查 configs、scripts、现有 command definitions
* 记录任何约束（runtime、dependency policy、build tooling）

### 文档检查清单

* 查找 existing PRDs/specs/templates
* 查找 command usage examples、README、ADRs（如有）

将 findings 写入中文 PRD：

* 添加到 `已知信息`
* 将 constraints/links 添加到 `技术备注`

---

## 第 2 步：分类复杂度（仍有用，但不作为 task 创建门槛）

| 复杂度   | 标准                                               | 动作                                      |
| ------------ | ------------------------------------------------------ | ------------------------------------------- |
| **Trivial**  | 单行修复、typo、明显变更                  | 跳过 brainstorm，直接实现         |
| **Simple**   | 目标清晰、1–2 个文件、scope 明确              | 问 1 个确认问题，然后实现      |
| **Moderate** | 多个文件，有一些歧义                         | 轻量 brainstorm（2–3 个高价值问题） |
| **Complex**  | 目标模糊、架构选择、多种方案 | 完整 brainstorm                             |

> 注意：Task 已在第 0 步存在。分类只影响 brainstorming 深度。

---

## 第 3 步：问题门禁（只问高价值问题）

在提出任何问题前，先通过以下门禁：

### 门禁 A — 我能否不问用户而推导出来？

如果答案可通过以下方式获得：

* repo inspection（code/config）
* docs/specs/conventions
* 快速 market/OSS research

→ **不要问。** 获取它、总结它、更新 PRD。

### 门禁 B — 这是 meta/lazy question 吗？

示例：

* "Should I search?"
* "Can you paste the code so I can proceed?"
* "What does the code look like?" (when repo is available)

→ **不要问。** 采取行动。

### 门禁 C — 这是什么类型的问题？

* **Blocking**：没有用户输入无法继续
* **Preference**：存在多个有效选择，取决于 product/UX/risk 偏好
* **Derivable**：应通过 inspection/research 回答

→ 只询问 **Blocking** 或 **Preference**。

---

## 第 4 步：Research-first 模式（技术选择时强制）

### 触发条件（任一满足 → research-first）

* task 涉及选择 approach、library、protocol、framework、template system、plugin mechanism 或 CLI UX convention
* 用户询问 “best practice”、“how others do it”、“recommendation”
* 用户无法合理枚举选项

### 委托给 `trellis-research` sub-agent（不要 inline research）

对每个 research topic，**通过 Task tool spawn 一个 `trellis-research` sub-agent** — 不要在主对话中 inline 执行 WebFetch / WebSearch / `gh api`。

原因：
- sub-agent 有自己的 context window → 不会用原始 tool output 污染 brainstorm context
- 它会将 findings 持久化到 `{TASK_DIR}/research/<topic>.md`（契约 — 见 `workflow.md` Phase 1.2）
- 它只向 main agent 返回 `{file path, one-line summary}`
- 独立 topics 可以**并行化** — 在一次 tool call 中 spawn 多个 sub-agents

> **Codex exception**：在 Codex CLI 上，不要为 research-first mode dispatch `trellis-research` — 直接 inline 做 research（main session 中的 WebFetch / WebSearch），并自行将 findings 写入 `{TASK_DIR}/research/<topic>.md`。原因：Codex `spawn_agent` 以 `fork_turns="none"` 运行 sub-agents（隔离 context，无 parent session inheritance），因此 research sub-agent 无法通过 `task.py current` 解析 active task path，会静默中止且不产出文件。Codex 上 inline research 可避免此失败模式。专门为 Codex 放宽 `workflow.md` 中 3+ inline research calls limit（B 规则）。

Agent type：`trellis-research`
Task description template："Research <specific question>; persist findings to `{TASK_DIR}/research/<topic-slug>.md`."

❌ Bad (what you must NOT do):
```
Main agent: WebFetch(url-A) → WebFetch(url-B) → Bash(gh api ...)
          → WebSearch(q1) → WebSearch(q2) → ... (10+ inline calls)
          → Write(research/topic.md)
```
→ 用原始 HTML/JSON 污染 main context，消耗 tokens。

✅ Good:
```
Main agent: Task(subagent_type="trellis-research",
                 prompt="Research topic A; persist to research/topic-a.md")
          + Task(subagent_type="trellis-research",
                 prompt="Research topic B; persist to research/topic-b.md")
          + Task(subagent_type="trellis-research",
                 prompt="Research topic C; persist to research/topic-c.md")
→ Reads research/topic-{a,b,c}.md after they finish.
```

### Research steps（传入每个 sub-agent prompt）

每个 `trellis-research` sub-agent 应：

1. 为其 topic 识别 2–4 个可比较 tools/patterns
2. 总结 common conventions 及其存在原因
3. 将 conventions 映射到我们的 repo constraints
4. 将 findings 写入 `{TASK_DIR}/research/<topic>.md`

Main agent 随后读取持久化文件，并在 PRD 中产出 **2–3 个可行 approaches**。

### Research output format（PRD）

PRD 本身只应引用已持久化 research files，不要重复其内容。添加指向 `research/*.md` 的 `## 研究参考` section。

可选：添加 convergence section，列出由 research 派生的可行 approaches：

```markdown
## 研究参考

* [`research/<topic-a>.md`](research/<topic-a>.md) — <one-line takeaway>
* [`research/<topic-b>.md`](research/<topic-b>.md) — <one-line takeaway>

## 研究备注

### 相似工具的做法

* ...
* ...

### 本 repo/project 的约束

* ...

### 当前可行方案

**方案 A：<name>**（推荐）

* 工作方式：
* 优点：
* 缺点：

**方案 B：<name>**

* 工作方式：
* 优点：
* 缺点：

**方案 C：<name>**（可选）

* ...
```

然后问**一个**偏好问题：

* "你更偏好哪个方案：A / B / C（或其他）？"

---

## 第 5 步：扩展扫描（DIVERGE）— 初步理解后必需

当你能总结目标后，在收敛前主动拓宽思考。

### 扩展类别（每类保持 1–2 bullet）

1. **未来演进**

   * 这个 feature 在 1–3 个月后可能变成什么？
   * 现在值得保留哪些 extension points？

2. **相关场景**

   * 哪些相邻 commands/flows 应与此保持一致？
   * 是否有 parity expectations（create vs update、import vs export 等）？

3. **Failure 与 edge cases**

   * Conflicts、offline/network failure、retries、idempotency、compatibility、rollback
   * Input validation、security boundaries、permission checks

### 扩展消息模板（发给用户）

```markdown
我理解你想实现：<current goal>。

进入设计前，我先快速扩展思考三个类别（避免后续返工）：

1. 未来演进：<1–2 bullets>
2. 相关场景：<1–2 bullets>
3. Failure/edge cases：<1–2 bullets>

这次 MVP 你希望包含哪些内容（或都不包含）？

1. 只做当前需求（minimal viable）
2. 增加 <X>（为未来扩展预留）
3. 增加 <Y>（提升健壮性/一致性）
4. 其他：描述你的偏好
```

然后更新 PRD：

* MVP 包含什么 → `需求`
* 排除什么 → `不在范围内`

---

## 第 6 步：Q&A 循环（CONVERGE）

### 规则

* 每条消息一个问题
* 可行时优先 multiple-choice
* 每次用户回答后：

  * 立即更新 PRD
  * 将已回答项从 `待确认问题` 移到 `需求`
  * 用可测试 checkboxes 更新 `验收标准`
  * 澄清 `不在范围内`

### 问题优先级（推荐）

1. **MVP scope boundary**（包含/排除什么）
2. **Preference decisions**（展示具体选项后）
3. **Failure/edge behavior**（仅限 MVP-critical paths）
4. **Success metrics & Acceptance Criteria**（什么证明它可用）

### 推荐问题格式（multiple choice）

```markdown
对于 <topic>，你更偏好哪种方案？

1. **选项 A** — <含义 + trade-off>
2. **选项 B** — <含义 + trade-off>
3. **选项 C** — <含义 + trade-off>
4. **其他** — 描述你的偏好
```

---

## 第 7 步：提出 Approaches + 记录 Decisions（复杂 tasks）

当 requirements 足够清晰后，提出 2–3 个 approaches（如果还没通过 research-first 完成）：

```markdown
基于当前信息，这里有 2–3 个可行方案：

**方案 A：<name>**（推荐）

* 做法：
* 优点：
* 缺点：

**方案 B：<name>**

* 做法：
* 优点：
* 缺点：

你更偏好哪个方向？
```

将结果作为 ADR-lite section 记录到 PRD：

```markdown
## 决策（ADR-lite）

**背景**：为什么需要这个决策
**决策**：选择了哪个方案
**后果**：Trade-offs、风险、潜在未来改进
```

---

## 第 8 步：最终确认 + 实现计划

当待确认问题已解决，用结构化中文摘要确认完整需求：

### 最终确认格式

```markdown
这是我对完整需求的理解：

**目标**：<一句话>

**需求**：

* ...
* ...

**验收标准**：

* [ ] ...
* [ ] ...

**完成定义**：

* ...

**不在范围内**：

* ...

**技术方案**：
<简要摘要 + 关键决策>

**实现计划（小 PRs）**：

* PR1: <scaffolding + tests + minimal plumbing>
* PR2: <core behavior>
* PR3: <edge cases + docs + cleanup>

这样是否正确？如果是，我会继续进入实现。
```

### Subtask 拆分（复杂 Tasks）

对包含多个独立 work items 的复杂 tasks，创建 subtasks：

```bash
# 创建 child tasks
CHILD1=$(python3 ./.trellis/scripts/task.py create "Child task 1" --slug child1 --parent "$TASK_DIR")
CHILD2=$(python3 ./.trellis/scripts/task.py create "Child task 2" --slug child2 --parent "$TASK_DIR")

# 或链接 existing tasks
python3 ./.trellis/scripts/task.py add-subtask "$TASK_DIR" "$CHILD_DIR"
```

---

## PRD 目标结构（最终）

`prd.md` 应收敛为：

```markdown
# <Task Title>

## 目标

<为什么 + 做什么>

## 需求

* ...

## 验收标准

* [ ] ...

## 完成定义

* ...

## 技术方案

<关键设计 + 决策>

## 决策（ADR-lite）

背景 / 决策 / 后果

## 不在范围内

* ...

## 技术备注

<约束、references、files、research notes>
```

---

## Anti-Patterns（严格避免）

* 向用户询问可从 repo 推导出的 code/context
* 在展示具体选项前要求用户选择 approach
* 关于是否 research 的 meta questions
* 狭窄停留在初始请求，不考虑 evolution/edges
* 让 brainstorming 漂移而不更新 PRD

---

## 与 Start Workflow 的集成

brainstorm 完成后（第 8 步确认通过），flow 继续进入 Task Workflow 的 **Phase 2：准备实现**：

```text
Brainstorm
  步骤 0：创建 task directory + 初始化中文 PRD
  步骤 1–7：发现 requirements，research，converge
  步骤 8：最终确认 → 用户批准
  ↓
Task Workflow Phase 2（准备实现）
  Code-Spec Depth Check (if applicable)
  → Research codebase (based on confirmed PRD)
  → Configure code-spec context (jsonl files)
  → Activate task
  ↓
Task Workflow Phase 3 (Execute)
  Implement → Check → Complete
```

task directory 和 PRD 已在 brainstorm 中存在，因此完全跳过 Task Workflow 的 Phase 1。

---

## 相关 Commands

| Command | 使用时机 |
|---------|-------------|
| ``start` (Trellis command)` | 触发 brainstorm 的入口点 |
| ``finish-work` (Trellis command)` | implementation 完成后 |
| ``update-spec` (Trellis command)` | 工作期间出现新 patterns 时 |
