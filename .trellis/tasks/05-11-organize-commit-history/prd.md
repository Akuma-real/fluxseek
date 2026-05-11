# 整理提交历史

## 目标

把当前本地 `main` 上未 push 的 Trellis/文档收尾提交整理成更清晰的提交结构，减少 `chore(task)` / `journal` / 清理提交噪音，同时避免破坏已发布的 beta tag 和远端历史。

## 已知信息

* 用户认为当前 commit 记录很乱，希望整理整个项目的 commit。
* 用户选择“激进”整理方向，并进一步选择“全历史重写”。这意味着所有 commit hash 都可能变化，已发布 tags/releases 也需要明确处理策略。
* 用户选择 tag 策略为“不保留任何 tag”。这意味着重写后的仓库历史不再维护 `v0.1.0-beta.7` 到 `v0.1.0-beta.16` 的 git tag；现有 GitHub Releases 与 tag 关系会被破坏或需要另行清理。
* 用户要求重写后的 commit 标题使用中文，但保留 `feat:` / `fix:` / `chore:` / `docs:` 等 Conventional Commit 前缀。
* 当前完整历史共有 83 个 commit。
* 当前 tags 包括 `v0.1.0-beta.7` 到 `v0.1.0-beta.16` 共 10 个 annotated tags。
* 当前 `main` 比 `origin/main` 领先 8 个提交。
* `origin/main` 当前在 `f71c726 chore: bump version to 0.1.0-beta.16`，且该提交被 tag `v0.1.0-beta.16` 指向。
* 领先的 8 个提交主要是：release task 相关提交、Trellis update runtime、重新中文化文档、归档 task、journal、删除归档源目录等。
* 重写已 push/tag 的历史风险高；尤其不应移动或重写 `v0.1.0-beta.16` 已发布 tag 指向的提交。

## 需求

* 在用户确认范围前，不执行 rebase/reset/force push 等历史重写命令。
* 优先整理尚未 push 的本地 ahead 提交，不触碰 `origin/main` 及 `v0.1.0-beta.16` 之前/所在的已发布历史。
* 保留所有内容变更，不丢失 Trellis update、中文化、release task 记录和 journal 信息。
* 整理后的提交应更少、更有语义，例如将同一任务的 task archive/journal/source-removal 合并进对应工作提交，或按“发布 / Trellis update / 中文化 / 记录”分组。
* 重写后的 commit message 标题使用中文说明，保留英文 Conventional Commit 前缀。
* 若需要 push 重写后的本地提交，必须再次获得用户明确确认；禁止对 `main` force push，除非用户明确要求且已说明风险。
* 采用全历史重写前，必须确认最终 commit 结构、tag/release 处理策略、远端 force push 策略和备份/回滚方案。

## 验收标准

* [ ] 用户确认要整理的范围和目标结构。
* [ ] 未修改已发布 tag `v0.1.0-beta.16` 指向的提交。
* [ ] 整理前有可恢复点（例如临时 backup branch）。
* [ ] 整理后 `git log --oneline --graph` 更清晰，提交数量减少或语义更明确。
* [ ] 工作树干净。
* [ ] 不丢失任何内容变更。

## 完成定义

* 用户确认最终 commit 结构可接受。
* 必要时完成提交整理，但不 push，除非用户再次明确要求。
* 记录风险和后续推送建议。

## 技术方案候选

### 方案 A：只整理本地 ahead 8 个提交（推荐）

以 `origin/main` / `v0.1.0-beta.16` 为不变基线，重排或 squash 之后的 8 个本地提交。风险较低，因为未 push；但仍需要备份分支和非交互式 rebase/reset 操作。

### 方案 B：只新增一个整理说明提交，不重写历史

不改变已有 commit，只接受当前历史，在后续提交里改善规范。风险最低，但不能真正减少现有噪音。

### 方案 C：重写更早历史或已 push/tag 历史

可以彻底整理，但风险最高，会影响远端、tag、release 和其他协作者；默认不做。

用户已选择全历史重写作为待细化方案；执行前仍需确认具体目标结构和风险。

## Open Questions

* 全历史重写后的最终 commit 结构是什么？
* 用户已选择删除远端已有 tags（`v0.1.0-beta.7` 到 `v0.1.0-beta.16`）。
* 整理完成后是否允许 force push `main` 和 tags？

## 推荐整理方向

推荐将 83 个 commit 重写为较少的语义分组提交，而不是逐个保留 task/archive/journal 噪音：

1. `chore: 初始化 Flutter 工作区` — 项目骨架、workspace、基础工具。
2. `build: 配置平台构建与发布流程` — Android/Linux/GitHub Actions/release tooling。
3. `feat: 引入本地 packages 与应用资源` — 本地 packages 与 assets。
4. `feat: 添加本地化资源与生成流程` — l10n 资源和生成流程。
5. `feat: 实现 NodeSeek 领域模型与网络栈` — models、services、network、cookie/CSRF 相关基础。
6. `feat: 实现应用状态与界面` — providers、settings、UI。
7. `test: 添加解析、网络、更新与界面回归测试` — 测试集合。
8. `perf: 优化 Android 发布构建` — release size / prep 优化。
9. `chore: 升级依赖与工具链` — dependency、Trellis/OpenCode runtime 更新。
10. `docs: 中文化 Trellis 与 AI 指导` — Trellis spec/skills/workflow 中文化。
11. `fix: 稳定 NodeSeek 解析、CSRF 与主题流程` — beta 后修复集合。
12. `chore: 将版本提升到 0.1.0-beta.16` — 最终版本号。

用户已选择不保留任何 tag，并删除远端已有 tags。因此执行方案需要包含：本地删除 tags、远端删除 tags、全历史重写、将新的 `main` 历史 force push 到远端。执行前仍需最后确认允许 force push `main`。

## 不在范围内

* 默认不 force push `main`。
* 默认不移动或重建 `v0.1.0-beta.16` tag。
* 默认不重写 `origin/main` 已有历史。

## 技术备注

* 如果采用方案 A，建议先创建 backup branch，例如 `backup/pre-rewrite-commit-history-<timestamp>`。
* 由于环境不适合交互式 rebase，应使用非交互式命令或临时分支完成整理。
