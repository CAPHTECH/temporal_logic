# temporal_logic_mtl

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- [![pub package](https://img.shields.io/pub/v/temporal_logic_mtl.svg)](https://pub.dev/packages/temporal_logic_mtl) -->
<!-- [![Build Status](...)](...) -->

This package provides support for **Metric Temporal Logic (MTL)**, allowing you to specify and evaluate properties of timed sequences (traces) with quantitative time constraints.

It builds upon the foundation laid by the `temporal_logic_core` package.

## Features

*   **Time Intervals:** Define precise time bounds using the `TimeInterval` class (e.g., `TimeInterval(Duration(seconds: 2), Duration(seconds: 5))`). Includes helpers like `TimeInterval.exactly()`, `TimeInterval.upTo()`, `TimeInterval.atLeast()`.
*   **MTL Operators:** Introduces timed versions of standard temporal operators:
    *   `EventuallyTimed` (F<sub>I</sub>): Asserts that a property holds *eventually* within a specific time interval `I`.
    *   `AlwaysTimed` (G<sub>I</sub>): Asserts that a property holds *always* throughout a specific time interval `I`.
    *   `UntilTimed` (U<sub>I</sub>): Asserts that one property holds *until* another becomes true, with the transition occurring within a time interval `I`.
*   **Unified Evaluation:** Provides the `evaluateMtlTrace` function which can evaluate both standard LTL formulas (from `temporal_logic_core`) and MTL formulas against a timed `Trace`.

## Getting Started

Add this package along with `temporal_logic_core` to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  temporal_logic_core: ^0.1.0 # Or latest version
  temporal_logic_mtl: ^0.1.0 # Use the latest version from pub.dev
```

Then run `flutter pub get` or `dart pub get`.

## Usage

Here's an example of defining an MTL specification and evaluating it:

```dart
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';

void main() {
  // Define propositions
  final request = state<String>((s) => s == 'request', name: 'request');
  final response = state<String>((s) => s == 'response', name: 'response');

  // Define an MTL formula: Always, if a request occurs,
  // then a response must occur within 3 to 5 time units (inclusive).
  // G (request -> F_[3ms, 5ms](response))
  final spec = always(
    request.implies(
      EventuallyTimed(
        response,
        TimeInterval(Duration(milliseconds: 3), Duration(milliseconds: 5)),
      ),
    ),
  );

  // Create a trace with explicit timestamps
  final trace1 = Trace([
    TraceEvent(timestamp: Duration(milliseconds: 0), value: 'idle'),
    TraceEvent(timestamp: Duration(milliseconds: 1), value: 'request'), // Request at 1ms
    TraceEvent(timestamp: Duration(milliseconds: 2), value: 'processing'),
    TraceEvent(timestamp: Duration(milliseconds: 5), value: 'response'), // Response at 5ms (5-1 = 4ms, which is in [3, 5])
    TraceEvent(timestamp: Duration(milliseconds: 6), value: 'idle'),
  ]);

  final trace2 = Trace([
    TraceEvent(timestamp: Duration(milliseconds: 0), value: 'idle'),
    TraceEvent(timestamp: Duration(milliseconds: 1), value: 'request'), // Request at 1ms
    TraceEvent(timestamp: Duration(milliseconds: 2), value: 'processing'),
    TraceEvent(timestamp: Duration(milliseconds: 7), value: 'response'), // Response at 7ms (7-1 = 6ms, which is NOT in [3, 5])
    TraceEvent(timestamp: Duration(milliseconds: 8), value: 'idle'),
  ]);

  // Evaluate using evaluateMtlTrace
  final result1 = evaluateMtlTrace(trace1, spec);
  final result2 = evaluateMtlTrace(trace2, spec);

  print('Trace 1 satisfies "$spec": ${result1.holds}'); // Output: true
  print('Trace 2 satisfies "$spec": ${result2.holds}'); // Output: false
  print('Reason for Trace 2 failure: ${result2.reason}');
  // Example output might be related to the F_[3ms, 5ms](response) part failing at index 1
}
```

## Additional Information

*   **Evaluation Semantics:** The evaluation follows standard MTL semantics over timed traces.
*   **LTL Compatibility:** `evaluateMtlTrace` can also evaluate standard LTL formulas from `temporal_logic_core`. If an LTL formula is provided, it effectively ignores the precise timestamps and operates based on the sequence ordering (similar to `evaluateLtl`).
*   **Infinite Intervals:** Intervals like `[t, inf)` created with `TimeInterval.atLeast()` use a large finite duration internally. True handling of infinite intervals might be added in future versions.

See the `examples/snackbar_mtl` directory in the main repository for a Flutter-specific usage scenario. 
