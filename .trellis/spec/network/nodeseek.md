# NodeSeek Service

## Architecture

- `NodeSeekClient` is the app-facing client entry.
- `NodeSeekService` contains SSR/API behavior and converts NodeSeek responses into app models.
- `lib/services/nodeseek/client_parts/` splits API groups such as auth, topics, posts, users, search, drafts, notifications.
- `ssr_parser.dart` parses rendered NodeSeek HTML and embedded JSON for list/detail/search flows.
- Models live in `lib/models/`; do not return raw response maps to UI code.

## Current Behavior

- Official NodeSeek host may require WebView for SSR; `NodeSeekService.getSsrResponse()` switches to WebView on official host or after native SSR returns Cloudflare 403.
- Topic list ordering relies on the `sortBy=postTime` cookie before SSR list fetches.
- Topic list capability is intentionally conservative: the current adapter only exposes the latest/default SSR list and simple category SSR lists. `new`, `unread`, `unseen`, `top`, `hot`, arbitrary tag filters, and explicit sort fields must stay hidden from UI until the service implements and tests real NodeSeek responses for them.
- Static category fallback is defined in `NodeSeekService.staticCategoryData`.
- Preloaded data may be used for first screen performance; see `PreloadedDataService`.

## Rules

- Parse and map only capabilities confirmed by NodeSeek responses. If a source response lacks author/avatar fields, do not invent them.
- If a NodeSeek list mode is not implemented, do not present it as selectable UI. Empty placeholder service methods are implementation gaps, not product capabilities.
- Keep endpoint grouping in `client_parts/` instead of making `node_seek_client.dart` larger.
- For SSR parsing changes, add or update tests in `test/services/nodeseek/ssr_parser_test.dart`.
- Use URL helpers such as `UrlHelper.resolveUrlWithCdn()` for avatar/media URL normalization.

## Scenario: NodeSeek Topic List Capability Boundary

### 1. Scope / Trigger
- Trigger: Adding or exposing topic list filters/sorts in `lib/providers/topic_list/`, `lib/widgets/topic/`, or `NodeSeekService`.

### 2. Signatures
- UI filter source: `supportedTopicListFilters` in `lib/providers/topic_list/filter_provider.dart`.
- UI sort source: `supportedTopicSortOrders` in `lib/providers/topic_list/sort_provider.dart`.
- Service entry points: `NodeSeekClient.getLatestTopics()` and `NodeSeekService.getFilteredTopics()`.

### 3. Contracts
- Latest/default list: may fetch `/` or `/page-n` SSR and parse rendered topic rows.
- Simple category list: may fetch `/categories/<slug>` or `/categories/<slug>/page-n` only when no tag, period, order, or ascending parameter is present.
- Unsupported modes must not be selectable: `new`, `unread`, `unseen`, `top`, `hot`, tag combinations, and explicit order fields.

### 4. Validation & Error Matrix
- Unsupported mode persisted in preferences -> normalize to `latest` / `defaultOrder`.
- Unsupported mode requested by UI -> do not expose it in dropdown options.
- Unsupported service path discovered -> add parser/service implementation and regression tests before adding it to supported constants.

### 5. Good/Base/Bad Cases
- Good: UI reads supported constants and only shows options backed by implemented service behavior.
- Base: Latest and simple category lists keep working through SSR.
- Bad: UI shows "热门" or "浏览量" while service returns an empty `TopicListResponse`.

### 6. Tests Required
- Unit test supported filter/sort constants.
- Parser tests for any new SSR shape used by a list mode.
- Service tests or fixtures proving each newly exposed mode maps real NodeSeek response fields.

### 7. Wrong vs Correct

#### Wrong
```dart
List<(TopicListFilter, String)> get filterOptions => [
  (TopicListFilter.latest, S.current.topic_filterLatest),
  (TopicListFilter.hot, S.current.topic_filterHot), // service returns empty
];
```

#### Correct
```dart
List<(TopicListFilter, String)> get filterOptions => [
  for (final filter in supportedTopicListFilters)
    if (filter == TopicListFilter.latest)
      (TopicListFilter.latest, S.current.topic_filterLatest),
];
```

## Example Anchors

- `lib/services/nodeseek/node_seek_service.dart`
- `lib/services/nodeseek/client_parts/_users.dart`
- `lib/services/nodeseek/ssr_parser.dart`
- `test/services/nodeseek/ssr_parser_test.dart`
