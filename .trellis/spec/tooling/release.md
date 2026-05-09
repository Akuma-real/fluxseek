# Release And Quality Gates

## Quality Commands

- `just analyze` for static analysis.
- `just test` for all tests.
- `just test -- <path>` for focused regression tests.
- `just release-check` for pre-release checks.

## Build Commands

- Linux dev run: `just run -- -d linux`
- Android dev run: `just run -- -d android --dart-define=cronetHttpNoPlay=true`
- Android release APK: `just build -- apk --release --target-platform android-arm64`
- Full release workflow: `just release` or `just prerelease`

## Release Scripts

- `tool/release.dart` controls release/prerelease flow.
- `tool/project_tasks.dart` contains higher-level app and native task orchestration.
- `tool/project_prep.dart` checks environment, l10n generation, and Android signing state.

## Rules

- Prefer focused tests for narrow service/parser fixes, then `just analyze`.
- Run Android APK build when changing Android Kotlin, Gradle, native adapter dependencies, signing, or release scripts.
- Do not push or publish releases from an AI session unless the user explicitly asks.
- Keep generated build artifacts out of commits unless the project already tracks them.
