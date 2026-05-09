# Network And NodeSeek Guidelines

> 网络层是 fluxseek 的核心风险区，涉及 NodeSeek SSR/API 逆向、Cookie、Cloudflare challenge、WebView fallback 和平台 HTTP adapter。

## Pre-Development Checklist

- 改 NodeSeek API、SSR 解析或用户/话题/通知数据时读 [nodeseek.md](./nodeseek.md)。
- 改 Dio、adapter、proxy、gateway、request scheduler 时读 [adapters.md](./adapters.md)。
- 改 Cookie、登录、CSRF、Cloudflare、WebView 同步时读 [cookies-and-cloudflare.md](./cookies-and-cloudflare.md)。
- 涉及 Android CDP 或 MethodChannel 时同时读 `.trellis/spec/android/index.md`。
- 涉及 UI 状态或 provider 时同时读 `.trellis/spec/app/index.md`。
- 总是读 `.trellis/spec/guides/index.md`。

## Key Paths

| Area | Path |
| --- | --- |
| Dio factory | `lib/services/network/node_seek_dio.dart` |
| Network adapters | `lib/services/network/adapters/` |
| Interceptors | `lib/services/network/interceptors/` |
| Cookie services | `lib/services/network/cookie/` |
| NodeSeek service | `lib/services/nodeseek/` |
| Cookie architecture doc | `docs/cookie-sync-status.md` |
