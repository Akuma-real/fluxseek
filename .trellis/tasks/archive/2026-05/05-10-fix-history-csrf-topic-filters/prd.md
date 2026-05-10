# Fix History, CSRF, Topic Categories, And Filters

## Goal

Fix four user-facing regressions in the NodeSeek app experience: profile history must show the same local WebView history that actually has data, comment/reply submission must pass NodeSeek CSRF checks, homepage topics must show category badges, and the topic filter/sort controls must only expose capabilities that the current NodeSeek adapter really supports.

## Requirements

- The profile "浏览历史" entry and optional history navigation entry show local WebView history from `webHistoryProvider`.
- The redundant profile "网页浏览" entry is removed after history is reachable directly.
- Web history timestamps remain relative for recent visits but switch to an absolute timestamp after the short relative window.
- NodeSeek comment/reply write requests include CSRF headers expected by the current cookie/token architecture.
- Homepage topic cards show category badges even when category provider data is unavailable or not yet loaded.
- Topic filter/sort UI does not expose unsupported NodeSeek options that currently produce empty results.

## Acceptance Criteria

- [ ] Opening "我的" -> "浏览历史" shows the same local history as the old "网页浏览" -> "浏览历史" path.
- [ ] Web history entries older than the threshold show concrete timestamps.
- [ ] Reply/comment POST requests include `x-csrf-challenge` and reuse the stored dynamic CSRF token when present.
- [ ] Home topic cards render a category badge from parsed topic fallback data.
- [ ] Unsupported filters such as new/unread/unseen/top/hot and unsupported sort fields are not selectable from the homepage controls.
- [ ] Analyzer and focused tests pass.

## Technical Approach

- Route history UI to `WebHistoryPage` wherever `NavEntryIds.history` or profile history is intended to show user-visible browsing history.
- Add a small `TimeUtils` helper for recent-relative history display instead of changing global relative-time behavior.
- Keep NodeSeek list capability honest by limiting exposed filter/sort options to `latest` and default order until real endpoints exist.
- Preserve parsed category fallback metadata and use it when category provider lookups fail.
- Update request header injection to include both NodeSeek's static CSRF challenge and the stored `X-CSRF-Token` when available.

## Out of Scope

- Implementing new NodeSeek endpoints for unread/new/top/hot/sort modes.
- Rebuilding the browser homepage.
- Changing remote NodeSeek account browsing-history APIs.

## Technical Notes

- `lib/providers/web_history_provider.dart` is the local history source populated by `WebViewPage.onLoadStop`.
- `lib/providers/user_content_providers.dart` remote seen history is separate and can be empty.
- `lib/services/nodeseek/client_parts/_topics.dart` returns empty responses for new/unread/unseen/top/hot.
- `lib/services/nodeseek/node_seek_service.dart` only supports latest SSR and simple category SSR lists; sort/tag/period combinations fall back to empty.
- NodeSeek MCP/browser live verification was unavailable in this environment due to 429 from the browser tool; implementation uses existing repo contracts and tests.
