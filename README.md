# Temporal Logic for Flutter & Dart

<!-- Add Badges here (e.g., pub.dev version, build status, license) -->

<!-- [![pub package](https://img.shields.io/pub/v/temporal_logic_core.svg)](https://pub.dev/packages/temporal_logic_core) -->

This repository contains a collection of Dart packages for working with various forms of temporal logic, primarily aimed at verification and specification within Flutter applications, but also usable in pure Dart environments.

## Why Temporal Logic for Flutter/Dart?

Modern applications, especially UI-rich applications built with frameworks like Flutter, often involve complex sequences of events, state changes, and timing dependencies. Bugs can arise from:

* **Incorrect Ordering:** Did an action complete *before* the UI updated? Was data fetched *before* being displayed?
* **Timing Issues:** Did a loading indicator disappear *too quickly*? Did a temporary message stay on screen for the *correct duration*?
* **Complex State Interactions:** Does the app remain in a valid state *after* a series of user interactions and background processes?

Manually testing all possible sequences and timing variations is difficult and error-prone.

**Temporal Logic** provides a formal language to precisely describe these time-dependent properties.

* **Linear Temporal Logic (LTL)** (Related to `temporal_logic_core` foundations): Allows you to specify properties about the *order* of events. For example:
  * "The user must *always* be logged in to access the settings page."
  * "A 'request sent' event must *eventually* be followed by a 'response received' or 'request failed' event."
* **Metric Temporal Logic (MTL)** (Implemented in `temporal_logic_mtl`): Extends LTL by adding *quantitative time constraints*. For example:
  * "After sending a message, a 'delivered' status must appear *within 5 seconds*."
  * "The splash screen must be displayed for *at least 2 seconds* but *no more than 4 seconds*."

**Using these packages, you can:**

1. **Clearly Specify Behavior:** Write down the intended temporal behavior of your components or application flow in an unambiguous way.
2. **(Future Goal) Runtime Verification:** Potentially monitor your running Flutter application to check if its actual behavior conforms to your specifications, catching violations early.
3. **Improve Testability:** Design tests that specifically target complex temporal scenarios.

Even if you don't perform formal verification, the act of writing down temporal specifications can clarify requirements and help identify potential design flaws.

## Packages

* **`packages/temporal_logic_core`**: Provides the fundamental interfaces and structures for propositional logic and basic trace representations.
* **`packages/temporal_logic_mtl`**: Implements Metric Temporal Logic (MTL), allowing specifications over timed traces with quantitative time constraints.
* **`packages/temporal_logic_flutter`**: Integrates temporal logic concepts with Flutter, potentially offering widgets or utilities for visualizing or checking properties against application state changes over time (details TBD).

## Features

* Core propositional logic building blocks.
* Metric Temporal Logic (MTL) formula construction and evaluation.
* (Planned/Potential) Flutter integration for runtime verification or visualization.

## Installation

Add the desired packages to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  temporal_logic_core: ^<latest_version> # Check pub.dev for the latest version
  temporal_logic_mtl: ^<latest_version>  # Check pub.dev for the latest version
  # temporal_logic_flutter: ^<latest_version> # Uncomment when available

dev_dependencies:
  flutter_test:
    sdk: flutter
```

Then run `flutter pub get`.

## Usage

Here's a brief overview of how to use the core packages. See the `examples/` directory for more detailed scenarios.

**`temporal_logic_core`**

```dart
import 'package:temporal_logic_core/temporal_logic_core.dart';

// Define atomic propositions using predicates
final p = AtomicProposition<Map<String, bool>>((state) => state['p'] ?? false, name: 'p');
final q = AtomicProposition<Map<String, bool>>((state) => state['q'] ?? false, name: 'q');

// Create simple formulas using the builder methods
final formula = p.and(q.not()); // Equivalent to: And(p, Not(q))

// Define a state (a valuation mapping proposition names/IDs to truth values)
final state = {'p': true, 'q': false};

// --- Evaluation Note ---
// Evaluation is typically done using an evaluator function against a trace
// (a sequence of states). For a single state:
bool evaluateAtomicInState(Formula<Map<String, bool>> formula, Map<String, bool> state) {
  if (formula is AtomicProposition<Map<String, bool>>) {
    return formula.predicate(state);
  }
  // ... handle other formula types recursively (Not, And, Or, etc.)
  // This is a simplified illustration; the actual evaluator handles traces.
  throw UnimplementedError('Full evaluation logic resides in the evaluator.');
}

// Conceptually evaluating the proposition p in the state:
final pResult = evaluateAtomicInState(p, state);
print('Proposition "${p.name}" holds in state: $pResult'); // Output: true

// Evaluating the full formula requires a proper trace evaluator.
// The string representation shows the formula structure:
print('Formula structure: "$formula"'); // Output: Formula structure: "(p && !(q))"
```

**`temporal_logic_mtl`**

```dart
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';

// Define atomic propositions using predicates on the state type (e.g., Map)
final request = AtomicProposition<Map<String, bool>>((state) => state['request'] ?? false, name: 'request');
final response = AtomicProposition<Map<String, bool>>((state) => state['response'] ?? false, name: 'response');

// Define an MTL formula: Globally, if 'request' happens, then 'response'
// must happen within 5 time units.
// Using builder methods: request.implies(response.eventually(interval: TimeInterval(0, 5))).always()
final spec = Always(
  Implies(request, EventuallyTimed(response, interval: TimeInterval(0, 5))),
);

// Define a timed trace (sequence of states with timestamps)
// The state type must match the AtomicProposition type (Map<String, bool>)
final trace = Trace<Map<String, bool>>([
  TraceEvent({'request': false, 'response': false}, 0),
  TraceEvent({'request': true, 'response': false}, 1),
  TraceEvent({'request': false, 'response': false}, 2),
  TraceEvent({'request': false, 'response': true}, 4), // Response arrives at t=4 (within 5 units of request at t=1)
  TraceEvent({'request': false, 'response': false}, 6),
]);

// Evaluate the specification against the trace using the MTL evaluator
// The evaluator function takes the formula, the trace, and the starting index.
final result = evaluateMtlTrace(spec, trace, 0); // Evaluate from the beginning (index 0)
print('Specification "$spec" holds on trace: $result'); // Expected output depends on exact MTL semantics implementation
```

*(Note: Ensure `temporal_logic_mtl` provides an `evaluateMtlTrace` function or similar for evaluation. The example assumes its existence.)*

## Examples

* **`examples/counter_ltl`**: A simple Flutter counter example demonstrating Linear Temporal Logic (LTL) concepts (or intended to).
* **`examples/snackbar_mtl`**: A Flutter example showcasing the use of Metric Temporal Logic (MTL) for specifying behavior related to Snackbars.
* **`examples/login_flow_ltl`**: Demonstrates using LTL to verify a multi-step login flow, including detecting transient state bugs (like UI flicker) that standard tests might miss.

## Getting Started

1. **Ensure Flutter is installed:** Follow the official [Flutter installation guide](https://docs.flutter.dev/get-started/install).
2. **Install FVM (Optional but Recommended):** If you prefer using FVM to manage Flutter versions, install it following the [FVM documentation](https://fvm.app/docs/getting_started/installation). This project is configured to use FVM.
3. **Clone the repository:**

    ```bash
    git clone https://github.com/your-username/temporal_logic_flutter.git # Replace with actual repo URL
    cd temporal_logic_flutter
    ```

4. **Get dependencies:**

    ```bash
    # If using FVM
    fvm flutter pub get

    # If using system Flutter
    flutter pub get
    ```

5. **Run tests (Optional):** Navigate to individual package directories (e.g., `packages/temporal_logic_core`) and run tests:

    ```bash
    # If using FVM
    cd packages/temporal_logic_core
    fvm flutter test

    # If using system Flutter
    cd packages/temporal_logic_core
    flutter test
    ```

## Contributing

Contributions are welcome! Please follow these general guidelines:

1. **Fork the repository** and create your branch from `main`.
2. **Make your changes.** Ensure code is formatted (`dart format .`) and passes analysis (`flutter analyze`).
3. **Add tests** for any new features or bug fixes.
4. **Ensure all tests pass** within the relevant package(s).
5. **Create a pull request** with a clear description of your changes.

Please note that this project adheres to a [Contributor Covenant code of conduct](https://www.contributor-covenant.org/). By participating, you are expected to uphold this code.

## Reporting Issues & Getting Support

Please report any bugs or feature requests on the [GitHub Issue Tracker](https://github.com/your-username/temporal_logic_flutter/issues). <!-- TODO: Replace with actual repo URL -->

## License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
