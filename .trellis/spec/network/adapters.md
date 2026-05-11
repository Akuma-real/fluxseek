# 网络 Adapters

## Dio Factory

`NodeSeekDio.create()` 是统一的 Dio 构造点。它按顺序配置：

1. platform adapter
2. session guard
3. request scheduler
4. cookie manager
5. Cronet fallback
6. retry interceptor
7. request headers / CSRF
8. redirect handling
9. error handling
10. Cloudflare challenge
11. network logging

除非有明确原因并且有意复制 interceptor 契约，否则不要为 NodeSeek 创建独立 Dio stack。

## Adapter 规则

- 平台选择位于 `lib/services/network/adapters/platform_adapter.dart`。
- Android 通常使用 native/Cronet-capable adapter 行为；WebView 是定向 fallback 路径，不是每个请求的默认路径。
- Gateway URL 重写在传输时发生于 `_GatewayAdapterWrapper` 内，因此 interceptors 仍然看到原始 NodeSeek URLs。
- `forceWebViewAdapter`、`skipWebViewAdapter`、`skipCfChallenge`、`skipCsrf` 和 `isSilent` 等请求级 flags 属于网络契约。新增或修改前先搜索现有用法。

## 验证

- Adapter 行为应在 `test/services/network/adapters/` 下有聚焦测试。
- Cookie/interceptor 变更还应运行 `test/services/network/cookie/` 下的相关 cookie 测试。
- 触及 adapter 代码后使用 `just analyze`，因为类型错误经常跨越 service 边界。
