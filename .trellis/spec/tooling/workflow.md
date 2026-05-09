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

## Flutter Wrapper

`tool/flutterw.dart` runs project prep before `run`, `build`, `drive`, and `test`. It also prepares native artifacts for Android/Linux targets through `tool/project_tasks.dart`.

Do not bypass `tool/flutterw.dart` for normal build/run/test workflows unless debugging the wrapper itself.
