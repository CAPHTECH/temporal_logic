# Publish Dry-Run Report

**Date**: 2026-04-02
**Scope**: `packages/temporal_logic_core`, `packages/temporal_logic_mtl`, `packages/temporal_logic_flutter`

## Commands

- `mise exec -- flutter pub publish --dry-run` in `packages/temporal_logic_core`
- `mise exec -- flutter pub publish --dry-run` in `packages/temporal_logic_mtl`
- `mise exec -- flutter pub publish --dry-run` in `packages/temporal_logic_flutter`
- `/Users/rizumita/.local/share/mise/installs/flutter/3.41.5-stable/bin/flutter pub publish --dry-run` in a temporary clean copy of `packages/temporal_logic_flutter`

## Results

### `temporal_logic_core`

- Dry-run completed successfully.
- Pub reported `Package has 0 warnings.`
- The package archive includes `lib/internal/evaluator_common.dart`, `lib/src/*`, tests, README, CHANGELOG, and LICENSE.

### `temporal_logic_mtl`

- Dry-run completed successfully.
- Pub reported `Package has 0 warnings.`
- The package archive includes `lib/src/*`, tests, README, CHANGELOG, and LICENSE.

### `temporal_logic_flutter`

- Package-level publish blockers were resolved.
- Direct dry-run in the working tree reported one warning because the package files were modified in git:
  - `lib/src/matchers.dart`
  - `pubspec.yaml`
- Dry-run in a temporary clean copy completed successfully.
- Pub reported `Package has 0 warnings.` for the clean-copy validation run.

## Notes

- `temporal_logic_core` and `temporal_logic_mtl` are publish-ready from the dry-run perspective.
- `temporal_logic_flutter` is also publish-ready from the dry-run perspective after adding `meta` and `matcher` to `dependencies` and removing the `flutter_test` import from library code.
- The working-tree warning for `temporal_logic_flutter` disappears once the current changes are committed.
