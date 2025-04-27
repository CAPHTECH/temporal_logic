# temporal_logic_core

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- [![pub package](https://img.shields.io/pub/v/temporal_logic_core.svg)](https://pub.dev/packages/temporal_logic_core) -->
<!-- [![Build Status](...)](...) -->

This package provides the core data structures, interfaces, and evaluation logic for propositional logic and Linear Temporal Logic (LTL). It forms the foundation for other temporal logic packages in this repository.

## Features

* **Abstract Syntax Tree (AST):** Defines classes like `Formula`, `AtomicProposition`, `And`, `Or`, `Not`, `Implies` for basic logical connectives, and LTL operators like `Next`, `Always` (Globally), `Eventually` (Finally), `Until`, `WeakUntil`, and `Release`.
* **Timed Traces:** Represents sequences of events or states using `Trace` and `TraceEvent`, incorporating `Duration` timestamps.
* **LTL Evaluation:** Provides the `evaluateTrace` function to check if a `Trace` satisfies a given LTL `Formula`.
* **Evaluation Results:** Returns detailed `EvaluationResult` objects, indicating success or failure with optional reasons and timestamps/indices.
* **Formula Building:** Includes basic helpers like the `LogicalConnectives` extension (`and`, `or`, `implies`, `not`).

## Getting Started

Add this package to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  temporal_logic_core: ^0.1.0 # Use the latest version from pub.dev
```

Then run `flutter pub get` or `dart pub get`.

## Usage

Here's a basic example of defining an LTL formula and evaluating it on a simple trace:

```dart
import 'package:temporal_logic_core/temporal_logic_core.dart';

void main() {
  // Define atomic propositions using builder functions
  // state<T>(predicate, {name}) creates an AtomicProposition<T>
  final isPositive = state<int>((s) => s > 0, name: 'isPositive');
  final isEven = state<int>((s) => s % 2 == 0, name: 'isEven');

  // Build an LTL formula using builder functions and extension methods:
  // "Always (Globally), if a state is positive, it must also be even."
  // G (isPositive -> isEven)
  final formula = always(isPositive.implies(isEven));

  // You could also write:
  // final formula = always(implies(isPositive, isEven));
  // Or using constructors directly:
  // final formula = Always(Implies(isPositive, isEven));

  // Create a trace from a list (timestamps are assigned automatically: 0ms, 1ms, ...)
  final trace1 = Trace.fromList([2, 4, 6, 8]); // All positive numbers are even
  final trace2 = Trace.fromList([2, 4, 5, 8]); // Contains 5 (positive but not even)

  // Evaluate the formula on the traces
  final result1 = evaluateTrace(trace1, formula);
  final result2 = evaluateTrace(trace2, formula);

  print('Trace 1 satisfies "$formula": ${result1.holds}'); // Output: true
  print('Trace 2 satisfies "$formula": ${result2.holds}'); // Output: false
  print('Reason for Trace 2 failure: ${result2.reason}');
  // Example Output: Reason for Trace 2 failure: Always failed: Antecedent held but consequent failed: isEven failed at index 2
}

```

## Additional Information

* **Formula Construction:** You can build formulas using:
  * Direct constructors (e.g., `Always(...)`, `Implies(...)`).
  * Builder functions (e.g., `always(...)`, `implies(...)`, `state(...)`).
  * Extension methods for common binary operators (`and`, `or`, `implies`).
* **Traces:** The `Trace` class assumes monotonically non-decreasing timestamps. You can create traces with explicit `Duration` timestamps using `
