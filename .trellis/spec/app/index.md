# Flutter App Guidelines

> fluxseek 是面向 NodeSeek 的 Flutter 客户端，Android 是正式发布目标，Linux 主要用于开发和调试。

## Pre-Development Checklist

- 先读 [architecture.md](./architecture.md)，确认改动应该落在 page、widget、provider、service、model、utils 还是本地 package。
- 改 UI、页面或状态时读 [state-and-ui.md](./state-and-ui.md)。
- 改文案或本地化时读 [localization.md](./localization.md)。
- 改测试或新增回归时读 [testing.md](./testing.md)。
- 涉及网络、Cookie、Cloudflare、NodeSeek SSR/API 时同时读 `.trellis/spec/network/index.md`。
- 涉及 Android MethodChannel、Gradle、签名、Manifest 时同时读 `.trellis/spec/android/index.md`。
- 涉及命令、生成代码、workspace package、release 时同时读 `.trellis/spec/tooling/index.md`。
- 总是读 `.trellis/spec/guides/index.md`。

## Layer Map

| Area | Source of truth |
| --- | --- |
| App entry and bootstrap | `lib/main.dart` |
| Pages | `lib/pages/` |
| Reusable widgets | `lib/widgets/` |
| Riverpod state | `lib/providers/` |
| Data models | `lib/models/` |
| Business and platform services | `lib/services/` |
| Utilities | `lib/utils/` |
| Feature modules | `lib/modules/` |
| Local packages | `packages/*/` |

## Rules

- 不要把这个仓当成 web 前后端项目；不要写 backend/frontend 语境的规范或目录建议。
- Android 是正式目标；Linux 可作为开发验证目标，但不要把 Linux-only 行为当成发布行为。
- 真实能力优先于占位功能。NodeSeek 没有确认的能力不要在 UI 或 service 中伪造。
- 优先复用已有 provider、service、widget、tool 命令；新增抽象前先 `rg` 搜同类实现。
- AI 助手与用户对话时使用中文，不要用英文。
