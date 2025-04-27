// Use relative path instead
import 'package:counter_ltl_example/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Import the temporal logic library with a prefix
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart' as tl;

void main() {
  // Define a test-specific state type if needed, or use the original (int)
  // typedef CounterTestState = int;

  test('Counter increments with Riverpod respects LTL properties', () async {
    // --- Setup ---
    // Use the prefixed TraceRecorder
    final recorder = tl.TraceRecorder<int>();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // *** Initialize the recorder ***
    recorder.initialize();

    container.listen<int>(
      counterProvider, // Assumes counterProvider is defined in main.dart
      (previous, next) {
        print('State changed: $previous -> $next');
        // *** Use the recorder's record method ***
        recorder.record(next);
      },
      fireImmediately: true, // Records the initial state (0) after initialization
    );

    final notifier = container.read(counterProvider.notifier);

    // --- Interaction ---
    notifier.increment();
    await Future.value();
    notifier.increment();
    await Future.value();

    // --- Temporal Logic Verification ---
    final trace = recorder.trace;
    // Example Expected Trace: [TraceEvent(timestamp: 0ms, value: 0),
    //                       TraceEvent(timestamp: ~Xms, value: 1),
    //                       TraceEvent(timestamp: ~Yms, value: 2)]
    print('Recorded Trace: $trace');

    // Define properties using the 'tl' prefix and correct function/extension usage
    final propEventually2 = tl.eventually(tl.state<int>((s) => s == 2));
    final propAlwaysNonNegative = tl.always(tl.state<int>((s) => s >= 0));
    final propIncrement = tl
        .always(tl.state<int>((s) => s == 0).implies(tl.next(tl.state<int>((s) => s == 1)))) // always(0 -> next(1))
        .and(
          // Use .and() extension
          tl.always(
            tl.state<int>((s) => s == 1).implies(tl.next(tl.state<int>((s) => s == 2))),
          ), // always(1 -> next(2))
        );
    final propNever3 = tl.always(tl.state<int>((s) => s != 3));

    // Verify the properties using the matcher with the 'tl' prefix
    expect(trace, tl.satisfiesLtl(propEventually2), reason: 'Expected counter to eventually be 2');
    expect(trace, tl.satisfiesLtl(propAlwaysNonNegative), reason: 'Expected counter to always be non-negative');
    expect(trace, tl.satisfiesLtl(propIncrement), reason: 'Expected counter increments correctly (0->1, 1->2)');
    expect(trace, tl.satisfiesLtl(propNever3), reason: 'Expected counter to never reach 3 in this trace');
  });
}
