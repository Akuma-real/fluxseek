# 全历史重写设计

## 决策

用户选择：全历史重写，不保留任何 tag，并删除远端已有 beta tags。

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

1. `chore: bootstrap Flutter workspace`
2. `build: configure platform builds and release workflow`
3. `feat: import bundled packages and app assets`
4. `feat: add localization resources`
5. `feat: implement NodeSeek domain and network stack`
6. `feat: implement app state and UI`
7. `test: add parser, network, update, and UI regressions`
8. `perf: optimize Android release builds`
9. `chore: upgrade dependencies and tooling`
10. `docs: localize Trellis and AI guidance to Chinese`
11. `fix: stabilize NodeSeek parsing, csrf, and topic flows`
12. `chore: bump version to 0.1.0-beta.16`

## 实现策略

优先用 `git reset --soft` / orphan branch 组合生成新线性历史，避免交互式 rebase。由于目标是整理全历史，不需要逐 commit 保留原始 authorship。最终文件树必须与重写前 `HEAD` 完全一致。

## 验证

* `git diff <old-head>..<new-head>` 应显示最终文件树无差异，或用 `git diff --exit-code <old-head> <new-head>` 验证。
* `git status --porcelain` 干净。
* `git log --oneline --graph` 显示目标结构。
* tags 不存在：`git tag` 输出为空。
* 如执行远端清理，验证 `git ls-remote --tags origin` 不再列出旧 beta tags。
