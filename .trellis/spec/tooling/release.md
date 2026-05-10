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

## Version Rules

- Do not include manual `pubspec.yaml` version bumps in ordinary feature or fix commits.
- Keep feature/fix commits on the current checked-in version; the release script owns version changes.
- Use `just prerelease <target>` for beta releases and `just release <target>` for stable releases.
- `tool/release.dart` writes `pubspec.yaml` as `<releaseVersion>+<dateBuildCode>`, creates a dedicated `chore: bump version to <releaseVersion>` commit, and tags `v<releaseVersion>`.
- For example, after landing fixes on `0.1.0-beta.8+2026050923`, run `just prerelease next` to produce the next beta such as `0.1.0-beta.9+YYYYMMDDNN`.

## Rules

- Prefer focused tests for narrow service/parser fixes, then `just analyze`.
- Run Android APK build when changing Android Kotlin, Gradle, native adapter dependencies, signing, or release scripts.
- Do not push or publish releases from an AI session unless the user explicitly asks.
- Keep generated build artifacts out of commits unless the project already tracks them.
