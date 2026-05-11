# Cookies 与 Cloudflare

## 事实来源

当前 cookie 架构记录在 `docs/cookie-sync-status.md`：

- `CookieJar` / `EnhancedPersistCookieJar` 是唯一持久化 cookie store。
- `BoundarySyncService` 只在登录或 Cloudflare 成功等边界同步。
- `RawSetCookieQueue` 保留原始 Set-Cookie headers，供后续 WebView flush。
- `AppCookieManager` 加载请求 cookies 并保存响应 Set-Cookie headers。
- `CsrfTokenService` 负责 CSRF token 管理。

## 规则

- 不要重新引入持续的 WebView-to-CookieJar 后台同步。
- 保留 host-only cookie 优先级；同 path 的重复 cookie 名应优先使用最新的可信 host-only session cookie。
- 除非调用显式 opt in，否则不要把 redirect response cookies 保存到目标域名。
- Cloudflare 检测必须使用 response headers 加 body 检查，不能只靠宽松关键字匹配。
- 手动 Cloudflare 验证后，同步一次 `cf_clearance`，并用新的 CookieJar 状态重试每个原始请求。
- 不要记录 cookie 值、tokens 或原始 secrets。长度、名称和 boolean 是否存在可以接受。
- 对 `/api/content/` 下的 NodeSeek 内容写入 APIs，发送 `x-csrf-challenge: simple-token`，并在可用时包含已存储的 `X-CSRF-Token`。如果内容写入尚无 token，dispatch 前通过 `CsrfTokenService.updateCsrfToken()` 刷新；遇到 BAD CSRF / `csrf check error` 时，不区分大小写移除任何过期 `X-CSRF-Token` header，清除 token cache，并在重试前刷新一次。

## 场景：NodeSeek 内容写入 CSRF

### 1. 范围 / 触发
- 触发：通过 NodeSeek 内容 APIs 创建、编辑或回复，例如 `/api/content/new-comment`、`/api/content/new-discussion` 或 `/api/content/edit-comment`。

### 2. 签名
- Request interceptor：`RequestHeaderInterceptor.onRequest(RequestOptions, RequestInterceptorHandler)`。
- Token owner：`CsrfTokenService.csrfToken`、`updateCsrfToken()` 和 `clearCsrfToken()`。
- Retry hook：NodeSeek client auth interceptor 对 403 CSRF/high-risk responses 处理一次。

### 3. 契约
- 除非 `extra['skipCsrf'] == true`，每个非 GET 都保留 `x-csrf-challenge: simple-token`。
- `/api/content/*` 写入在 dispatch 前刷新缺失的动态 token，并在存在时包含 `X-CSRF-Token`。
- CSRF retry 必须不区分大小写移除过期手动 Cookie headers 和过期 `X-CSRF-Token` headers，清除 token cache，刷新 token，然后重试原始请求一次。

### 4. 验证与错误矩阵
- `extra['skipCsrf'] == true` -> 不注入 CSRF headers。
- `/api/content/*` 缺少 token -> 发送前调用 `updateCsrfToken()`。
- 403 body 包含 `BAD CSRF` 或 `csrf check error` -> 刷新并重试一次。
- 重试也失败 -> 传播原始 Dio error 路径；不要循环。

### 5. Good/Base/Bad 案例
- Good：登录/session 同步后，回复请求同时携带 static challenge 和 dynamic token。
- Base：非内容写入 APIs 仍获得 static challenge。
- Bad：服务器开始要求 dynamic token 后，回复请求只发送 `x-csrf-challenge`。

### 6. 必需测试
- 可行时，为 static challenge 和 dynamic token 增加 header 注入测试。
- 为 reply/comment 写入增加回归测试或定向手动验证。
- 新增 CSRF response shape 时增加错误解析测试。

### 7. 错误 vs 正确

#### 错误
```dart
options.headers['x-csrf-challenge'] = 'simple-token';
```

#### 正确
```dart
options.headers['x-csrf-challenge'] = 'simple-token';
final csrfToken = csrfTokenService.csrfToken;
if (csrfToken != null && csrfToken.isNotEmpty) {
  options.headers['X-CSRF-Token'] = csrfToken;
}
```

## 示例锚点

- `lib/services/network/cookie/app_cookie_manager.dart`
- `lib/services/network/cookie/boundary_sync_service.dart`
- `lib/services/network/cookie/raw_set_cookie_queue.dart`
- `lib/services/network/interceptors/cf_challenge_interceptor.dart`
- `test/services/network/cookie/app_cookie_manager_test.dart`
