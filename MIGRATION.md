# Migration Guide

## 2026-04 Public API Cleanup

This repository now treats the package libraries as the supported public entry points.

Use these imports:

* `package:temporal_logic_core/temporal_logic_core.dart`
* `package:temporal_logic_mtl/temporal_logic_mtl.dart`
* `package:temporal_logic_flutter/temporal_logic_flutter.dart`
* `package:temporal_logic_flutter/temporal_logic_flutter_test.dart`

Do not import files from `src/` in application code. Those files are internal implementation details and may change during refactoring.

## Removed MTL Helper APIs

The following legacy helper functions were removed:

* `checkEventuallyWithin`
* `checkAlwaysWithin`
* `checkUntilWithin`

Use `evaluateMtlTrace` with timed formulas instead.

### `checkEventuallyWithin`

Before:

```dart
final holds = checkEventuallyWithin(trace, interval, response);
```

After:

```dart
final holds = evaluateMtlTrace(
  trace,
  EventuallyTimed(response, interval),
).holds;
```

### `checkAlwaysWithin`

Before:

```dart
final holds = checkAlwaysWithin(trace, interval, stable);
```

After:

```dart
final holds = evaluateMtlTrace(
  trace,
  AlwaysTimed(stable, interval),
).holds;
```

### `checkUntilWithin`

Before:

```dart
final holds = checkUntilWithin(trace, interval, waiting, ready);
```

After:

```dart
final holds = evaluateMtlTrace(
  trace,
  UntilTimed(waiting, ready, interval),
).holds;
```

## What Did Not Change

* `evaluateMtlTrace` remains the supported timed evaluation entry point.
* `EventuallyTimed`, `AlwaysTimed`, `UntilTimed`, `ReleaseTimed`, and `WeakUntilTimed` remain available from `package:temporal_logic_mtl/temporal_logic_mtl.dart`.
* `temporal_logic_flutter` continues to re-export the curated core and MTL surface along with Flutter-specific utilities.
