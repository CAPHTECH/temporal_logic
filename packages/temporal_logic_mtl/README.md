# temporal_logic_mtl

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- [![pub package](https://img.shields.io/pub/v/temporal_logic_mtl.svg)](https://pub.dev/packages/temporal_logic_mtl) -->
<!-- [![Build Status](...)](...) -->

`temporal_logic_mtl` adds Metric Temporal Logic (MTL) on top of `temporal_logic_core`.
It provides time-bounded operators and `evaluateMtlTrace` for evaluating `Trace<T>` values with explicit timing information.

## Features

* **Time intervals**: `TimeInterval`, `TimeInterval.exactly`, `TimeInterval.upTo`, `TimeInterval.atLeast`, `TimeInterval.always`
* **Timed operators**: `EventuallyTimed`, `AlwaysTimed`, `UntilTimed`, `ReleaseTimed`, `WeakUntilTimed`
* **Unified evaluation**: `evaluateMtlTrace` can evaluate both timed MTL formulas and pure LTL `Formula` values
* **Core re-exports**: also re-exports `Formula`, `Trace`, `TraceEvent`, `TimedValue`, `EvaluationResult`, and the LTL builder DSL

## Getting Started

Add `temporal_logic_core` and `temporal_logic_mtl` to `pubspec.yaml`.

```yaml
dependencies:
  temporal_logic_core: ^0.1.1
  temporal_logic_mtl: ^0.3.0
```

Then run `flutter pub get` or `dart pub get`.

## Usage

```dart
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';

void main() {
  final request = state<String>((s) => s == 'request', name: 'request');
  final response = state<String>((s) => s == 'response', name: 'response');

  final spec = always(
    request.implies(
      EventuallyTimed(
        response,
        TimeInterval(
          const Duration(milliseconds: 3),
          const Duration(milliseconds: 5),
        ),
      ),
    ),
  );

  final trace = Trace([
    TraceEvent(timestamp: const Duration(milliseconds: 0), value: 'idle'),
    TraceEvent(timestamp: const Duration(milliseconds: 1), value: 'request'),
    TraceEvent(timestamp: const Duration(milliseconds: 4), value: 'response'),
  ]);

  final result = evaluateMtlTrace(trace, spec);
  print(result.holds);
  print(result.reason);
}
```

## Notes

* `evaluateMtlTrace` evaluates formulas against timed traces.
* Pure LTL `Formula` values are also supported.
* Use `package:temporal_logic_mtl/temporal_logic_mtl.dart` as the supported entry point, and avoid importing from `src/` directly.
* The legacy helpers `checkEventuallyWithin`, `checkAlwaysWithin`, and `checkUntilWithin` were removed. Migration examples are documented in [MIGRATION.md](../../MIGRATION.md).
