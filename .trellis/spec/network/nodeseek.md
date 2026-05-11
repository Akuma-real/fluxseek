# NodeSeek Service

## 架构

- `NodeSeekClient` 是面向 app 的 client 入口。
- `NodeSeekService` 包含 SSR/API 行为，并将 NodeSeek responses 转换为 app models。
- `lib/services/nodeseek/client_parts/` 拆分 auth、topics、posts、users、search、drafts、notifications 等 API groups。
- `ssr_parser.dart` 为 list/detail/search flows 解析渲染后的 NodeSeek HTML 和 embedded JSON。
- Models 位于 `lib/models/`；不要向 UI code 返回原始 response maps。

## 当前行为

- 官方 NodeSeek host 的 SSR 可能需要 WebView；`NodeSeekService.getSsrResponse()` 会在官方 host 或 native SSR 返回 Cloudflare 403 后切换到 WebView。
- 话题列表排序依赖 SSR list fetch 前的 `sortBy=postTime` cookie。
- 话题列表能力刻意保守：当前 adapter 只暴露 latest/default SSR list 和简单 category SSR lists。`new`、`unread`、`unseen`、`top`、`hot`、任意 tag filters 和显式 sort fields 必须在 service 对真实 NodeSeek responses 完成实现和测试前对 UI 保持隐藏。
- Static category fallback 定义在 `NodeSeekService.staticCategoryData`。
- 首屏性能可以使用 preloaded data；见 `PreloadedDataService`。

## 规则

- 只解析和映射由 NodeSeek responses 确认的能力。如果 source response 缺少 author/avatar 字段，不要发明它们。
- 如果某个 NodeSeek list mode 尚未实现，不要把它作为可选择 UI 展示。空 placeholder service methods 是实现缺口，不是产品能力。
- 保持 endpoint grouping 在 `client_parts/` 中，不要让 `node_seek_client.dart` 变得更大。
- SSR parsing 变更需在 `test/services/nodeseek/ssr_parser_test.dart` 新增或更新测试。
- 使用 `UrlHelper.resolveUrlWithCdn()` 等 URL helpers 进行 avatar/media URL 规范化。

## 场景：NodeSeek 话题列表能力边界

### 1. 范围 / 触发
- 触发：在 `lib/providers/topic_list/`、`lib/widgets/topic/` 或 `NodeSeekService` 中添加或暴露 topic list filters/sorts。

### 2. 签名
- UI filter source：`supportedTopicListFilters` in `lib/providers/topic_list/filter_provider.dart`。
- UI sort source：`supportedTopicSortOrders` in `lib/providers/topic_list/sort_provider.dart`。
- Service entry points：`NodeSeekClient.getLatestTopics()` 和 `NodeSeekService.getFilteredTopics()`。

### 3. 契约
- Latest/default list：可以 fetch `/` 或 `/page-n` SSR 并解析渲染后的 topic rows。
- Simple category list：仅在没有 tag、period、order 或 ascending 参数时，可以 fetch `/categories/<slug>` 或 `/categories/<slug>/page-n`。
- Unsupported modes 不得可选：`new`、`unread`、`unseen`、`top`、`hot`、tag combinations 和显式 order fields。

### 4. 验证与错误矩阵
- Unsupported mode 持久化在 preferences 中 -> 规范化为 `latest` / `defaultOrder`。
- UI 请求 unsupported mode -> 不要在 dropdown options 中暴露它。
- 发现 unsupported service path -> 在加入 supported constants 前添加 parser/service implementation 和 regression tests。

### 5. Good/Base/Bad 案例
- Good：UI 读取 supported constants，并只展示由已实现 service behavior 支撑的选项。
- Base：Latest 和 simple category lists 继续通过 SSR 工作。
- Bad：UI 展示“热门”或“浏览量”，但 service 返回空 `TopicListResponse`。

### 6. 必需测试
- Unit test supported filter/sort constants。
- 对 list mode 使用的任何新 SSR shape 增加 parser tests。
- Service tests 或 fixtures 证明每个新暴露 mode 都映射真实 NodeSeek response fields。

### 7. 错误 vs 正确

#### 错误
```dart
List<(TopicListFilter, String)> get filterOptions => [
  (TopicListFilter.latest, S.current.topic_filterLatest),
  (TopicListFilter.hot, S.current.topic_filterHot), // service returns empty
];
```

#### 正确
```dart
List<(TopicListFilter, String)> get filterOptions => [
  for (final filter in supportedTopicListFilters)
    if (filter == TopicListFilter.latest)
      (TopicListFilter.latest, S.current.topic_filterLatest),
];
```

## 示例锚点

- `lib/services/nodeseek/node_seek_service.dart`
- `lib/services/nodeseek/client_parts/_users.dart`
- `lib/services/nodeseek/ssr_parser.dart`
- `test/services/nodeseek/ssr_parser_test.dart`
