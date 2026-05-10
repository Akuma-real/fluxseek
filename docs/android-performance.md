# Android performance workflow

FluxSeek is developed on Linux, but Android is the release target. Use Linux
debug runs for iteration only; performance decisions should come from Android
profile/release measurements.

## Daily measurement commands

Run Android profile mode when checking runtime smoothness:

```bash
just run -- -d android --profile --dart-define=cronetHttpNoPlay=true
```

Build the normal arm64 release APK:

```bash
just build -- apk --release --target-platform android-arm64
```

Build and inspect release size:

```bash
just build -- apk --release --target-platform android-arm64 --analyze-size
```

For symbolized release crash analysis, keep split debug info outside the repo:

```bash
just build -- apk --release --target-platform android-arm64 --obfuscate --split-debug-info="$HOME/.fluxseek-symbols/android"
```

## What to measure

* Cold start to first usable topic list.
* Opening a representative long topic detail page.
* Scrolling the same long topic for jank in DevTools frame charts.
* APK size after dependency, resource, or Android build changes.
* Network path choice: WebView adapter should be reserved for requests that
  need browser TLS/Cookie behavior.

## Current APK size hotspots

The arm64 release APK after removing the bundled MiSans font, limiting
syntax-highlighting languages, replacing the `flutter_avif` umbrella package,
and pruning Android-unused web worker assets is about 46.5 MB in Flutter output,
45 MB on disk, and 44 MB total compressed in Flutter size analysis. The largest
remaining entries are:

* `lib/arm64-v8a/libapp.so` - about 22.6 MB.
* `lib/arm64-v8a/libflutter.so` - about 11.3 MB.
* `classes.dex` plus `classes2.dex` - about 3.1 MB compressed in size analysis.
* `lib/arm64-v8a/libflutter_avif.so` - about 3.3 MB.
* Web-only package assets from `flutter_inappwebview_web` and `wakelock_plus`
  still add a small amount of asset weight.
* Dart AOT decompressed symbols are about 22 MB; `re_highlight` dropped from
  about 2 MB to about 635 KB after replacing `languages/all.dart` with a
  common-language whitelist.

Gradle `packaging.resources.excludes` does not remove Flutter assets from the
APK. Release/profile builds therefore run an Android-only Flutter asset pruning
task for package-declared assets that are provably web-only on Android. It
currently removes `pro_image_editor`'s `lib/web/web_worker.dart.js` and source
map after Flutter merges assets but before Android compresses them. The
previous bundled `MiSans-Regular.ttf` asset was about 8.1 MB and has been
removed from the Android release package by dropping the user-selectable MiSans
option.

`flutter_avif` is intentionally not used as a root dependency. FluxSeek imports
`flutter_avif_platform_interface` directly and keeps only
`flutter_avif_android` / `flutter_avif_linux` as platform implementations. This
preserves Android native AVIF decoding through `libflutter_avif.so` while
avoiding the `flutter_avif_web` WASM/JS assets in Android APKs.

## Release build notes

* The Android Gradle config filters ABI according to `--target-platform`; use
  `android-arm64` for normal release checks.
* Release builds enable R8 minification and resource shrinking. If a plugin
  breaks after shrinking, add the narrowest keep rule to
  `android/app/proguard-rules.pro` and re-run the release APK build.
* After asset-pruning changes, verify absence with:
  ```bash
  unzip -l build/app/outputs/flutter-apk/app-release.apk | rg "flutter_avif_web|web_worker"
  ```
* Do not commit signing secrets, keystores, release APKs, or split-debug-info
  artifacts.
