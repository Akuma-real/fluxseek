---
name: trellis-before-dev
description: "实现开始前，从 .trellis/spec/ 发现并注入项目特定编码指南。读取目标 package 的 spec indexes、开发前检查清单和共享思考指南。开始新编码 task、写任何代码前、切换到不同 package 或需要刷新项目约定与标准时使用。"
---

开始 task 前读取相关开发指南。

执行以下步骤：

1. **读取当前 task artifacts**：
   - `prd.md`：需求和验收标准
   - `design.md`（如存在）：技术设计
   - `implement.md`（如存在）：执行顺序和验证计划

2. **发现 packages 及其 spec layers**：
   ```bash
   python3 ./.trellis/scripts/get_context.py --mode packages
   ```

3. **根据以下信息识别适用于当前 task 的 specs**：
   - 你正在修改哪个 package（例如 `cli/`、`docs-site/`）
   - 工作类型（backend、frontend、unit-test、docs 等）
   - task artifacts 引用的任何 spec/research paths

3. **读取每个相关模块的 spec index**：
   ```bash
   cat .trellis/spec/<package>/<layer>/index.md
   ```
    遵循 index 中的 **"开发前检查清单"** section。

4. **读取 开发前检查清单 中列出的、与 task 相关的具体 guideline files**。Index 不是目标 — 它会指向实际 guideline files（例如 `error-handling.md`、`conventions.md`、`mock-strategies.md`）。读取这些文件以理解编码标准和 patterns。

5. **始终读取共享 guides**：
   ```bash
   cat .trellis/spec/guides/index.md
   ```

6. 理解你需要遵循的编码标准和 patterns，然后继续你的开发计划。

写任何代码前，此步骤是**强制的**。
