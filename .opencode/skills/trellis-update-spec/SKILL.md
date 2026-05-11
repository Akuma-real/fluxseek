---
name: trellis-update-spec
description: "将可执行契约和编码约定捕获到 .trellis/spec/ 文档中。当你从 debugging、implementing 或讨论中学到值得为未来 sessions 保留的内容时使用。"
---

# 更新 Code-Spec - 捕获可执行契约

当你学到有价值的内容（来自 debugging、implementing 或讨论）时，使用此 skill 更新相关 code-spec 文档。

**时机**：完成 task、修复 bug 或发现新 pattern 后

---

## Code-Spec 优先规则（关键）

在本项目中，实现工作的 “spec” 指 **code-spec**：
- 可执行契约（不是只有原则的文字）
- 具体 signatures、payload fields、env keys 和 boundary behavior
- 可测试的 validation/error behavior

如果变更触及 infra 或 cross-layer contracts，必须达到 code-spec 深度。

### 强制触发条件

当变更包含以下任一内容时，应用 code-spec 深度：
- 新增/变更 command 或 API signature
- Cross-layer request/response contract 变更
- Database schema/migration 变更
- Infra integration（storage、queue、cache、secrets、env wiring）

### 强制输出（7 Sections）

对触发的 tasks，包含以下全部 sections：
1. 范围 / 触发
2. 签名（command/API/DB）
3. 契约（request/response/env）
4. 验证与错误矩阵
5. Good/Base/Bad 案例
6. 必需测试（带 assertion points）
7. 错误 vs 正确（至少一对）

---

## 何时更新 Code-Specs

| 触发 | 示例 | 目标 Spec |
|---------|---------|-------------|
| **实现了 feature** | 添加新 integration 或 module | 相关 spec file |
| **作出 design decision** | 为 extensibility pattern 放弃 simplicity | 相关 spec + "Design Decisions" section |
| **修复了 bug** | 发现 error handling 的隐蔽问题 | 相关 spec（例如 error-handling docs） |
| **发现 pattern** | 找到更好的 code 组织方式 | 相关 spec file |
| **踩到 gotcha** | 学到 X 必须在 Y 前完成 | 相关 spec + "Common Mistakes" section |
| **建立 convention** | 团队同意命名 pattern | Quality guidelines |
| **新 thinking trigger** | “做 Y 前别忘了检查 X” | `guides/*.md`（作为 checklist item） |

**关键洞察**：Code-spec updates 不只是为问题准备。每个 feature implementation 都包含未来 AI/developers 安全执行所需的 design decisions 和 contracts。

---

## Spec 结构概览

```
.trellis/spec/
├── <layer>/           # Per-layer coding standards (e.g., backend/, frontend/, api/)
│   ├── index.md       # Overview and links
│   └── *.md           # Topic-specific guidelines
└── guides/            # Thinking checklists (NOT coding specs!)
    ├── index.md       # Guide index
    └── *.md           # Topic-specific guides
```

### 关键：Code-Spec vs Guide - 明确区别

| 类型 | 位置 | 目的 | 内容风格 |
|------|----------|---------|---------------|
| **Code-Spec** | `<layer>/*.md` | 告诉 AI “如何安全实现” | 签名、contracts、matrices、cases、test points |
| **Guide** | `guides/*.md` | 帮助 AI “该思考什么” | Checklists、questions、指向 specs 的 pointers |

**决策规则**：问自己：

- “这是**如何写**代码” → 放到 spec layer directory
- “这是写之前**要考虑什么**” → 放到 `guides/`

**示例**：

| 学到的内容 | 错误位置 | 正确位置 |
|----------|----------------|------------------|
| “此 task 使用 API X 而非 API Y” | ❌ `guides/`（对 thinking guide 太具体） | ✅ 相关 spec file（具体 convention） |
| “做 Y 时记得检查 X” | ❌ Spec file（对 spec 太抽象） | ✅ `guides/`（thinking checklist） |

**Guides 应该是指向 specs 的短 checklists**，而不是重复详细规则。

---

## 更新流程

### 第 1 步：识别你学到了什么

回答这些问题：

1. **你学到了什么？**（具体）
2. **为什么重要？**（它预防什么问题？）
3. **它属于哪里？**（哪个 spec file？）

### 第 2 步：分类更新类型

| 类型 | 描述 | 动作 |
|------|-------------|--------|
| **Design Decision** | 为什么选择 approach X 而不是 Y | 添加到 "Design Decisions" section |
| **Project Convention** | 本项目如何做 X | 添加到相关 section，并带 examples |
| **New Pattern** | 发现的可复用 approach | 添加到 "Patterns" section |
| **Forbidden Pattern** | 会引发问题的东西 | 添加到 "Anti-patterns" 或 "Don't" section |
| **Common Mistake** | 容易犯的错误 | 添加到 "Common Mistakes" section |
| **Convention** | 已达成一致的标准 | 添加到相关 section |
| **Gotcha** | 非显而易见的行为 | 添加 warning callout |

### 第 3 步：读取目标 Code-Spec

编辑前，读取当前 code-spec 以：
- 理解现有结构
- 避免重复内容
- 找到适合此次更新的 section

