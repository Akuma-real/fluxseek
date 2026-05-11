---
name: trellis-check
description: "综合质量验证：spec compliance、lint、type-check、tests、cross-layer data flow、代码复用和一致性检查。代码已写完需要质量验证、提交变更前，或长 session 中捕捉 context drift 时使用。"
---

# 代码质量检查

对最近编写代码进行综合质量验证。结合 spec compliance、cross-layer 安全性和 pre-commit checks。

---

## 第 1 步：识别变更内容

```bash
git diff --name-only HEAD
git status
```

## 第 2 步：读取 Task Artifacts 和适用 Specs

Read the current task artifacts in order:

- `prd.md`
- `design.md` if present
- `implement.md` if present

```bash
python3 ./.trellis/scripts/get_context.py --mode packages
```

对每个变更的 package/layer，读取 spec index 并遵循其 **质量检查** section：

```bash
cat .trellis/spec/<package>/<layer>/index.md
```

读取引用的具体 guideline files — index 是指针，不是目标。

## 第 3 步：运行项目检查

运行项目 lint、type-check 和 test 命令。继续前修复任何失败。

## 第 4 步：按检查清单 review

### 代码质量

- [ ] Linter 是否通过？
- [ ] Type checker 是否通过（如适用）？
- [ ] Tests 是否通过？
- [ ] 没有遗留 debug logging？
- [ ] 没有 suppressed warnings 或 type-safety bypasses？

### 测试覆盖

- [ ] 新 function → 已添加 unit test？
- [ ] Bug fix → 已添加 regression test？
- [ ] 行为变更 → 已更新 existing tests？

### Spec 同步

- [ ] `.trellis/spec/` 是否需要更新？（new patterns、conventions、lessons learned）

> “如果我修复了 bug 或发现了非显而易见的事情，我是否应该记录下来，让未来的我不再踩同一个坑？”→ 如果是，更新相关 spec doc。

## 第 5 步：Cross-Layer 维度（如适用）

如果你的变更局限于单个 layer，跳过此步。

### A. Data Flow（变更触及 3+ layers）

- [ ] Read flow trace 是否正确：Storage → Service → API → UI
- [ ] Write flow trace 是否正确：UI → API → Service → Storage
- [ ] Types/schemas 是否在 layers 间正确传递？
- [ ] Errors 是否正确传播给 caller？

### B. 代码复用（修改 constants、创建 utilities）

- [ ] 创建新代码前是否搜索过现有相似代码？
  ```bash
  grep -r "pattern" src/
  ```
- [ ] 如果 2+ 处定义同一值 → 是否提取为 shared constant？
- [ ] 批量修改后，是否更新了所有 occurrences？

### C. Import/Dependency（创建新文件）

- [ ] Import paths 是否正确（relative vs absolute）？
- [ ] 是否没有 circular dependencies？

### D. Same-Layer Consistency

- [ ] 使用同一概念的其他地方是否一致？

---

## 第 6 步：报告并修复

报告发现的 violations，并直接修复。修复后重新运行项目检查。
