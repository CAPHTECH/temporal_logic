# Temporal Logic for Flutter & Dart

<!-- Add Badges here (e.g., pub.dev version, build status, license) -->

<!-- [![pub package](https://img.shields.io/pub/v/temporal_logic_core.svg)](https://pub.dev/packages/temporal_logic_core) -->

This repository contains a collection of Dart packages for working with various forms of temporal logic, primarily aimed at verification and specification within Flutter applications, but also usable in pure Dart environments.

## Public API and Migration

Use the package libraries as the supported entry points:

* `package:temporal_logic_core/temporal_logic_core.dart`
* `package:temporal_logic_mtl/temporal_logic_mtl.dart`
* `package:temporal_logic_flutter/temporal_logic_flutter.dart`
* `package:temporal_logic_flutter/temporal_logic_flutter_test.dart`

Files under `src/` are implementation details and can change during refactoring. If you used the removed legacy MTL helpers, see [MIGRATION.md](MIGRATION.md).

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

* **`packages/temporal_logic_core`**: Core AST, trace model, `EvaluationResult`, and `evaluateTrace` / `evaluateLtl`.
* **`packages/temporal_logic_mtl`**: Timed operators and `evaluateMtlTrace` for Metric Temporal Logic over timed traces.
* **`packages/temporal_logic_flutter`**: Flutter-oriented stream checkers, widgets, trace recording, and test matchers.

## Features

* Core propositional logic and LTL building blocks.
* Metric Temporal Logic (MTL) formula construction and timed evaluation.
* Flutter integration for stream-based checking, widgets, trace recording, and test helpers.

## Installation

Add the desired packages to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  temporal_logic_core: ^<latest_version>
  temporal_logic_mtl: ^<latest_version>
  temporal_logic_flutter: ^<latest_version>

dev_dependencies:
  flutter_test:
    sdk: flutter
```

Then run `flutter pub get`.

## Usage

Here is a brief overview of the current API. See the package READMEs and `examples/` for fuller scenarios.

**`temporal_logic_core`**

```dart
import 'package:temporal_logic_core/temporal_logic_core.dart';

final isPositive = state<int>((value) => value > 0, name: 'isPositive');
final isEven = state<int>((value) => value.isEven, name: 'isEven');
final formula = always(isPositive.implies(isEven));

final trace = Trace<int>.fromList([2, 4, 6, 7, 8]);
final result = evaluateTrace(trace, formula);

print(result.holds);
print(result.reason);
```

**`temporal_logic_mtl`**

```dart
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';

final request = state<String>((value) => value == 'request', name: 'request');
final response = state<String>((value) => value == 'response', name: 'response');

final spec = always(
  request.implies(
    EventuallyTimed(
      response,
      TimeInterval.upTo(const Duration(seconds: 5)),
    ),
  ),
);

final trace = Trace<String>([
  TraceEvent(timestamp: Duration.zero, value: 'idle'),
  TraceEvent(timestamp: const Duration(seconds: 1), value: 'request'),
  TraceEvent(timestamp: const Duration(seconds: 3), value: 'response'),
]);

final result = evaluateMtlTrace(trace, spec);
print(result.holds);
print(result.reason);
```

For Flutter-specific usage, import `package:temporal_logic_flutter/temporal_logic_flutter.dart` and see the package README for `StreamLtlChecker`, `StreamMtlChecker`, `LtlCheckerWidget`, `MtlCheckerWidget`, and `TraceRecorder`.

## Examples

* **`examples/counter_ltl`**: A simple Flutter counter example demonstrating Linear Temporal Logic (LTL) concepts (or intended to).
* **`examples/snackbar_mtl`**: A Flutter example showcasing the use of Metric Temporal Logic (MTL) for specifying behavior related to Snackbars.
* **`examples/login_flow_ltl`**: Demonstrates using LTL to verify a multi-step login flow, including detecting transient state bugs (like UI flicker) that standard tests might miss.

## Getting Started

1. **Install mise:** Follow the official [mise installation guide](https://mise.jdx.dev/getting-started.html).
2. **Install the pinned Flutter SDK:** This repository pins Flutter `3.41.5` in [`mise.toml`](mise.toml).

    ```bash
    mise install
    ```

3. **Clone the repository:**

    ```bash
    git clone git@github.com:CAPHTECH/temporal_logic.git
    cd temporal_logic
    ```

4. **Get dependencies:**

    ```bash
    mise exec -- flutter pub get
    ```

5. **Run tests (Optional):** Navigate to individual package directories (e.g., `packages/temporal_logic_core`) and run tests:

    ```bash
    cd packages/temporal_logic_core
    mise exec -- flutter test
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

Please report any bugs or feature requests on the [GitHub Issue Tracker](https://github.com/CAPHTECH/temporal_logic/issues).

## License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
