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
- Static category fallback is defined in `NodeSeekService.staticCategoryData`.
- Preloaded data may be used for first screen performance; see `PreloadedDataService`.

## Rules

- Parse and map only capabilities confirmed by NodeSeek responses. If a source response lacks author/avatar fields, do not invent them.
- Keep endpoint grouping in `client_parts/` instead of making `node_seek_client.dart` larger.
- For SSR parsing changes, add or update tests in `test/services/nodeseek/ssr_parser_test.dart`.
- Use URL helpers such as `UrlHelper.resolveUrlWithCdn()` for avatar/media URL normalization.

## Example Anchors

- `lib/services/nodeseek/node_seek_service.dart`
- `lib/services/nodeseek/client_parts/_users.dart`
- `lib/services/nodeseek/ssr_parser.dart`
- `test/services/nodeseek/ssr_parser_test.dart`
