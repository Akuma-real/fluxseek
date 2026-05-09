# Android Build And Release

## Build Configuration

`android/app/build.gradle.kts` owns Android build behavior:

- namespace/applicationId: `com.akuma.fluxseek`
- Java/Kotlin target: 17
- Firebase plugins are present, but Crashlytics is initialized lazily from user preference.
- Signing reads `android/key.properties`; if incomplete, debug/profile/release fall back to debug signing.
- ABI filtering follows Gradle `target-platform` to avoid bundling unused native libraries.

## Rules

- Do not commit signing secrets or local keystores.
- Keep release/profile/debug signing fallback explicit and understandable.
- For Android release builds, prefer `just build -- apk --release --target-platform android-arm64` or the release scripts rather than raw Gradle.
- If changing native dependencies such as Cronet, WebKit, Firebase, or desugaring, verify Android build and document any required SDK/JDK changes.
- `FluxseekApplication` intentionally disables WebView debugging early and initializes Firebase only when Crashlytics is enabled.

## Verification

- Static check: `just analyze`
- Focused tests: `just test -- <test path>`
- Android APK build when platform code changes: `just build -- apk --release --target-platform android-arm64`
