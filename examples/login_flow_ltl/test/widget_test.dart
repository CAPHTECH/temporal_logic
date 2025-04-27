// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_flow_ltl_example/main.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart' as tlCore;
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart' as tlFlutter;

void main() {
  group('Login Flow LTL Example (External Recording)', () {
    // No longer need helper to create container with override

    testWidgets('Successful login flow satisfies LTL formula (EXPECTED TO FAIL due to flicker bug)', (tester) async {
      // --- Setup ---
      final recorder = tlFlutter.TraceRecorder<AppSnap>(interval: Duration.zero);
      // Use a standard ProviderContainer
      final container = ProviderContainer();
      addTearDown(container.dispose); // Ensure disposal
      recorder.initialize();

      // Manually record the initial state *before* pumping the widget
      // as the listener won't capture the very first state.
      final initialState = container.read(appStateProvider);
      recorder.record(AppSnap.fromAppState(initialState));

      // Set up the listener *before* pumping the widget to catch early changes
      // Note: Riverpod listeners might batch updates.
      container.listen<AppState>(appStateProvider, (previous, next) {
        print('Listener triggered: ${AppSnap.fromAppState(next)}');
        // Record every state change detected by the listener
        recorder.record(AppSnap.fromAppState(next));
      }, fireImmediately: false); // Don't fire immediately, already recorded initial

      // Pump the widget, triggering potential initial state changes caught by listener
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MyApp(),
        ),
      );
      // pumpAndSettle might be needed if MyApp itself triggers async actions on build
      await tester.pumpAndSettle();

      // --- Interaction: Successful Login (which includes the flicker bug) ---
      await tester.enterText(find.byKey(const Key('email')), 'valid@email.com');
      await tester.tap(find.byKey(const Key('login')));

      // IMPORTANT: pumpAndSettle allows all async operations (Future.delayed)
      // and state updates triggered by the interaction to complete.
      // The listener will record the states during this settlement.
      await tester.pumpAndSettle();

      // --- Temporal Logic Verification ---
      final loading = tlCore.state<AppSnap>((s) => s.isLoading, name: 'loading');
      final home = tlCore.state<AppSnap>((s) => s.isOnHomeScreen, name: 'home');
      final error = tlCore.state<AppSnap>((s) => s.hasError, name: 'error');
      final loginClicked = tlCore.event<AppSnap>((s) => s.loginClicked, name: 'loginClicked');

      // LTL Formula φ: Originally defined for a *correct* successful login
      final formula = tlCore.always(
          loginClicked.implies(tlCore.next(loading).and(tlCore.eventually(home)).and(tlCore.always(error.not()))));

      final trace = recorder.trace;
      print('Trace (Success Scenario with Flicker Bug):');
      trace.events.asMap().forEach((i, event) {
        print('$i: ${event.value} at ${event.timestamp}');
      });

      // Use the satisfiesLtl matcher, but expect it to FAIL due to the flicker bug
      // The test will PASS if the formula correctly evaluates to false.
      expect(
        trace,
        isNot(tlFlutter.satisfiesLtl(formula)),
        reason: 'LTL formula for successful login should FAIL due to the injected flicker bug violating G(!error).',
      );
    });

    testWidgets('Failed login flow violates LTL formula part', (tester) async {
      // --- Setup ---
      final recorder = tlFlutter.TraceRecorder<AppSnap>(interval: Duration.zero);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      recorder.initialize();

      final initialState = container.read(appStateProvider);
      recorder.record(AppSnap.fromAppState(initialState));

      container.listen<AppState>(appStateProvider, (previous, next) {
        print('Listener triggered: ${AppSnap.fromAppState(next)}');
        recorder.record(AppSnap.fromAppState(next));
      }, fireImmediately: false);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // --- Interaction: Failed Login ---
      await tester.enterText(find.byKey(const Key('email')), 'invalid-email');
      await tester.tap(find.byKey(const Key('login')));
      await tester.pumpAndSettle();

      // --- Temporal Logic Verification ---
      final loading = tlCore.state<AppSnap>((s) => s.isLoading, name: 'loading');
      final home = tlCore.state<AppSnap>((s) => s.isOnHomeScreen, name: 'home');
      final error = tlCore.state<AppSnap>((s) => s.hasError, name: 'error');
      final loginClicked = tlCore.event<AppSnap>((s) => s.loginClicked, name: 'loginClicked');

      // LTL Formula φ (same as before)
      final formula = tlCore.always(loginClicked.implies(tlCore
              .next(loading)
              .and(tlCore.eventually(home)) // This part will fail
              .and(tlCore.always(error.not())) // This part will also fail
          ));

      // Failure formula (same as before)
      final failureFormula = tlCore.always(loginClicked.implies(tlCore.eventually(error)));

      final trace = recorder.trace;
      print('Trace (Failure Scenario - External Recording):');
      trace.events.asMap().forEach((i, event) {
        print('$i: ${event.value} at ${event.timestamp}');
      });

      expect(trace, isNot(tlFlutter.satisfiesLtl(formula)),
          reason: 'LTL formula for successful login should NOT hold for failure (external recording).');

      expect(trace, tlFlutter.satisfiesLtl(failureFormula),
          reason: 'LTL formula for failed login should hold (external recording).');
    });

    testWidgets('Successful login should NOT flicker through error state', (tester) async {
      // --- Setup (same as successful login test) ---
      final recorder = tlFlutter.TraceRecorder<AppSnap>(interval: Duration.zero);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      recorder.initialize();

      final initialState = container.read(appStateProvider);
      recorder.record(AppSnap.fromAppState(initialState));

      container.listen<AppState>(appStateProvider, (previous, next) {
        print('Listener triggered (Flicker Test): ${AppSnap.fromAppState(next)}');
        recorder.record(AppSnap.fromAppState(next));
      }, fireImmediately: false);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // --- Interaction: Successful Login (which now includes the flicker) ---
      await tester.enterText(find.byKey(const Key('email')), 'valid@email.com');
      await tester.tap(find.byKey(const Key('login')));
      await tester.pumpAndSettle(); // Let login process (including flicker) complete

      // --- Temporal Logic Verification for Flicker ---

      final loading = tlCore.state<AppSnap>((s) => s.isLoading, name: 'loading');
      final home = tlCore.state<AppSnap>((s) => s.isOnHomeScreen, name: 'home');
      final error = tlCore.state<AppSnap>((s) => s.hasError, name: 'error');
      final loginClicked = tlCore.event<AppSnap>((s) => s.loginClicked, name: 'loginClicked');

      // Formula 1: Checks the original success condition (might still pass F(home))
      final originalSuccessFormula = tlCore.always(
          loginClicked.implies(tlCore.next(loading).and(tlCore.eventually(home)).and(tlCore.always(error.not()))));

      // Formula 2: Specifically checks against flicker.
      // "Globally, if loading starts, then it's NEVER followed by an error state."
      // This is a strong safety property against flickering *after* loading.
      final noErrorAfterLoading = tlCore.always(loading.implies(tlCore.always(error.not())));
      // Alternative Formula 2b: "Globally, if login is clicked, the next state is loading, and it's NEVER error afterwards"
      // final noErrorAfterLogin = tlCore.always(loginClicked.implies(tlCore.next(loading.and(tlCore.always(error.not())))));

      final trace = recorder.trace;
      print('Trace (Flicker Scenario):');
      trace.events.asMap().forEach((i, event) {
        print('$i: ${event.value} at ${event.timestamp}');
      });

      // Verification:
      // 1. The original formula might *incorrectly* seem to pass if only F(home) is considered
      //    OR it might fail because of G(!error). Let's check explicitly.
      //    EXPECTED: Fail because G(!error) is violated by the flicker.
      print('Evaluating original formula against flicker trace...');
      expect(trace, isNot(tlFlutter.satisfiesLtl(originalSuccessFormula)),
          reason: 'Original success formula should FAIL due to G(!error) violation by flicker.');

      // 2. The specific anti-flicker formula MUST fail because of the bug.
      print('Evaluating anti-flicker formula against flicker trace...');
      expect(trace, isNot(tlFlutter.satisfiesLtl(noErrorAfterLoading)),
          reason: 'No-error-after-loading formula should FAIL due to flicker.');

      // 3. Optional: Show that a standard test checking *only* the final screen would pass
      expect(find.byType(HomeScreen), findsOneWidget,
          reason: 'Standard test checking final state would incorrectly pass.');
    });

    testWidgets('Standard test passes for successful login (misses flicker)', (tester) async {
      // --- Setup ---
      // No recorder needed for this standard test
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle(); // Initial frame

      // --- Interaction: Successful Login (which includes the flicker) ---
      await tester.enterText(find.byKey(const Key('email')), 'valid@email.com');
      await tester.tap(find.byKey(const Key('login')));

      // Wait for all asynchronous operations and state changes to complete.
      // pumpAndSettle() waits until there are no more frames scheduled.
      // The flicker happens *during* this settlement period.
      await tester.pumpAndSettle();

      // --- Standard Verification (Checks only the final state) ---

      // Verify that the loading indicator is gone.
      expect(find.byType(LoadingScreen), findsNothing,
          reason: 'Loading screen should not be present after successful login settles.');

      // Verify that the error screen is not present.
      // THIS IS THE KEY POINT: The temporary error screen during the flicker
      // is no longer present after pumpAndSettle completes.
      expect(find.byType(ErrorScreen), findsNothing,
          reason: 'Error screen should not be present after successful login settles.');

      // Verify that the home screen is present.
      expect(find.byType(HomeScreen), findsOneWidget,
          reason: 'Home screen should be present after successful login settles.');

      // This test passes because it only observes the state *after* the
      // transient flicker has occurred and resolved.
    });
  });
}