```bash
cat .trellis/spec/<category>/<file>.md
```

### 第 4 步：执行更新

遵循这些原则：

1. **具体**：包含具体 examples，而不仅是抽象规则
2. **解释原因**：说明这能预防什么问题
3. **展示契约**：添加 signatures、payload fields 和 error behavior
4. **展示代码**：为关键 patterns 添加 code snippets
5. **保持简短**：每个 section 一个概念

### 第 5 步：更新 Index（如需要）

如果你添加了新 section 或 code-spec status 发生变化，更新该 category 的 `index.md`。

---

## 更新模板

### Infra/Cross-Layer Work 强制模板

```markdown
## Scenario: <name>

### 1. 范围 / 触发
- Trigger: <why this requires code-spec depth>

### 2. 签名
- Backend command/API/DB signature(s)

### 3. 契约
- Request fields (name, type, constraints)
- Response fields (name, type, constraints)
- Environment keys (required/optional)

### 4. 验证与错误矩阵
- <condition> -> <error>

### 5. Good/Base/Bad 案例
- Good: ...
- Base: ...
- Bad: ...

### 6. 必需测试
- Unit/Integration/E2E with assertion points

### 7. 错误 vs 正确
#### Wrong
...
#### Correct
...
```

### 添加 Design Decision

```markdown
### Design Decision: [Decision Name]

**Context**: What problem were we solving?

**Options Considered**:
1. Option A - brief description
2. Option B - brief description

**Decision**: We chose Option X because...

**Example**:
\`\`\`typescript
// How it's implemented
code example
\`\`\`

**Extensibility**: How to extend this in the future...
```

### 添加 Project Convention

```markdown
### Convention: [Convention Name]

**What**: Brief description of the convention.

**Why**: Why we do it this way in this project.

**Example**:
\`\`\`typescript
// How to follow this convention
code example
\`\`\`

**Related**: Links to related conventions or specs.
```

### 添加 New Pattern

```markdown
### Pattern Name

**Problem**: What problem does this solve?

**Solution**: Brief description of the approach.

**Example**:
\`\`\`
// Good
code example

// Bad
code example
\`\`\`

**Why**: Explanation of why this works better.
```

### 添加 Forbidden Pattern

```markdown
### Don't: Pattern Name

**Problem**:
\`\`\`
// Don't do this
bad code example
\`\`\`

**Why it's bad**: Explanation of the issue.

**Instead**:
\`\`\`
// Do this instead
good code example
\`\`\`
```

### 添加 Common Mistake

```markdown
### 常见错误：说明

**症状**：出现什么问题

**原因**：为什么会发生

**修复**：如何纠正

**预防**：未来如何避免
```

### 添加 Gotcha

```markdown
> **Warning**: Brief description of the non-obvious behavior.
>
> Details about when this happens and how to handle it.
```

---

## 交互模式

如果你不确定要更新什么，回答这些 prompts：

1. **你刚完成了什么？**
   - [ ] 修复 bug
   - [ ] 实现 feature
   - [ ] 重构代码
   - [ ] 进行了 approach 讨论

2. **你学到或决定了什么？**
   - Design decision（为什么选择 X 而不是 Y）
   - Project convention（我们如何做 X）
   - 非显而易见 behavior（gotcha）
   - 更好的 approach（pattern）

3. **未来 AI/developers 是否需要知道这件事？**
   - 为理解代码如何工作 → 是，更新 spec
   - 为维护或扩展 feature → 是，更新 spec
   - 为避免重复错误 → 是，更新 spec
   - 纯一次性 implementation detail → 可以跳过

4. **它与哪个 area 相关？**
   - [ ] Backend code
   - [ ] Frontend code
   - [ ] Cross-layer data flow
   - [ ] Code organization/reuse
   - [ ] Quality/testing

---

## 质量检查清单

完成 code-spec update 前：

- [ ] 内容是否具体且可执行？
- [ ] 是否包含 code example？
- [ ] 是否解释了 WHY，而不只是 WHAT？
- [ ] 是否包含 executable signatures/contracts？
- [ ] 是否包含 validation and error matrix？
- [ ] 是否包含 Good/Base/Bad cases？
- [ ] 是否包含带 assertion points 的 required tests？
- [ ] 是否位于正确 code-spec file？
- [ ] 是否重复现有内容？
- [ ] 新团队成员能否理解？

---

## 与其他 Commands 的关系

```
Development Flow:
  Learn something → `update-spec` (Trellis command) → Knowledge captured
       ↑                                  ↓
  `break-loop` (Trellis command) ←──────────────────── Future sessions benefit
  (deep bug analysis)
```

- ``break-loop` (Trellis command)` - 深度分析 bugs，经常揭示需要 spec updates
- ``update-spec` (Trellis command)` - 实际执行更新
- ``finish-work` (Trellis command)` - 提醒你检查 specs 是否需要更新

---

## 核心理念

> **Code-specs 是活文档。每次 debugging session、每个 “aha moment” 都是让 implementation contract 更清晰的机会。**

目标是**组织记忆**：
- 一个人学到的，所有人都受益
- AI 在一个 session 中学到的，会持久化到未来 sessions
- 错误变成有文档记录的 guardrails
