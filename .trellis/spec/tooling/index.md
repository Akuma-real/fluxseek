# Tooling Guidelines

> 本仓优先通过 `just` 和 `tool/` 包装命令运行 Flutter/Dart 工作流。

## Pre-Development Checklist

- 改依赖、workspace、生成代码、命令入口时读 [workflow.md](./workflow.md)。
- 改 release、版本、构建、CI 脚本时读 [release.md](./release.md)。
- 涉及 Flutter app 代码时同时读 `.trellis/spec/app/index.md`。
- 涉及 Android 构建时同时读 `.trellis/spec/android/index.md`。
- 总是读 `.trellis/spec/guides/index.md`。

## Command Rule

优先使用 `just`：

- `just sync`
- `just l10n`
- `just l10n-check`
- `just analyze`
- `just test`
- `just run -- -d linux`
- `just build -- apk --release --target-platform android-arm64`
- `just release-check`

Only fall back to raw `flutter` / `dart` commands when the wrapper is not appropriate, and explain why.
