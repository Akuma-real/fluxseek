# Android release performance optimization

## Goal

Optimize FluxSeek for the user's actual workflow: Linux is the development machine, Android is the formal release target, and performance work should prioritize release-user impact over Linux-only debug behavior. The work should produce measurable improvements or verified release settings for startup, navigation/detail rendering, network/WebView overhead, APK size, and developer iteration speed.

## What I already know

* User develops on Linux and ships Android release builds.
* Android is already documented as the formal release target; Linux is mainly for development and debugging.
* The reported Linux `just run -d linux` log shows repeated dependency resolution, project prep, verbose HTML renderer logging, WebView initialization, secure-storage fallback warnings, and repeated `HtmlWidget` body builds while opening topic detail pages.
* `tool/flutterw.dart` always runs `project_prep.dart app` before `run`, `build`, and `drive`.
* `project_prep.dart app` runs `ensurePubGet()` and then always runs l10n generation.
* `ensurePubGet()` has its own pubspec stamp, but the final `flutter run/build` can still invoke Flutter's implicit pub step unless `--no-pub` is passed.
* Android Gradle already filters ABI from `--target-platform` and excludes non-target `lib/<abi>/**` entries for native libraries.
* Android release/profile/debug signing intentionally falls back to debug signing if local release signing is incomplete.
* Android release build type currently only sets signing config; there is no explicit `isMinifyEnabled`, `isShrinkResources`, proguard rules file, baseline profile dependency, or Dart `--split-debug-info` wrapper policy.
* `FluxseekApplication` disables WebView debugging early and lazily initializes Firebase only after the user enables Crashlytics.

## Assumptions

* We should optimize the Android arm64 release path first because that is the normal modern production APK path in this repo.
* Linux debug smoothness is useful as a development signal, but it must not override Android profile/release measurements.
* "Extreme optimization" means applying high-value release-safe optimizations first, then validating with measurements, instead of risky broad rewrites or dependency churn.

## Requirements

* Add or refine tooling so Android release/profile performance can be measured repeatably from Linux.
* Reduce unnecessary development-loop overhead where it is clearly redundant and safe to skip.
* Ensure Android release builds use size/performance-oriented build settings where compatible with Flutter and current dependencies.
* Keep Android release behavior compatible with WebView, Cronet/native network adapters, Firebase, dynamic icons, OTA update, and generated Flutter artifacts.
* Identify and reduce runtime hotspots visible in the supplied log: HTML rendering churn, verbose logging, WebView adapter routing, and repeated secure-storage fallback paths.
* Do not treat package version upgrades as the primary optimization unless a specific upgrade is needed and verified.
* Preserve Trellis and project workflow rules: use `just`/`tool/` wrappers, avoid committing signing secrets, and verify with repo quality gates.

## Acceptance Criteria

* [ ] A documented Android performance workflow exists for Linux development, including at least profile run, release APK build, and size analysis commands.
* [ ] `just build -- apk --release --target-platform android-arm64` still works after changes.
* [ ] `just analyze` passes.
* [ ] Any changed app code has focused tests where practical, or an explicit rationale if the optimization is build/tooling-only.
* [ ] Android release packaging is verified for ABI filtering and no unintended debug-only behavior.
* [ ] Runtime logging is not excessively verbose in normal debug/profile usage unless explicitly enabled.
* [ ] Topic detail / HTML rendering changes, if implemented, are validated on a representative long topic or by targeted tests.

## Definition of Done

* Requirements above are implemented or explicitly split into follow-up tasks.
* Quality gates pass: `just analyze`, focused tests as applicable, and Android release APK build.
* Measurements or command output are recorded in this task or the final response.
* Any newly discovered project convention is captured in `.trellis/spec/` if it should guide future sessions.

## Out of Scope

* Full dependency major-version upgrade sweep.
* Publishing a release, pushing tags, or uploading artifacts.
* Linux-only rendering fixes that do not affect Android or developer measurement quality.
* Replacing the network stack or HTML rendering library wholesale without separate design.

## Technical Notes

* Relevant specs: `.trellis/spec/android/build-and-release.md`, `.trellis/spec/app/architecture.md`, `.trellis/spec/tooling/workflow.md`, `.trellis/spec/tooling/release.md`.
* Key tooling files: `justfile`, `tool/flutterw.dart`, `tool/project_prep.dart`, `tool/project_tasks.dart`, `tool/_workspace_cli.dart`.
* Key Android files: `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/akuma/fluxseek/FluxseekApplication.kt`, `android/gradle.properties`.
* Key runtime areas from the log: `lib/main.dart`, `lib/widgets/content/html_content/html_content_widget.dart`, `lib/widgets/content/html_content/chunked/html_chunker.dart`, `lib/services/network/adapters/platform_adapter.dart`, `lib/services/network/adapters/webview_http_adapter.dart`, `lib/services/storage/resilient_secure_storage.dart`, `packages/ai_model_manager/lib/services/resilient_secure_storage.dart`.
