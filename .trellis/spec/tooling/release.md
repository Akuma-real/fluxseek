# 发布与质量门禁

## 质量命令

- `just analyze` 用于静态分析。
- `just test` 用于全量测试。
- `just test -- <path>` 用于聚焦回归测试。
- `just release-check` 用于发布前检查。

## 构建命令

- Linux 开发运行：`just run -- -d linux`
- Android 开发运行：`just run -- -d android --dart-define=cronetHttpNoPlay=true`
- Android release APK：`just build -- apk --release --target-platform android-arm64`
- 完整发布工作流：`just release` 或 `just prerelease`

## 发布脚本

- `tool/release.dart` 控制 release/prerelease 流程。
- `tool/project_tasks.dart` 包含更高层的 app 和 native 任务编排。
- `tool/project_prep.dart` 检查环境、l10n 生成和 Android 签名状态。

## 版本规则

- 不要在普通 feature 或 fix commit 中手动 bump `pubspec.yaml` 版本。
- feature/fix commit 保持当前已检入版本；版本变更由发布脚本负责。
- beta 发布使用 `just prerelease <target>`，稳定发布使用 `just release <target>`。
- `tool/release.dart` 将 `pubspec.yaml` 写为 `<releaseVersion>+<dateBuildCode>`，创建专用的 `chore: bump version to <releaseVersion>` commit，并打 tag `v<releaseVersion>`。
- 例如，在 `0.1.0-beta.8+2026050923` 上落地修复后，运行 `just prerelease next` 生成下一版 beta，如 `0.1.0-beta.9+YYYYMMDDNN`。

## 规则

- 对窄范围 service/parser 修复优先运行聚焦测试，然后运行 `just analyze`。
- 修改 Android Kotlin、Gradle、native adapter 依赖、签名或发布脚本时运行 Android APK build。
- 除非用户明确要求，否则不要从 AI 会话 push 或发布 release。
- 除非项目已经跟踪生成的构建产物，否则不要把它们纳入 commit。
