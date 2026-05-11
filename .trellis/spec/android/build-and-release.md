# Android 构建与发布

## 构建配置

`android/app/build.gradle.kts` 负责 Android build 行为：

- namespace/applicationId：`com.akuma.fluxseek`
- Java/Kotlin target：17
- Firebase plugins 已存在，但 Crashlytics 根据用户偏好延迟初始化。
- Signing 读取 `android/key.properties`；如果不完整，debug/profile/release fallback 到 debug signing。
- ABI filtering 跟随 Gradle `target-platform`，避免打包未使用 native libraries。
- Release builds 启用 R8 minification 和 resource shrinking；keep rules 位于 `android/app/proguard-rules.pro`。
- Release/profile builds 在 merge 后、compression 前裁剪 Android 未使用的 Flutter assets。
- 当 Flutter plugin 附带过时 Android Gradle script 时，根 `android/build.gradle.kts` 可以为 Android library subprojects 强制 `compileSdk`。

## 规则

- 不要 commit signing secrets 或本地 keystores。
- 保持 release/profile/debug signing fallback 明确且易理解。
- Android release builds 优先使用 `just build -- apk --release --target-platform android-arm64` 或发布脚本，而不是原始 Gradle。
- 如果修改 Cronet、WebKit、Firebase 或 desugaring 等 native dependencies，验证 Android build 并记录任何所需 SDK/JDK 变更。
- 不要仅因为 AGP 9.x 是最新 stable AGP 就把这个基于 plugin 的 Flutter app 升级到 AGP 9.x。Flutter 的 AGP 9 migration 需要 built-in Kotlin，且会破坏仍应用 `kotlin-android` 的项目；除非专门的 AGP 9 migration 在范围内，否则使用最新已验证 AGP 8.x 线。
- 如果 plugin subproject 因编译目标为旧 Android API 而导致 `checkReleaseAarMetadata` 失败，优先使用 root Gradle convention 更新 `com.android.library` subproject `compileSdk`，而不是 patch pub-cache 文件。
- 当只需要 Android/Linux implementations，且 umbrella package 会把 web assets 拉入 Android APK 时，不要依赖 umbrella Flutter plugins。
- `FluxseekApplication` 刻意较早禁用 WebView debugging，并仅在 Crashlytics 启用时初始化 Firebase。

## 验证

- 静态检查：`just analyze`
- 聚焦测试：`just test -- <test path>`
- 平台代码变更时的 Android APK build：`just build -- apk --release --target-platform android-arm64`

## 场景：Android 依赖升级兼容性

### 1. 范围 / 触发

- 触发：升级 AGP、Gradle、Kotlin、Firebase、AndroidX、desugaring，或带 Android native code 的 Flutter plugins。

### 2. 签名

- Build command：`just build -- apk --release --target-platform android-arm64`
- Root Android library override location：`android/build.gradle.kts`

### 3. 契约

- 除非任务明确迁移到 AGP 9 built-in Kotlin，否则将 AGP 保持在最新已验证 8.x 版本。
- 将 Gradle 保持在与所选 AGP 线兼容的最新版本。
- 应用 `com.android.library` 的 plugin subprojects 必须针对足够新的 API level 编译，以满足其 AndroidX dependencies。

### 4. 验证与错误矩阵

- `kotlin-android` 在 AGP 9 下失败 -> 回退到最新已验证 AGP 8.x，或执行完整 Flutter AGP 9 migration。
- `checkReleaseAarMetadata` 显示某 plugin 针对 `android-31` 编译而 AndroidX 要求 34+ -> 从 root Gradle 为 Android library subprojects 强制更新的 `compileSdk`。

### 5. Good/Base/Bad 案例

- Good：AGP 8.x + compatible Gradle 构建 release APK，并保持 plugin scripts 未修改。
- Base：仅 AndroidX version bumps 仍运行 release APK build。
- Bad：编辑 `.pub-cache` 内文件或 commit 本地 plugin symlink churn。

### 6. 必需测试

- 运行 `just analyze`。
- 除非变更是 Android-only metadata，否则运行 `just test`。
- 运行 `just build -- apk --release --target-platform android-arm64`。

### 7. 错误 vs 正确

#### 错误

```kotlin
// android/settings.gradle.kts
id("com.android.application") version "9.2.1" apply false
```

#### 正确

