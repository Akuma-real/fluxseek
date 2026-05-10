# Fix Failed Beta Release Action

## Goal

Fix the failed GitHub Actions `Build and Release` run for the beta release by aligning CI with the Flutter/Dart SDK required by the repository after the dependency upgrade.

## Evidence

- Failed run: `25625944564`
- Workflow: `Build and Release`
- Trigger: tag `v0.1.0-beta.12`
- Failed jobs: all Android matrix builds (`arm64-v8a`, `armeabi-v7a`, `x86_64`)
- Failure: CI used Flutter `3.38.9` / Dart `3.10.8`, but `pubspec.yaml` requires Dart SDK `^3.11.5`.

## Requirements

- Update GitHub Actions release workflow to use the Flutter SDK version locked by `.fvmrc`.
- Update stale project documentation/spec references that still mention the old Flutter SDK version.
- Verify the workflow configuration no longer references Flutter `3.38.9`.
- Run local checks that cover release preparation after the change.
- Push the fix and trigger a beta release workflow again.

## Acceptance Criteria

- [x] `.github/workflows/build.yaml` uses Flutter `3.41.9`.
- [x] Stale docs/spec references to Flutter `3.38.9` are updated or removed.
- [x] `just release-check` passes locally.
- [x] A new GitHub Actions release run reaches success.

## Resolution

- Fixed `.github/workflows/build.yaml` to use Flutter `3.41.9`.
- Updated stale Flutter SDK references in `README.md` and `.trellis/spec/app/architecture.md`.
- `just release-check` passed locally.
- Published `v0.1.0-beta.13`; GitHub Actions run `25626213250` completed successfully and created the prerelease with all three APKs plus SHA256 assets.

## Out of Scope

- Changing dependency versions again.
- Reworking the release workflow beyond the SDK mismatch fix.
