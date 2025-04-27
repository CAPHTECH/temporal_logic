import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart';

// Define a simple enum for testing states
enum TestState { initial, target, other }

void main() {
  group('SustainedStateCheckerWidget', () {
    late StreamController<TimedValue<TestState>> streamController;
    const targetState = TestState.target;
    const sustainDuration = Duration(milliseconds: 100);

    setUp(() {
      // Stream now emits TimedValue<TestState>
      streamController = StreamController<TimedValue<TestState>>.broadcast();
    });

    tearDown(() {
      streamController.close();
    });

    Widget buildTestableWidget({
      TimedValue<TestState>? initialValue, // Changed type
      Widget Function(BuildContext, CheckStatus)? builder,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SustainedStateCheckerWidget<TestState>(
            stream: streamController.stream, // Now matches expected type
            targetState: targetState,
            sustainDuration: sustainDuration,
            initialValue: initialValue, // Now matches expected type
            builder: builder,
          ),
        ),
      );
    }

    // Helper to create TimedValue with duration from start
    TimedValue<TestState> timed(TestState state, Duration timeFromStart) =>
        TimedValue(state, timeFromStart);

    testWidgets('Initial state is Failure when no initial value matches',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
          initialValue: timed(TestState.initial, Duration.zero)));

      // Expect Failure because initial state is not target
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('Initial state is Pending when initial value matches target',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
          initialValue: timed(TestState.target, Duration.zero)));

      // Starts Pending because duration hasn't elapsed
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('Transitions to Success when target state is sustained',
        (WidgetTester tester) async {
      final startTime = tester.binding.clock.now();
      Duration elapsed() => tester.binding.clock.now().difference(startTime);

      // Start with initial non-target state -> should show Failure initially
      await tester.pumpWidget(buildTestableWidget(
          initialValue: timed(TestState.initial, Duration.zero)));
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      streamController.add(timed(TestState.target, elapsed()));
      // Need to pump twice: once for StreamBuilder to get new stream,
      // once for the internal listener to update based on the new state
      await tester.pump();
      await tester.pump(); // Should now be Pending
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);

      // Wait for sustain duration
      await tester.pump(sustainDuration);
      // Add another event to trigger check (or rely on timer within checker)
      streamController.add(timed(TestState.target, elapsed()));
      await tester.pump();

      // Now should be Success
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('Transitions to Failure if leaves target state early',
        (WidgetTester tester) async {
      final startTime = tester.binding.clock.now();
      Duration elapsed() => tester.binding.clock.now().difference(startTime);

      // Start with initial non-target state -> should show Failure initially
      await tester.pumpWidget(buildTestableWidget(
          initialValue: timed(TestState.initial, Duration.zero)));
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      streamController.add(timed(TestState.target, elapsed()));
      await tester.pump(); // Process stream add
      await tester.pump(); // Process internal state change (should go Pending)

      // Leave before sustain duration
      await tester.pump(sustainDuration * 0.5);
      streamController.add(timed(TestState.other, elapsed()));
      await tester.pump(); // Process stream add
      await tester.pump(); // Process internal state change (should go Failure)

      // Should transition to Failure
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('Resets to Pending and succeeds if re-enters target',
        (WidgetTester tester) async {
      final startTime = tester.binding.clock.now();
      Duration elapsed() => tester.binding.clock.now().difference(startTime);

      // Start with initial non-target state -> should show Failure initially
      await tester.pumpWidget(buildTestableWidget(
          initialValue: timed(TestState.initial, Duration.zero)));
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      // Enter target, leave early -> Failure
      streamController.add(timed(TestState.target, elapsed()));
      await tester.pump();
      await tester.pump(); // -> Pending
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);
      await tester.pump(sustainDuration * 0.5);
      streamController.add(timed(TestState.other, elapsed()));
      await tester.pump();
      await tester.pump(); // -> Failure
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      // Re-enter target
      streamController.add(timed(TestState.target, elapsed()));
      await tester.pump();
      await tester.pump(); // -> Pending
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);

      // Stay for duration -> Success
      await tester.pump(sustainDuration);
      streamController.add(timed(TestState.target, elapsed())); // Trigger check
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('Uses custom builder when provided',
        (WidgetTester tester) async {
      final startTime = tester.binding.clock.now();
      Duration elapsed() => tester.binding.clock.now().difference(startTime);

      await tester.pumpWidget(
        buildTestableWidget(
          initialValue: timed(TestState.initial, Duration.zero),
          builder: (context, status) {
            return Text('Status: ${status.name}');
          },
        ),
      );

      // Initial state should be Failure
      expect(find.text('Status: failure'), findsOneWidget);

      streamController.add(timed(TestState.target, elapsed()));
      await tester.pump();
      await tester.pump(); // -> Pending
      expect(find.text('Status: pending'), findsOneWidget);

      await tester.pump(sustainDuration);
      streamController.add(timed(TestState.target, elapsed())); // Trigger check
      await tester.pump();
      await tester.pump(); // -> Success

      // Updated state
      expect(find.text('Status: success'), findsOneWidget);
    });

    testWidgets('Handles stream closing gracefully',
        (WidgetTester tester) async {
      final startTime = tester.binding.clock.now();
      Duration elapsed() => tester.binding.clock.now().difference(startTime);

      // Start Failure
      await tester.pumpWidget(buildTestableWidget(
          initialValue: timed(TestState.initial, Duration.zero)));
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      // Become Success
      streamController.add(timed(TestState.target, elapsed()));
      await tester.pump();
      await tester.pump(); // -> Pending
      await tester.pump(sustainDuration);
      streamController.add(timed(TestState.target, elapsed())); // Trigger check
      await tester.pump();
      await tester.pump(); // -> Success
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await streamController.close();
      await tester.pump(); // Rebuild after stream closes

      // Should retain the last status (Success)
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('Transitions to Failure if stream ends while pending',
        (WidgetTester tester) async {
      final startTime = tester.binding.clock.now();
      Duration elapsed() => tester.binding.clock.now().difference(startTime);

      await tester.pumpWidget(buildTestableWidget(
          initialValue: timed(TestState.initial, Duration.zero)));
      expect(find.byIcon(Icons.cancel), findsOneWidget); // Pending

      streamController.add(timed(TestState.target, elapsed()));
      await tester
          .pump(sustainDuration * 0.5); // Enter target, but not long enough
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);

      await streamController.close();
      await tester.pump(); // Rebuild after stream closes

      // Should transition to Failure because it was pending when stream ended
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });
  });
}
