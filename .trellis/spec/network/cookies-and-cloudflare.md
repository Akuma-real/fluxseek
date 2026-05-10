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
- For NodeSeek content write APIs under `/api/content/`, send `x-csrf-challenge: simple-token` and include the stored `X-CSRF-Token` when available. If a content write has no token yet, refresh through `CsrfTokenService.updateCsrfToken()` before dispatch; on BAD CSRF / `csrf check error`, remove any stale `X-CSRF-Token` header case-insensitively, clear the token cache, and refresh once before retrying.

## Scenario: NodeSeek Content Write CSRF

### 1. Scope / Trigger
- Trigger: Creating, editing, or replying through NodeSeek content APIs such as `/api/content/new-comment`, `/api/content/new-discussion`, or `/api/content/edit-comment`.

### 2. Signatures
- Request interceptor: `RequestHeaderInterceptor.onRequest(RequestOptions, RequestInterceptorHandler)`.
- Token owner: `CsrfTokenService.csrfToken`, `updateCsrfToken()`, and `clearCsrfToken()`.
- Retry hook: NodeSeek client auth interceptor handles 403 CSRF/high-risk responses once.

### 3. Contracts
- Every non-GET keeps `x-csrf-challenge: simple-token` unless `extra['skipCsrf'] == true`.
- `/api/content/*` writes refresh a missing dynamic token before dispatching and include `X-CSRF-Token` when present.
- CSRF retry must remove stale manual Cookie headers and stale `X-CSRF-Token` headers case-insensitively, clear the token cache, refresh the token, then retry the original request once.

### 4. Validation & Error Matrix
- `extra['skipCsrf'] == true` -> do not inject CSRF headers.
- Missing token for `/api/content/*` -> call `updateCsrfToken()` before sending.
- 403 body contains `BAD CSRF` or `csrf check error` -> refresh and retry once.
- Retry also fails -> propagate the original Dio error path; do not loop.

### 5. Good/Base/Bad Cases
- Good: A reply request carries both static challenge and dynamic token after login/session sync.
- Base: Non-content write APIs still get the static challenge.
- Bad: A reply request only sends `x-csrf-challenge` after the server starts requiring the dynamic token.

### 6. Tests Required
- Header injection test for static challenge and dynamic token when practical.
- Regression test or targeted manual verification for reply/comment writes.
- Error parsing test when adding a new CSRF response shape.

### 7. Wrong vs Correct

#### Wrong
```dart
options.headers['x-csrf-challenge'] = 'simple-token';
```

#### Correct
```dart
options.headers['x-csrf-challenge'] = 'simple-token';
final csrfToken = csrfTokenService.csrfToken;
if (csrfToken != null && csrfToken.isNotEmpty) {
  options.headers['X-CSRF-Token'] = csrfToken;
}
```

## Example Anchors

- `lib/services/network/cookie/app_cookie_manager.dart`
- `lib/services/network/cookie/boundary_sync_service.dart`
- `lib/services/network/cookie/raw_set_cookie_queue.dart`
- `lib/services/network/interceptors/cf_challenge_interceptor.dart`
- `test/services/network/cookie/app_cookie_manager_test.dart`
