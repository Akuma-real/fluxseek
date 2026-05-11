# Native Bridge

## MethodChannel 规则

Channel names 是稳定的 app 契约。现有示例：

- `com.akuma.fluxseek/browser`
- `com.akuma.fluxseek/crashlytics`
- `com.akuma.fluxseek/app_icon`
- `com.akuma.fluxseek/raw_cookie`
- `com.akuma.fluxseek/android_cdp`
- `com.akuma.fluxseek/webauthn`

新增或修改 channel 时：

- 保持 Android method names 和 Dart caller names 同步。
- 对可恢复失败，用 `result.error(...)` 返回结构化 error details。
- 将阻塞 IO 或 socket 工作移出 UI thread；现有 CDP methods 使用 `ioExecutor`。
- 避免在 logs 或 error payloads 中泄露 cookie/token 值。

## CDP Bridge

`AndroidCdpBridge` 与本地 WebView DevTools sockets 通信以执行 cookie 操作。它对 target discovery 和可重试 WebSocket disconnects 有明确 retry 行为。

规则：

- 保持 target selection 保守。`getCookies` 必须匹配 requested URLs；write/delete 操作需要 page target。
- 除非 tests 或设备证据证明需要变更，否则保留 retry limits 和 timeout behavior。
- 记录 operation metadata 和 counts，不记录 secret cookie values。

## 示例

- `android/app/src/main/kotlin/com/akuma/fluxseek/MainActivity.kt`
- `android/app/src/main/kotlin/com/akuma/fluxseek/AndroidCdpBridge.kt`
