# 发布 beta 版本

## 目标

发布下一版 FluxSeek beta，使仓库版本从当前 `0.1.0-beta.15+2026051023` 推进到下一预发布版本，并通过 tag 触发 GitHub Actions 构建与 GitHub prerelease。

## 已知信息

* 用户要求“发beta版本”。
* 用户已明确允许执行实际发布命令，包括 push main 和 push tag。
* 当前 `pubspec.yaml` 版本为 `0.1.0-beta.15+2026051023`。
* `.trellis/spec/tooling/release.md` 规定 beta 发布使用 `just prerelease <target>`。
* `tool/release.dart` 的 `next` 会在当前 beta 序列上递增预发布号，因此目标 release version 预计为 `0.1.0-beta.16`，pubspec build code 由脚本按当前日期生成。
* `tool/release.dart` 非 dry-run 会要求 clean working tree，运行 release prepare，更新 `pubspec.yaml`，创建 `chore: bump version to <releaseVersion>` commit，push main，创建并 push `v<releaseVersion>` tag。
* `.github/workflows/build.yaml` 会在 `v*` tag 上构建 Android APK 并创建 release；带 `-` 的版本会标记为 prerelease。

## 需求

* 按项目发布规范发布下一版 beta。
* 发布前保证工作树除当前 Trellis task 文件外没有未提交业务变更。
* 使用 `just prerelease next` 或等效脚本路径发布下一 beta。
* 因发布命令会 push main 和 tag，执行前必须获得用户明确确认；本任务已获得确认。
* 发布过程中不要手动编辑版本号；由 `tool/release.dart` 负责 bump、commit 和 tag。
* 发布完成后记录实际版本、tag 和关键命令结果。

## 验收标准

* [ ] 发布前检查通过，或失败原因明确记录。
* [ ] `pubspec.yaml` 被发布脚本更新到新的 beta 版本。
* [ ] 版本 bump commit 已创建。
* [ ] `v0.1.0-beta.16` tag 已创建并推送，或实际 tag 与脚本输出一致。
* [ ] GitHub Actions release workflow 已被 tag push 触发，或失败原因明确记录。
* [ ] 不提交构建产物、签名 secret 或本地 keystore。

## 完成定义

* 发布命令执行完成或明确失败并记录原因。
* Trellis check 已确认版本/发布状态。
* 工作通过 Trellis workflow 提交/归档，journal 记录本次发布。

## 技术方案

1. 先处理当前 Trellis task 文件造成的 dirty tree，确保 release 脚本需要的 clean working tree。
2. 运行 `just prerelease next --yes`。
3. 检查 `git log`、tag、远端推送结果和 GitHub Actions 状态。
4. 如发布脚本失败，停止并报告失败点，不手动伪造 tag 或 release。

## 不在范围内

* 修改 release 脚本、GitHub Actions 或构建配置。
* 手动编辑 `pubspec.yaml` 版本号。
* 手动上传 APK 或创建 GitHub release。
* 修改应用功能代码。

## 技术备注

* `just prerelease next` 会运行 `tool/project_tasks.dart release:prepare`，包含发布前检查、analyze、test。
* 发布脚本会 push 到远程仓库；这需要用户确认。
* 当前任务目录本身会让工作树变脏，需要先作为 Trellis 流程提交，或在执行 release 脚本前确保工作树干净。
