# Cookies And Cloudflare

## Source Of Truth

Current cookie architecture is documented in `docs/cookie-sync-status.md`:

- `CookieJar` / `EnhancedPersistCookieJar` is the unique persistent cookie store.
- `BoundarySyncService` only syncs at boundaries such as login or Cloudflare success.
- `RawSetCookieQueue` preserves raw Set-Cookie headers for later WebView flush.
- `AppCookieManager` loads request cookies and saves response Set-Cookie headers.
- `CsrfTokenService` owns CSRF token management.

## Rules

- Do not reintroduce constant WebView-to-CookieJar background sync.
- Preserve host-only cookie priority; duplicate cookie names with same path should prefer the newest trusted host-only session cookie.
- Do not save redirect response cookies into target domains unless the call explicitly opts in.
- Cloudflare detection must use response headers plus body checks, not loose keyword matching alone.
- After manual Cloudflare verification, sync `cf_clearance` once and retry each original request with fresh CookieJar state.
- Do not log cookie values, tokens, or raw secrets. Length, names, and boolean presence are acceptable.

## Example Anchors

- `lib/services/network/cookie/app_cookie_manager.dart`
- `lib/services/network/cookie/boundary_sync_service.dart`
- `lib/services/network/cookie/raw_set_cookie_queue.dart`
- `lib/services/network/interceptors/cf_challenge_interceptor.dart`
- `test/services/network/cookie/app_cookie_manager_test.dart`
