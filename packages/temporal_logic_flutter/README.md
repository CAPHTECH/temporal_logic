# temporal_logic_flutter

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- [![pub package](https://img.shields.io/pub/v/temporal_logic_flutter.svg)](https://pub.dev/packages/temporal_logic_flutter) -->
<!-- [![Build Status](...)](...) -->

This package bridges the gap between temporal logic specifications (LTL and MTL from `temporal_logic_core` and `temporal_logic_mtl`) and live Flutter application state.

It provides tools to monitor streams of application state changes and evaluate temporal properties against them in real-time, facilitating runtime verification and debugging of complex temporal behaviors.

## Features

*   **Stream Checkers:**
    *   `StreamLtlChecker`: Evaluates standard LTL formulas against a stream of state updates.
    *   `StreamMtlChecker`: Evaluates MTL formulas (with time constraints) against a stream of timed state updates.
    *   `StreamSustainedStateChecker`: Checks if a specific state predicate holds continuously for a required duration within a stream.
*   **Trace Recording:** `TraceRecorder` widget (or utility) to capture a sequence of state changes from a stream into a `Trace` object for later analysis or evaluation.
*   **Visualization Widgets (Examples/Utilities):**
    *   `LtlCheckerWidget`, `MtlCheckerWidget`, `SustainedStateCheckerWidget`: Example widgets that likely consume a stream checker and display its current status (`CheckStatus`: unknown, success, failure).
*   **State Matching:** Utility functions or classes (in `matchers.dart`) likely used to define the atomic propositions based on application state.
*   **Status Reporting:** `CheckStatus` enum to represent the outcome of a check.

## Getting Started

**(Note: This package is under active development and API details might change.)**

Add this package along with its core dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  temporal_logic_core: ^0.1.0 # Or latest
  temporal_logic_mtl: ^0.1.0 # Or latest
  temporal_logic_flutter: ^0.0.1-dev # Use the latest version from pub.dev or Git
```

Then run `flutter pub get`.

## Usage (Conceptual)

While the exact API might evolve, the general usage pattern would involve:

1.  **Defining State Propositions:** Use helpers (likely from `matchers.dart` or `temporal_logic_core.builder`) to create `AtomicProposition` instances based on your application state (e.g., from a BLoC, Riverpod provider, ValueNotifier, etc.).

    ```dart
    // Example using a hypothetical state class `CounterState`
    final isCounting = state<CounterState>((s) => s.isCounting);
    final countIsTen = state<CounterState>((s) => s.count == 10);
    ```

2.  **Defining Temporal Formulas:** Construct LTL or MTL formulas using builders or constructors from the core/mtl packages.

    ```dart
    // LTL: It should eventually reach 10
    final ltlSpec = eventually(countIsTen);

    // MTL: Counting must start within 500ms
    final mtlSpec = EventuallyTimed(isCounting, TimeInterval.upTo(Duration(milliseconds: 500)));
    ```

3.  **Setting up a Stream Checker:** Instantiate a checker (`StreamLtlChecker`, `StreamMtlChecker`, etc.) providing the formula and the stream of application state.

    ```dart
    // Assuming `myBloc.stream` provides a Stream<CounterState>
    final ltlChecker = StreamLtlChecker<CounterState>(
        formula: ltlSpec,
        stream: myBloc.stream,
    );

    // For MTL, the stream needs to provide timed values or be wrapped
    // final mtlChecker = StreamMtlChecker<CounterState>(...);
    ```

4.  **Observing Check Status:** Listen to the checker's status stream (which likely emits `CheckStatus`) or use one of the provided `*CheckerWidget`s to display the status in the UI.

    ```dart
    // Using a widget
    MtlCheckerWidget(
      checker: mtlChecker,
      // Builder to display based on CheckStatus (success, failure, unknown)
    )

    // Or listening to the stream directly
    mtlChecker.statusStream.listen((status) {
      print('MTL Check Status: $status');
      if (status == CheckStatus.failure) {
        // Handle failure...
      }
    });
    ```

**(Please refer to specific class documentation and examples once available for precise usage.)**

## Additional Information

*   **Dependencies:** Relies heavily on `temporal_logic_core` for formula structure and `temporal_logic_mtl` for timed logic.
*   **State Management:** Designed to work with streams, making it potentially compatible with various state management solutions (BLoC, Riverpod, etc.) that expose state via streams.
*   **Performance:** Runtime checking can have performance implications. The efficiency of the checkers, especially for complex formulas and high-frequency streams, should be considered.

See the `example/` directory in the main repository for potential usage scenarios.

## Testing with LTL in Flutter Widget Tests

You can use the `TraceRecorder` widget and the `satisfiesLtl` matcher from this package to verify state transitions in your Flutter widget tests according to LTL formulas.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart';

// Example test using TraceRecorder and satisfiesLtl
testWidgets('MyWidget follows LTL specification', (tester) async {
  final recorder = TraceRecorder<MyWidgetState>(
    child: MyWidget(),
    extractor: (widget) => (widget as MyWidget).currentState, // Replace with your state extraction
  );

  await tester.pumpWidget(MaterialApp(home: recorder));

  // Interact with the widget
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle(); // Allow state to settle

  // Define your LTL formula
  final Formula<MyWidgetState> formula = eventually(state((s) => s.isComplete));

  // Get the recorded trace
  final trace = recorder.trace;

  // Verify the trace against the formula
  // Note: See important usage note below for widget tests.
  // expect(trace, satisfiesLtl(formula));

  // RECOMMENDED approach for widget tests (see below):
  final result = evaluateTrace(trace, formula);
  expect(result.holds, isTrue, reason: 'Formula should hold. Reason: \${result.reason}');
});
```

### Important Note on Using `satisfiesLtl` in Widget Tests

While the `satisfiesLtl` matcher provides a convenient way to write LTL assertions using `expect`, **it may exhibit inconsistent behavior (sometimes passing, sometimes failing) in Flutter widget tests**, especially when:

*   Evaluating complex LTL formulas involving combinations of logical and temporal operators (e.g., `P.and(eventually(Q))`).
*   Using traces dynamically generated by `TraceRecorder` during widget interactions.

This inconsistency is likely due to the complex interactions between the matcher, the Flutter test environment's asynchronous nature, and state updates, rather than an issue in the core LTL evaluation logic (`evaluateTrace`).

**Recommendation for Widget Tests:**

For reliable and stable LTL verification in Flutter widget tests, it is **strongly recommended to call the `evaluateTrace` function directly** from the `temporal_logic_core` package and assert the `holds` property of the returned `EvaluationResult`.

```dart
// Recommended approach in widget tests:
import 'package:temporal_logic_core/temporal_logic_core.dart';

// ... inside testWidgets ...
final trace = recorder.trace;
final formula = /* ... your formula ... */;

// Call evaluateTrace directly
final EvaluationResult result = evaluateTrace(trace, formula);

// Assert the result's 'holds' property
expect(result.holds, isTrue, reason: 'Formula should hold. Reason: \${result.reason}');
```

Using `evaluateTrace` directly bypasses the potential inconsistencies associated with the matcher in the widget test environment. The `satisfiesLtl` matcher might still be suitable for simpler formulas or non-widget test scenarios where its behavior is more predictable.
