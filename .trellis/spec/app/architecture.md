# App 架构

## 项目形态

fluxseek 是 Flutter workspace 单仓：

- 根应用：`lib/`、`android/`、`linux/`
- 本地 workspace packages：`packages/ai_model_manager`、`packages/enhanced_cookie_jar`、`packages/extended_image_lite`、`packages/pangutext`、`packages/paper_shaders`
- 开发脚本：`tool/`
- CI 辅助脚本：`scripts/ci/linux/`

`pubspec.yaml` 是依赖、workspace、asset、font 的源头；`.fvmrc` 锁定 Flutter `3.41.9`。

## 放置规则

- `lib/pages/` 放屏幕级页面，例如 `lib/pages/topics_page.dart` 和 `lib/pages/topic_detail_page/topic_detail_page.dart`。
- `lib/widgets/` 放跨页面复用组件；页面私有组件放页面子目录，如 `lib/pages/topic_detail_page/widgets/`。
- `lib/providers/` 放 Riverpod 状态和组合导出；领域子目录已有 `topic_list/`、`topic_detail/`、`message_bus/`。
- `lib/services/` 放业务服务、网络服务、平台服务和持久化服务。
- `lib/models/` 放纯数据模型和 JSON 映射。
- `lib/utils/` 放无状态工具，如 URL、时间、分页、平台判断。
- `lib/modules/<feature>/` 用于边界清晰的功能模块，现有例子是 `lib/modules/ldc_reward/`。

## 现有入口

- App 启动、初始化顺序和 ProviderScope 都在 `lib/main.dart`。
- NodeSeek provider 聚合导出在 `lib/providers/nodeseek_providers.dart`。
- 网络统一导出在 `lib/services/network/network.dart`。
- NodeSeek 服务入口是 `lib/services/nodeseek/node_seek_client.dart` 和 `lib/services/nodeseek/node_seek_service.dart`。

## 不要

- 不要新建 web-style `frontend/`、`backend/`、`api/` 目录。
- 不要把生成文件当手写源改；l10n 生成入口见 `.trellis/spec/tooling/workflow.md`。
- 不要绕过现有服务层让 widget 直接拼 NodeSeek 请求。
