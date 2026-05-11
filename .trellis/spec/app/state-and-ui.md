# 状态与 UI

## Riverpod

项目使用 `flutter_riverpod`。常见模式：

- 普通 service provider：`lib/providers/core_providers.dart` 的 `nodeSeekClientProvider`。
- 异步状态：`AsyncNotifier` / `AsyncNotifierProvider`，例如 `CurrentUserNotifier`、`TopicListNotifier`。
- 参数化列表状态：`topicListProvider(categoryId)` 这类 provider family 模式在 `lib/providers/topic_list/`。
- 跨页面聚合导出：`lib/providers/nodeseek_providers.dart` 只做 export，不放业务逻辑。

状态读取约定：

- `build()` 内需要建立依赖时用 `ref.watch`。
- 只读配置、手动刷新参数、避免自动依赖时用 `ref.read`，参考 `TopicListNotifier.build()` 对筛选和排序的处理。
- 刷新失败时优先保留旧数据并暴露错误状态，参考 `CurrentUserNotifier.refreshSilently()`。

## UI 组织

- 屏幕级 widget 放 `lib/pages/`，复杂页面拆到同名目录的 `widgets/`、`controllers/`、`actions/`。
- 可复用视觉组件放 `lib/widgets/<domain>/`，如 `widgets/topic/`、`widgets/post/`、`widgets/content/html_content/`。
- 桌面/移动自适应优先复用 `lib/widgets/layout/` 和 `lib/utils/responsive.dart`。
- 交互提示优先走 `ToastService`、已有 dialog helper 或本地化文本，不要散落硬编码字符串。

## 示例

- 主题列表：`lib/pages/topics_page.dart`
- 详情页控制器：`lib/pages/topic_detail_page/controllers/topic_detail_controller.dart`
- 话题列表 provider：`lib/providers/topic_list/topic_list_provider.dart`
- 通用错误视图：`lib/widgets/common/error_view.dart`

## 不要

- 不要在 widget 中直接持久化 cookie、CSRF、Cloudflare 状态。
- 不要在 UI 里伪造 NodeSeek 作者、头像、权限或统计信息；源响应没有就保守显示。
- 不要把页面私有状态提升成全局 provider，除非有跨页面消费者。
