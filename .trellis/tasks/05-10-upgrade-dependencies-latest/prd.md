# Upgrade All Dependencies To Latest

## Goal

Upgrade the project's dependencies to current versions while preserving the ability to build and validate the Flutter app, with Android treated as the release target and Linux as the development target.

## What I Already Know

* The repo is a Flutter/Dart workspace using the root `pubspec.yaml` plus local packages under `packages/*`.
* Direct Dart dependencies are declared in the root app and local package pubspecs, with workspace resolution enabled for local packages.
* Android build dependencies are declared in `android/settings.gradle.kts`, `android/app/build.gradle.kts`, and `android/gradle/wrapper/gradle-wrapper.properties`.
* Project tooling guidance says dependency, workspace, and generated-code workflows should use `just` wrappers where appropriate.
* Current SDKs on this machine: Flutter 3.41.9 stable and Dart 3.11.5.
* `dart pub outdated --json` reports several direct Dart packages with newer resolvable versions, including `anthropic_sdk_dart`, `connectivity_plus`, `file_picker`, `flutter_secure_storage`, `font_awesome_flutter`, `googleai_dart`, `openai_dart`, `pro_image_editor`, and `melos`.
* Android metadata checked on 2026-05-10 shows newer versions for Gradle, Android Gradle Plugin, Kotlin plugin, Google Services plugin, Firebase Crashlytics plugin, Firebase BoM, desugar JDK libs, AndroidX WebKit, and `org.json:json`.

## Assumptions

* "Latest" means latest stable release where stable is available, not preview-only alpha/beta/RC releases, unless the project is already using a prerelease dependency or no stable release exists.
* Direct dependencies should be upgraded through manifest constraints and lockfile resolution; transitive dependencies should move through the resolver rather than being pinned manually unless a conflict requires it.
* If a latest version is not resolvable under Flutter 3.41.9 / Dart 3.11.5, document the blocker and use the newest resolvable version unless the user explicitly wants broader SDK/toolchain changes.
* Existing local path packages remain local path packages.

## Open Questions

* None.

## Requirements

* Use the confirmed target: latest stable/resolvable versions under current Flutter 3.41.9 / Dart 3.11.5.
* Allow major dependency upgrades, but do not move the project to alpha/beta/RC package versions or Flutter beta/master solely to chase preview releases.
* Upgrade Dart/Flutter direct dependencies in the root app and local workspace packages.
* Refresh `pubspec.lock` files affected by the upgrade.
* Upgrade Android build/runtime dependency versions where compatible with the current Flutter stable toolchain.
* Preserve existing comments that encode required follow-up steps, such as validating `slang` code generation and regenerating Font Awesome mappings when needed.
* Run project sync and validation commands after upgrades.
* Fix compile/analyze/test failures caused by dependency API changes when reasonably scoped to this task.
* Record any dependency that cannot be upgraded to the absolute latest and explain why.

## Acceptance Criteria

* [x] `dart pub outdated` no longer reports direct dependencies behind the selected upgrade target, except documented blockers.
* [x] `just sync` completes.
* [x] `just analyze` completes.
* [x] `just test` completes, or any failure is unrelated and explicitly documented.
* [x] Android build dependency changes are validated at least by Gradle/Flutter dependency resolution; release APK build is attempted if practical.
* [x] Lockfiles are updated consistently.

## Definition of Done

* Tests and analysis pass or documented blockers are clear.
* Dependency manifests and lockfiles are updated.
* Any necessary generated files are refreshed.
* Rollback risk is clear from the changed files and validation output.

## Out of Scope

* Replacing packages with alternatives.
* Migrating the app to Flutter beta/master solely to satisfy preview dependency versions.
* Large feature rewrites unrelated to dependency API compatibility.
* Publishing releases or pushing commits.

## Technical Notes

* User confirmed the upgrade policy on 2026-05-10: upgrade to the latest stable/resolvable versions under the current stable Flutter/Dart toolchain, allow major upgrades, and document blockers instead of switching to preview toolchains.
* Validation completed:
  * `just sync` passed.
  * `just analyze` passed.
  * `just test` passed.
  * `just build -- apk --release --target-platform android-arm64` passed and produced `build/app/outputs/flutter-apk/app-release.apk`.
* Documented latest-version blockers after final `flutter pub outdated --json`:
  * `chewie 1.14.0` requires `wakelock_plus ^1.6.0`, which requires `package_info_plus ^10.0.0`; `package_info_plus 10.x` conflicts with `dart_console ^4.1.4` through `win32 ^6.0.1` vs `<6.0.0`.
  * `device_info_plus 13.1.0`, `package_info_plus 10.1.0`, and `share_plus 13.1.0` each require `win32 ^6.0.1`, conflicting with current `dart_console ^4.1.4`.
  * `test 1.31.1` requires `test_api 0.7.12`, but current Flutter SDK `flutter_test` pins `test_api 0.7.10`.
  * `meta 1.18.2` and `vector_math 2.3.0` are blocked by current Flutter SDK pins from `flutter_test`.
  * AGP 9.x was attempted and rejected because Flutter/AGP 9 built-in Kotlin migration currently blocks this plugin-based app; latest compatible stable used here is AGP 8.13.2 with Gradle 8.14.5.
* Relevant specs:
  * `.trellis/spec/guides/index.md`
  * `.trellis/spec/tooling/index.md`
  * `.trellis/spec/app/index.md`
  * `.trellis/spec/android/index.md`
  * `.trellis/spec/network/index.md`
* Relevant manifests:
  * `pubspec.yaml`
  * `packages/ai_model_manager/pubspec.yaml`
  * `packages/enhanced_cookie_jar/pubspec.yaml`
  * `packages/extended_image_lite/pubspec.yaml`
  * `packages/flutter_inappwebview_linux/pubspec.yaml`
  * `packages/pangutext/pubspec.yaml`
  * `packages/paper_shaders/pubspec.yaml`
  * `android/settings.gradle.kts`
  * `android/app/build.gradle.kts`
  * `android/gradle/wrapper/gradle-wrapper.properties`
* Current notable Android latest metadata:
  * Gradle wrapper: current stable `9.5.0` from `https://services.gradle.org/versions/current`.
  * Android Gradle Plugin: metadata latest includes preview `9.3.0-alpha04`; latest stable-looking release in metadata is `9.2.1`.
  * Kotlin Android plugin: metadata latest is `2.4.0-Beta2`; latest stable-looking release in metadata is `2.3.21`.
  * Google Services plugin: `4.4.4`.
  * Firebase Crashlytics Gradle plugin: `3.0.7`.
  * Firebase BoM: `34.13.0`.
  * desugar JDK libs: `2.1.5`.
  * AndroidX WebKit: `1.16.0`.
  * `org.json:json`: `20251224`.
