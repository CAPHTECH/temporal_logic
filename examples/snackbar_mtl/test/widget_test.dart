import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snackbar_mtl_example/main.dart';
// Use consistent prefixes
import 'package:temporal_logic_core/temporal_logic_core.dart' as tlCore;
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart' as tlFlutter;
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart' as tlMtl;

// Helper to get current SnackbarState from the widget tree and interaction state
// We now pass the trigger count manually when recording.
SnackbarState getCurrentSnackbarState(WidgetTester tester, int currentTriggerCount) {
  final snackbarFinder = find.byType(SnackBar);
  // Use tester.any() for a more robust visibility check
  final bool isCurrentlyVisible = tester.any(snackbarFinder);

  if (!isCurrentlyVisible) {
    // If snackbar isn't visible, return the hidden state from the enum
    return SnackbarState.hidden; // Assuming triggerCount is not needed when hidden
  }
  // If visible, extract content (assuming it must exist if visible)
  // Return the visible state. Content check might be removed if not needed.
  // final snackbarWidget = tester.widget<SnackBar>(snackbarFinder.first);
  // final contentWidget = snackbarWidget.content as Text;
  // Need to decide if content matters for the 'showing' state or if just visible is enough
  return SnackbarState.visible; // Corrected to use the enum member
}

void main() {
  group('Snackbar MTL Example', () {
    testWidgets(
        'Snackbar visibility follows MTL rule G(showError -> F[0,3s] !snackbarVisible)',
        (tester) => tester.runAsync(() async {
              // --- Setup ---
              // Use TimedValue<SnackbarState> (enum) for the recorder
              final recorder = tlFlutter.TraceRecorder<tlCore.TimedValue<SnackbarState>>(
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
              // Stream<tlCore.TimedValue<SnackbarState>> appStream = getAppStream(container);
              // StreamSubscription sub = appStream.listen((timedValue) {
              //    print('Test recorder received: $timedValue');
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
              await tester.pump(const Duration(seconds: 3)); // Wait for snackbar duration + buffer
              await tester.pumpAndSettle(); // Ensure animations finish
              await Future.delayed(const Duration(milliseconds: 100)); // Final buffer

              // --- Temporal Logic Verification ---

              // TODO: Redefine formulas for TimedValue<SnackbarState> (enum)
              // Use tlCore.event for state change detection
              final showError =
                  tlCore.event<tlCore.TimedValue<SnackbarState>>((tv) => /* Detect trigger */ false, name: 'showError');
              // Correctly compare the enum value inside the TimedValue
              // Use tlCore.state for instantaneous state check
              final snackbarHidden = tlCore
                  .state<tlCore.TimedValue<SnackbarState>>((tv) => tv.value == SnackbarState.hidden, name: 'hidden');

              // Placeholder MTL formula
              final formula = tlCore.always(showError.implies(
                  // Use tlMtl prefix for eventuallyTimed
                  // Use the class constructor, not a builder function
                  tlMtl.EventuallyTimed(
                      snackbarHidden, tlMtl.TimeInterval(Duration.zero, const Duration(seconds: 3)))));

              final trace = recorder.trace; // Should be Trace<TimedValue<SnackbarState>>
              print('Recorded Trace (TimedValue<SnackbarState>):\n$trace');

              // Verification
              final mtlResult = tlMtl.evaluateMtlTrace(trace, formula);
              expect(mtlResult.holds, isTrue, reason: 'MTL formula evaluation failed: $mtlResult');
            }));
  });
}
