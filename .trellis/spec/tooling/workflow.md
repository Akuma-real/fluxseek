# Development Workflow

## Workspace

The root `pubspec.yaml` uses Dart workspace members:

- `packages/ai_model_manager`
- `packages/enhanced_cookie_jar`
- `packages/extended_image_lite`
- `packages/pangutext`
- `packages/paper_shaders`

Use `dart run melos bootstrap` or `just bootstrap` to bootstrap workspace dependencies.

## Generated Code

- l10n source: `lib/l10n/modules/**/*.arb`
- l10n config: `slang.yaml`
- l10n generator: `tool/gen_l10n.dart`
- compatibility generator: `tool/gen_slang_compat.dart`

Rules:

- Run `just sync` after dependency or l10n changes.
- Run `just l10n-check` before finishing l10n work.
- Do not hand edit generated localization output.
- If updating `font_awesome_flutter`, run `dart run tool/gen_fa_name_mapping.dart` as noted in `pubspec.yaml`.
- `tool/gen_fa_name_mapping.dart` must support the current pub cache layout on Linux/macOS (`$HOME/.pub-cache`) and Windows (`%LOCALAPPDATA%\Pub\Cache`) when `PUB_CACHE` is unset.
- `font_awesome_flutter` 11.x exposes constants as `FaIconData`; generated CSS mappings should continue returning plain `IconData` for NodeSeek category/icon alias consumers that render through Flutter `Icon`.

## Flutter Wrapper

`tool/flutterw.dart` runs project prep before `run`, `build`, `drive`, and `test`. It also prepares native artifacts for Android/Linux targets through `tool/project_tasks.dart`.

Do not bypass `tool/flutterw.dart` for normal build/run/test workflows unless debugging the wrapper itself.

## Scenario: Wrapper-prepared Flutter commands

### 1. Scope / Trigger

- Trigger: changing `just` recipes, `tool/flutterw.dart`, or `tool/project_prep.dart`.
- Applies to commands that run Flutter after project prep: `run`, `build`, `drive`, and `test`.

### 2. Signatures

- `dart run tool/flutterw.dart <flutter-command> [flutter args...]`
- `just run -- -d linux`
- `just build -- apk --release --target-platform android-arm64`
- `just test`

### 3. Contracts

- `tool/flutterw.dart` must tolerate the optional `--` separator used by `just` varargs and must not pass that separator through to Flutter.
- After wrapper prep succeeds, Flutter commands that support pub control should receive `--no-pub` unless the user already passed `--pub`, `--no-pub`, `--help`, or `-h`.
- For `flutter build <target>`, insert `--no-pub` after `<target>`; `flutter build --no-pub apk` is invalid.
- For `run`, `drive`, and `test`, insert `--no-pub` after the Flutter command.

### 4. Validation & Error Matrix

- `just build -- apk ...` passes literal `--` to Flutter -> wrapper must strip it.
- `flutter build --no-pub apk ...` -> invalid; use `flutter build apk --no-pub ...`.
- User asks for help -> do not inject `--no-pub`; preserve help output behavior.

### 5. Good/Base/Bad Cases

- Good: `just build -- apk --release --target-platform android-arm64` runs `flutter build apk --no-pub --release --target-platform android-arm64`.
- Base: `dart run tool/flutterw.dart run -d linux` runs `flutter run --no-pub -d linux`.
- Bad: `flutter build -- apk ...` or `flutter build --no-pub apk ...`.

### 6. Tests Required

- For wrapper changes, run help/config-only smoke checks before full builds:
  - `dart run tool/flutterw.dart build -- apk --help`
  - `dart run tool/flutterw.dart run -- -d linux --help`
  - `dart run tool/flutterw.dart build -- apk --config-only --release --target-platform android-arm64`
- Run `just analyze`; run `just test` when behavior affects test prep.

### 7. Wrong vs Correct

#### Wrong

```bash
flutter build -- apk --release
flutter build --no-pub apk --release
```

#### Correct

```bash
flutter build apk --no-pub --release
```
