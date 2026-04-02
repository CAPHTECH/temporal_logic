# temporal_logic_core

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- [![pub package](https://img.shields.io/pub/v/temporal_logic_core.svg)](https://pub.dev/packages/temporal_logic_core) -->
<!-- [![Build Status](...)](...) -->

`temporal_logic_core` provides the shared foundation for propositional logic and Linear Temporal Logic (LTL).
It exports the AST, trace model, evaluation result types, and the main entry points such as `evaluateTrace` and `evaluateLtl`.

## Features

* **AST**: `Formula`, `AtomicProposition`, `Not`, `And`, `Or`, `Implies`, `Next`, `Always`, `Eventually`, `Until`, `WeakUntil`, `Release`
* **Trace model**: `Trace`, `TraceEvent`, `TimedValue`
* **Evaluation**: trace-based evaluation with `evaluateTrace` and a convenience LTL entry point with `evaluateLtl`
* **Result details**: `EvaluationResult` exposes `holds`, `reason`, `relatedIndex`, and `relatedTimestamp`
* **Builder DSL**: `state`, `event`, `next`, `always`, `eventually`, `until`, `weakUntil`, `release`

## Getting Started

Add the package to `pubspec.yaml`.

```yaml
dependencies:
  temporal_logic_core: ^0.1.1
```

Then run `flutter pub get` or `dart pub get`.

## Usage

```dart
import 'package:temporal_logic_core/temporal_logic_core.dart';

void main() {
  final isPositive = state<int>((s) => s > 0, name: 'isPositive');
  final isEven = state<int>((s) => s % 2 == 0, name: 'isEven');
  final formula = always(isPositive.implies(isEven));

  final trace = Trace.fromList([2, 4, 6, 7, 8]);
  final result = evaluateTrace(trace, formula);

  print(result.holds);
  print(result.reason);
  print(result.relatedIndex);
  print(result.relatedTimestamp);
}
```

`Trace.fromList` is convenient when you want to build a trace from an ordered sequence of values. If you need explicit timestamps, use `Trace([TraceEvent(...), ...])`.

## Notes

* `evaluateTrace` is the main entry point for evaluating formulas against traces.
* `evaluateLtl` is a convenience helper when you only want to evaluate a plain sequence of states.
* `EvaluationResult` is part of the public API.
* Use `package:temporal_logic_core/temporal_logic_core.dart` as the supported entry point, and avoid importing from `src/` directly.
