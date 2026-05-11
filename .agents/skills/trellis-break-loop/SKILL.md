---
name: trellis-break-loop
description: "深度 bug 分析，用于打破修复-遗忘-重复循环。分析 root cause 分类、fixes 失败原因、预防机制，并将知识捕获到 specs。修复 bug 后用于防止同类 bug。"
---

# 打破循环 - 深度 Bug 分析

debug 完成后，使用此 skill 进行深度分析，打破“fix bug -> forget -> repeat”循环。

---

## 分析框架

从以下 5 个维度分析你刚修复的 bug：

### 1. Root Cause 分类

这个 bug 属于哪类？

| 分类 | 特征 | 示例 |
|----------|-----------------|---------|
| **A. Missing Spec** | 没有说明该怎么做的文档 | 新功能没有 checklist |
| **B. Cross-Layer Contract** | layers 之间接口不清楚 | API 返回格式与期望不同 |
| **C. Change Propagation Failure** | 改了一处，漏了其他处 | 修改 function signature，漏了 call sites |
| **D. Test Coverage Gap** | Unit test 通过，integration 失败 | 单独可用，组合后破坏 |
| **E. Implicit Assumption** | 代码依赖未记录假设 | Timestamp seconds vs milliseconds |

### 2. Fixes 为什么失败（如适用）

如果成功前尝试过多种 fixes，分析每次失败：

- **Surface Fix**：修了症状，没修 root cause
- **Incomplete Scope**：找到 root cause，但没覆盖所有情况
- **Tool Limitation**：grep 漏掉了，type check 不够严格
- **Mental Model**：一直看同一 layer，没有 cross-layer 思考

### 3. 预防机制

哪些机制能防止它再次发生？

| 类型 | 描述 | 示例 |
|------|-------------|---------|
| **Documentation** | 写下来让大家知道 | 更新 thinking guide |
| **Architecture** | 通过结构让错误不可能发生 | Type-safe wrappers |
| **Compile-time** | 严格类型检查，无 escape hatches | Signature 变更导致 compile error |
| **Runtime** | Monitoring、alerts、scans | 检测 orphan entities |
| **Test Coverage** | E2E tests、integration tests | 验证完整 flow |
| **Code Review** | Checklist、PR template | “你检查 X 了吗？” |

### 4. 系统性扩展

这个 bug 揭示了哪些更广泛的问题？

- **Similar Issues**：哪里还可能存在这个问题？
- **Design Flaw**：是否存在根本架构问题？
- **Process Flaw**：开发流程是否可改进？
- **Knowledge Gap**：团队是否缺少某些理解？

### 5. 知识捕获

将洞察固化到系统中：

- [ ] 更新 `.trellis/spec/guides/` thinking guides
- [ ] 更新相关 `.trellis/spec/` docs
- [ ] 创建 issue record（如适用）
- [ ] 为 root fix 创建 feature ticket
- [ ] 需要时更新 check guidelines

---

## 输出格式

请按此格式输出分析：

```markdown
## Bug Analysis: [Short Description]

### 1. Root Cause Category
- **Category**: [A/B/C/D/E] - [Category Name]
- **Specific Cause**: [Detailed description]

### 2. Why Fixes Failed (if applicable)
1. [First attempt]: [Why it failed]
2. [Second attempt]: [Why it failed]
...

### 3. Prevention Mechanisms
| Priority | Mechanism | Specific Action | Status |
|----------|-----------|-----------------|--------|
| P0 | ... | ... | TODO/DONE |

### 4. Systematic Expansion
- **Similar Issues**: [List places with similar problems]
- **Design Improvement**: [Architecture-level suggestions]
- **Process Improvement**: [Development process suggestions]

### 5. Knowledge Capture
- [ ] [Documents to update / tickets to create]
```

---

## 核心理念

> **调试的价值不在于修复这个 bug，而在于让这类 bug 永远不再发生。**

三层洞察：
1. **Tactical**：如何修复这个 bug
2. **Strategic**：如何预防这一类 bugs
3. **Philosophical**：如何扩展思维模式

30 分钟分析可以节省未来 30 小时调试。

---

## 分析后：立即行动

**重要**：完成上述分析后，你必须立即：

1. **更新 spec/guides** - 不要只列 TODOs，实际更新相关文件：
   - 如果是 cross-platform issue → 更新 `cross-platform-thinking-guide.md`
   - 如果是 cross-layer issue → 更新 `cross-layer-thinking-guide.md`
   - 如果是 code reuse issue → 更新 `code-reuse-thinking-guide.md`
   - 如果是 domain-specific → 更新 `backend/*.md` 或 `frontend/*.md`

2. **同步 templates** - 更新 `.trellis/spec/` 后，同步到 `src/templates/markdown/spec/`

3. **Commit spec updates** - 这是主要输出，而不只是分析文本

> **如果分析只停留在聊天中，它就没有价值。价值在于更新后的 specs。**
