# Android 平台指南

> Android 是正式发布目标。原生 Kotlin、Gradle、签名、WebView/CDP、Crashlytics 都属于这个层。

## 开发前检查清单

- 改 MethodChannel、CDP、WebView、App Links、动态图标时读 [native-bridge.md](./native-bridge.md)。
- 改 Gradle、签名、ABI、Manifest、Firebase 时读 [build-and-release.md](./build-and-release.md)。
- 涉及 Flutter 调用端时同时读 `.trellis/spec/app/index.md`。
- 涉及 Cookie/CDP/Cloudflare 时同时读 `.trellis/spec/network/index.md`。
- 总是读 `.trellis/spec/guides/index.md`。

## 关键路径

| 区域 | 路径 |
| --- | --- |
| Main activity channels | `android/app/src/main/kotlin/com/akuma/fluxseek/MainActivity.kt` |
| Android CDP bridge | `android/app/src/main/kotlin/com/akuma/fluxseek/AndroidCdpBridge.kt` |
| Application bootstrap | `android/app/src/main/kotlin/com/akuma/fluxseek/FluxseekApplication.kt` |
| Gradle app 配置 | `android/app/build.gradle.kts` |
| Manifest | `android/app/src/main/AndroidManifest.xml` |
| Network security 配置 | `android/app/src/main/res/xml/network_security_config.xml` |
