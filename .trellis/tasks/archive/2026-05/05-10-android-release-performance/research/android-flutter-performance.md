# Android / Flutter performance research

## Official guidance summary

* Flutter performance work should be measured outside debug mode. Use profile mode for runtime profiling and release mode for final build behavior.
* Flutter supports release size analysis with `--analyze-size`.
* Flutter supports Dart symbol obfuscation with `--obfuscate` plus `--split-debug-info=<dir>`. The split debug info output must be kept outside normal source commits so release stack traces can be symbolized later.
* Flutter Android release builds can target specific ABIs through `--target-platform`; this project already maps that value to Gradle ABI filters and extra JNI excludes.
* Android release builds commonly use R8 code shrinking and resource shrinking for smaller APKs, but app-specific keep rules must be verified for reflection, WebView bridges, Firebase, and plugins.
* Android Baseline Profiles can improve startup and critical user journeys when generated for representative flows, but this is a separate instrumentation effort and should not block first-pass build/tooling wins.

## Project-specific implications

* The safest first pass is tooling and build configuration:
  * avoid redundant implicit pub resolution when the wrapper has already run pub get;
  * skip l10n generation when inputs and generator scripts are unchanged;
  * add documented profile/release/size-analysis commands;
  * evaluate R8/resource shrinking behind a verified Android release build;
  * add release debug-info output policy if obfuscation is enabled.
* Runtime work should be driven by measurement:
  * reduce verbose logging before profiling;
  * check `HtmlWidget` rebuilds on topic detail pages;
  * avoid forcing WebView adapter for requests that can safely use Dio/native adapters;
  * cache Linux/Android secure-storage fallback state after a backend is known unavailable.

## References

* Flutter docs: Performance best practices and profiling modes.
* Flutter docs: Build and release Android apps, app size analysis, obfuscation, and split debug info.
* Android Developers docs: Shrink, obfuscate, and optimize your app with R8.
* Android Developers docs: Baseline Profiles.