```kotlin
// Use latest verified AGP 8.x unless an AGP 9 migration is the task.
id("com.android.application") version "8.13.2" apply false
```

#### 正确

```kotlin
// android/build.gradle.kts
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            extensions.configure<com.android.build.api.dsl.LibraryExtension>("android") {
                compileSdk = 36
            }
        }
    }
}
```

## 场景：Android release shrinking

### 1. 范围 / 触发

- 触发：修改 `android/app/build.gradle.kts`、`android/app/proguard-rules.pro`、Flutter plugins、Firebase、WebView、MethodChannel classes 或 native dependency packaging。

### 2. 签名

- Build command：`just build -- apk --release --target-platform android-arm64`
- Size command：`just build -- apk --release --target-platform android-arm64 --analyze-size`
- Proguard file：`android/app/proguard-rules.pro`

### 3. 契约

- `release` build type 必须保持 `isMinifyEnabled = true` 和 `isShrinkResources = true`，除非已验证的 plugin break 需要临时回滚。
- Keep rules 应尽量窄，并记录在 `proguard-rules.pro` 中。
- 可选 Flutter embedding Play Core deferred-component references 可以用 `-dontwarn com.google.android.play.core...` suppress，因为 FluxSeek 不发布 Android deferred components。
- Android-only Flutter asset pruning 必须在 `mergeReleaseAssets`/`mergeProfileAssets` 之后运行，并在存在 compression task 时早于 `compressReleaseAssets`。
- 只裁剪 Android 上因 platform conditional imports 或 platform-specific code paths 不可达的 assets。
- 不要 commit signing secrets、keystores、生成的 APKs、mapping files 或 split debug info。

### 4. 验证与错误矩阵

- R8 缺少 optional class -> 检查 `build/app/outputs/mapping/release/missing_rules.txt`，添加最窄规则，重新构建。
- shrink 后 plugin reflection/MethodChannel break -> 为受影响 native class 添加 keep rules，并在 Android 上验证该功能。
- APK 包含非目标 ABI libraries -> 验证 `--target-platform` 传播和 Gradle JNI excludes。
- release APK 中仍有 Web-only Flutter assets -> 不要使用 `packaging.resources.excludes`；裁剪 merged Flutter assets 或移除声明它们的依赖。
- 被裁剪 asset 在 Android runtime 被请求 -> 从裁剪列表回退该 asset，并改用 package-level 策略。

### 5. Good/Base/Bad 案例

- Good：release APK 使用 R8/resource shrink 构建，并且针对 `android-arm64` 只包含 `lib/arm64-v8a/**`。
- Good：Android APK 包含 `libflutter_avif.so`，但不包含 `flutter_avif_web` assets。
- Base：完整 build 前用 `--config-only` 确认 Flutter/Gradle 参数解析。
- Base：debug builds 可以保留额外 assets 以便诊断。
- Bad：为避免 missing-rule failure 而永久关闭 shrink，且未记录实际 optional dependency。
- Bad：使用 Gradle `packaging.resources.excludes` 并假设它会从 `assets/flutter_assets/**` 移除 Flutter assets。

### 6. 必需测试

- 运行 `just analyze`。
- 对 app/tooling 变更运行 `just test`，除非变更是 Android-only Gradle metadata。
- 运行 `just build -- apk --release --target-platform android-arm64`。
- ABI 相关变更后检查 APK native libs：
  ```bash
  unzip -l build/app/outputs/flutter-apk/app-release.apk | rg "lib/.+\\.so"
  ```
- Flutter asset 变更后检查 web-only asset pruning：
  ```bash
  unzip -l build/app/outputs/flutter-apk/app-release.apk | rg "flutter_avif_web|web_worker"
  ```

### 7. 错误 vs 正确

#### 错误

```kotlin
release {
    isMinifyEnabled = false
}
```

#### 正确

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

#### 错误

```kotlin
packaging {
    resources.excludes.add("assets/flutter_assets/packages/example/web/**")
}
```

#### 正确

```kotlin
tasks.register<Delete>("pruneReleaseAndroidOnlyFlutterAssets") {
    dependsOn("mergeReleaseAssets")
    mustRunAfter("mergeReleaseAssets")
    delete(layout.buildDirectory.file("intermediates/assets/release/mergeReleaseAssets/flutter_assets/packages/example/web/worker.js"))
}
```
