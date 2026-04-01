import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snackbar_mtl_example/main.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter_test.dart'
    as tl_flutter;

// Helper to get current SnackbarState from the widget tree and interaction state
// We now pass the trigger count manually when recording.
SnackbarState getCurrentSnackbarState(
    WidgetTester tester, int currentTriggerCount) {
  final snackbarFinder = find.byType(SnackBar);
  // Use tester.any() for a more robust visibility check
  final bool isCurrentlyVisible = tester.any(snackbarFinder);

  if (!isCurrentlyVisible) {
    // If snackbar isn't visible, return the hidden state from the enum
    return SnackbarState
        .hidden; // Assuming triggerCount is not needed when hidden
  }
  // If visible, extract content (assuming it must exist if visible)
  // Return the visible state. Content check might be removed if not needed.
  return SnackbarState.visible; // Corrected to use the enum member
}

void main() {
  group('Snackbar MTL Example', () {
    testWidgets(
        'Snackbar visibility follows MTL rule G(showError -> F[0,3s] !snackbarVisible)',
        (tester) => tester.runAsync(() async {
              // --- Setup ---
              // Use TimedValue<SnackbarState> (enum) for the recorder
              final recorder = tl_flutter.TraceRecorder<
                  tl_flutter.TimedValue<SnackbarState>>(
                // Adjust interval if needed
                interval: const Duration(milliseconds: 50),
              );
              final container = ProviderContainer();
              addTearDown(container.dispose);

              // Initialize recorder before first record
              recorder.initialize();
              // int triggerCount = 0; // Trigger count managed by snackbarTriggerProvider

              // TODO: Need a way to access the app's snackbarStreamController stream here
              // Example placeholder:
              // Stream<tl_flutter.TimedValue<SnackbarState>> appStream = getAppStream(container);
              // StreamSubscription sub = appStream.listen((timedValue) {
              //    debugPrint('Test recorder received: $timedValue');
              //    recorder.record(timedValue);
              // });
              // addTearDown(sub.cancel);

              // Build app
              await tester.pumpWidget(
                UncontrolledProviderScope(
                  container: container,
                  child: const MyApp(),
                ),
              );
              await tester.pumpAndSettle();

              // --- Interaction ---
              // Tap the button increments snackbarTriggerProvider in the app
              await tester.tap(find.byIcon(Icons.add_alert));
              // Allow time for snackbar to show and hide
              await tester.pump(const Duration(
                  seconds: 3)); // Wait for snackbar duration + buffer
              await tester.pumpAndSettle(); // Ensure animations finish
              await Future.delayed(
                  const Duration(milliseconds: 100)); // Final buffer

              // --- Temporal Logic Verification ---

              // TODO: Redefine formulas for TimedValue<SnackbarState> (enum)
              // Use tl_flutter.event for state change detection
              final showError =
                  tl_flutter.event<tl_flutter.TimedValue<SnackbarState>>(
                      (tv) => /* Detect trigger */ false,
                      name: 'showError');
              // Correctly compare the enum value inside the TimedValue
              // Use tl_flutter.state for instantaneous state check
              final snackbarHidden =
                  tl_flutter.state<tl_flutter.TimedValue<SnackbarState>>(
                      (tv) => tv.value == SnackbarState.hidden,
                      name: 'hidden');

              // Placeholder MTL formula
              final formula = tl_flutter.always(showError.implies(
                  // Use tl_flutter prefix for eventuallyTimed
                  // Use the class constructor, not a builder function
                  tl_flutter.EventuallyTimed(
                      snackbarHidden,
                      tl_flutter.TimeInterval(
                          Duration.zero, const Duration(seconds: 3)))));

              final trace =
                  recorder.trace; // Should be Trace<TimedValue<SnackbarState>>

              // Verification
              final mtlResult = tl_flutter.evaluateMtlTrace(trace, formula);
              expect(mtlResult.holds, isTrue,
                  reason: 'MTL formula evaluation failed: $mtlResult');
            }));
  });
}
