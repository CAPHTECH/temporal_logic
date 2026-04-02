# Publish Dry-Run Report

**Date**: 2026-04-02
**Scope**: `packages/temporal_logic_core`, `packages/temporal_logic_mtl`, `packages/temporal_logic_flutter`

## Commands

- `mise exec -- flutter pub publish --dry-run` in `packages/temporal_logic_core`
- `mise exec -- flutter pub publish --dry-run` in `packages/temporal_logic_mtl`
- `mise exec -- flutter pub publish --dry-run` in `packages/temporal_logic_flutter`

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

- Dry-run failed with 3 package validation errors.
- Errors reported by pub:
  - `lib/src/stream_trace_checker_base.dart` imports `package:meta/meta.dart`, but `meta` is not declared in `dependencies`.
  - `lib/src/formula_stream_checker_base.dart` imports `package:meta/meta.dart`, but `meta` is not declared in `dependencies`.
  - `lib/src/matchers.dart` imports `package:flutter_test/flutter_test.dart`, but `flutter_test` is only in `dev_dependencies`.
- Pub ended with: `Sorry, your package is missing some requirements and can't be published yet.`

## Notes

- `temporal_logic_core` and `temporal_logic_mtl` are publish-ready from the dry-run perspective.
- `temporal_logic_flutter` is not publish-ready yet because its library code depends on packages that are not declared for publication.
