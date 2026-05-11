# 全历史重写设计

## 决策

用户选择：全历史重写，不保留任何 tag，并删除远端已有 beta tags。

Commit message 策略：保留 `feat:` / `fix:` / `chore:` / `docs:` 等 Conventional Commit 前缀，标题主体使用中文。

## 风险

* 所有 commit hash 会变化。
* `v0.1.0-beta.7` 到 `v0.1.0-beta.16` 的本地和远端 tags 会删除。
* GitHub Releases 可能出现无 tag 或异常状态，需要之后手动清理。
* 其他 clone 需要重新同步，通常要重新 clone 或 hard reset 到新 `main`。
* 需要 force push `main`，这是破坏性远端操作。

## 安全措施

* 执行前创建本地备份分支：`backup/pre-history-rewrite-<timestamp>`。
* 执行前确认工作树只包含当前 task 文件，且先提交 task planning/design 文件。
* 先在临时 orphan 分支构建新历史，验证内容与当前 `HEAD` 文件树一致。
* 验证通过后再移动 `main`。
* 删除本地 tags 前记录 tag 列表到 task notes。
* 删除远端 tags 和 force push `main` 必须有用户明确确认。

## 目标提交结构

将现有 83 个 commit 压缩为少量语义提交，推荐结构：

1. `chore: 初始化 Flutter 工作区`
2. `build: 配置平台构建与发布流程`
3. `feat: 引入本地 packages 与应用资源`
4. `feat: 添加本地化资源与生成流程`
5. `feat: 实现 NodeSeek 领域模型与网络栈`
6. `feat: 实现应用状态与界面`
7. `test: 添加解析、网络、更新与界面回归测试`
8. `perf: 优化 Android 发布构建`
9. `chore: 升级依赖与工具链`
10. `docs: 中文化 Trellis 与 AI 指导`
11. `fix: 稳定 NodeSeek 解析、CSRF 与主题流程`
12. `chore: 将版本提升到 0.1.0-beta.16`

## 实现策略

优先用 `git reset --soft` / orphan branch 组合生成新线性历史，避免交互式 rebase。由于目标是整理全历史，不需要逐 commit 保留原始 authorship。最终文件树必须与重写前 `HEAD` 完全一致。

## 验证

* `git diff <old-head>..<new-head>` 应显示最终文件树无差异，或用 `git diff --exit-code <old-head> <new-head>` 验证。
* `git status --porcelain` 干净。
* `git log --oneline --graph` 显示目标结构。
* tags 不存在：`git tag` 输出为空。
* 如执行远端清理，验证 `git ls-remote --tags origin` 不再列出旧 beta tags。
