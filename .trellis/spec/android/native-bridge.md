# Native Bridge

## MethodChannel Rules

Channel names are stable app contracts. Existing examples:

- `com.akuma.fluxseek/browser`
- `com.akuma.fluxseek/crashlytics`
- `com.akuma.fluxseek/app_icon`
- `com.akuma.fluxseek/raw_cookie`
- `com.akuma.fluxseek/android_cdp`
- `com.akuma.fluxseek/webauthn`

When adding or changing a channel:

- Keep Android method names and Dart caller names in sync.
- Return structured error details with `result.error(...)` for recoverable failures.
- Move blocking IO or socket work off the UI thread; existing CDP methods use `ioExecutor`.
- Avoid leaking cookie/token values into logs or error payloads.

## CDP Bridge

`AndroidCdpBridge` talks to local WebView DevTools sockets for cookie operations. It has explicit retry behavior for target discovery and retryable WebSocket disconnects.

Rules:

- Keep target selection conservative. `getCookies` must match requested URLs; write/delete operations require a page target.
- Preserve retry limits and timeout behavior unless tests or device evidence justify a change.
- Log operation metadata and counts, not secret cookie values.

## Examples

- `android/app/src/main/kotlin/com/akuma/fluxseek/MainActivity.kt`
- `android/app/src/main/kotlin/com/akuma/fluxseek/AndroidCdpBridge.kt`
