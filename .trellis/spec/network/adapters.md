# Network Adapters

## Dio Factory

`NodeSeekDio.create()` is the unified Dio construction point. It configures, in order:

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

Do not create a separate Dio stack for NodeSeek unless there is a clear reason and the interceptor contract is copied deliberately.

## Adapter Rules

- Platform selection lives in `lib/services/network/adapters/platform_adapter.dart`.
- Android normally uses native/Cronet-capable adapter behavior; WebView is a targeted fallback path, not the default for every request.
- Gateway URL rewriting happens inside `_GatewayAdapterWrapper` at transport time so interceptors continue seeing original NodeSeek URLs.
- Request-level flags such as `forceWebViewAdapter`, `skipWebViewAdapter`, `skipCfChallenge`, `skipCsrf`, and `isSilent` are part of the network contract. Search existing usage before adding or changing them.

## Verification

- Adapter behavior should have focused tests under `test/services/network/adapters/`.
- Cookie/interceptor changes should also run related cookie tests under `test/services/network/cookie/`.
- Use `just analyze` after touching adapter code because type errors often cross service boundaries.
