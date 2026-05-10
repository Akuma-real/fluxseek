# Android Build And Release

## Build Configuration

`android/app/build.gradle.kts` owns Android build behavior:

- namespace/applicationId: `com.akuma.fluxseek`
- Java/Kotlin target: 17
- Firebase plugins are present, but Crashlytics is initialized lazily from user preference.
- Signing reads `android/key.properties`; if incomplete, debug/profile/release fall back to debug signing.
- ABI filtering follows Gradle `target-platform` to avoid bundling unused native libraries.
- Release builds enable R8 minification and resource shrinking; keep rules live in `android/app/proguard-rules.pro`.
- Release/profile builds prune Android-unused Flutter assets after merge and before compression.

## Rules

- Do not commit signing secrets or local keystores.
- Keep release/profile/debug signing fallback explicit and understandable.
- For Android release builds, prefer `just build -- apk --release --target-platform android-arm64` or the release scripts rather than raw Gradle.
- If changing native dependencies such as Cronet, WebKit, Firebase, or desugaring, verify Android build and document any required SDK/JDK changes.
- Do not depend on umbrella Flutter plugins when only Android/Linux implementations are needed and the umbrella package pulls web assets into Android APKs.
- `FluxseekApplication` intentionally disables WebView debugging early and initializes Firebase only when Crashlytics is enabled.

## Verification

- Static check: `just analyze`
- Focused tests: `just test -- <test path>`
- Android APK build when platform code changes: `just build -- apk --release --target-platform android-arm64`

## Scenario: Android release shrinking

### 1. Scope / Trigger

- Trigger: changing `android/app/build.gradle.kts`, `android/app/proguard-rules.pro`, Flutter plugins, Firebase, WebView, MethodChannel classes, or native dependency packaging.

### 2. Signatures

- Build command: `just build -- apk --release --target-platform android-arm64`
- Size command: `just build -- apk --release --target-platform android-arm64 --analyze-size`
- Proguard file: `android/app/proguard-rules.pro`

### 3. Contracts

- `release` build type must keep `isMinifyEnabled = true` and `isShrinkResources = true` unless a verified plugin break requires a temporary rollback.
- Keep rules should be as narrow as practical and documented in `proguard-rules.pro`.
- Optional Flutter embedding Play Core deferred-component references may be suppressed with `-dontwarn com.google.android.play.core...` because FluxSeek does not ship Android deferred components.
- Android-only Flutter asset pruning must run after `mergeReleaseAssets`/`mergeProfileAssets` and before `compressReleaseAssets` when that compression task exists.
- Prune only assets that are unreachable on Android by platform conditional imports or platform-specific code paths.
- Do not commit signing secrets, keystores, generated APKs, mapping files, or split debug info.

### 4. Validation & Error Matrix

- R8 missing optional class -> inspect `build/app/outputs/mapping/release/missing_rules.txt`, add the narrowest rule, rebuild.
- Plugin reflection/MethodChannel break after shrink -> add keep rules for the affected native class and verify the feature on Android.
- APK contains non-target ABI libraries -> verify `--target-platform` propagation and Gradle JNI excludes.
- Web-only Flutter assets remain in release APK -> do not use `packaging.resources.excludes`; prune merged Flutter assets or remove the dependency that declares them.
- Pruned asset is requested on Android at runtime -> revert that asset from the pruning list and replace the package-level strategy instead.

### 5. Good/Base/Bad Cases

- Good: release APK builds with R8/resource shrink and contains only `lib/arm64-v8a/**` for `android-arm64`.
- Good: Android APK contains `libflutter_avif.so` but not `flutter_avif_web` assets.
- Base: `--config-only` confirms Flutter/Gradle argument parsing before a full build.
- Base: debug builds may retain extra assets for diagnosis.
- Bad: disabling shrink permanently to avoid a missing-rule failure without documenting the actual optional dependency.
- Bad: using Gradle `packaging.resources.excludes` and assuming it removes Flutter assets from `assets/flutter_assets/**`.

### 6. Tests Required

- Run `just analyze`.
- Run `just test` for app/tooling changes unless the change is Android-only Gradle metadata.
- Run `just build -- apk --release --target-platform android-arm64`.
- Inspect APK native libs after ABI-related changes:
  ```bash
  unzip -l build/app/outputs/flutter-apk/app-release.apk | rg "lib/.+\\.so"
  ```
- Inspect web-only asset pruning after Flutter asset changes:
  ```bash
  unzip -l build/app/outputs/flutter-apk/app-release.apk | rg "flutter_avif_web|web_worker"
  ```

### 7. Wrong vs Correct

#### Wrong

```kotlin
release {
    isMinifyEnabled = false
}
```

#### Correct

```kotlin
release {
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles(
        getDefaultProguardFile("proguard-android-optimize.txt"),
        "proguard-rules.pro",
    )
}
```

#### Wrong

```kotlin
packaging {
    resources.excludes.add("assets/flutter_assets/packages/example/web/**")
}
```

#### Correct

```kotlin
tasks.register<Delete>("pruneReleaseAndroidOnlyFlutterAssets") {
    dependsOn("mergeReleaseAssets")
    mustRunAfter("mergeReleaseAssets")
    delete(layout.buildDirectory.file("intermediates/assets/release/mergeReleaseAssets/flutter_assets/packages/example/web/worker.js"))
}
```
