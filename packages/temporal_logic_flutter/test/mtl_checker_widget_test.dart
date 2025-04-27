import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart';

// Simple state class for testing
class TestState {
  final bool value;
  TestState(this.value);
  @override
  bool operator ==(Object other) => other is TestState && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'TestState($value)';
}

void main() {
  group('MtlCheckerWidget', () {
    late StreamController<TimedValue<TestState>> streamController;
    late Formula<TestState> formulaAlwaysTrueTimed;
    late Formula<TestState> formulaEventuallyTrueTimed;

    setUp(() {
      streamController = StreamController<TimedValue<TestState>>.broadcast();
      // Example MTL Formula: value must be true within 0 to 100ms
      // Use the AST node constructor directly
      formulaAlwaysTrueTimed = AlwaysTimed<TestState>(
        state<TestState>((s) => s.value),
        TimeInterval(Duration.zero, Duration(milliseconds: 100)),
      );
      formulaEventuallyTrueTimed = EventuallyTimed<TestState>(
        state<TestState>((s) => s.value),
        TimeInterval(Duration.zero, Duration(milliseconds: 200)),
      );
    });

    tearDown(() {
      streamController.close();
    });

    Widget buildTestableWidget(Formula<TestState> formula, {TimedValue<TestState>? initialValue}) {
      return MaterialApp(
        home: Scaffold(
          body: MtlCheckerWidget<TestState>(
            stream: streamController.stream,
            formula: formula,
            initialValue: initialValue,
          ),
        ),
      );
    }

    // Helper to create TimedValue with duration from start
    TimedValue<TestState> timed(TestState state, Duration timeFromStart) => TimedValue(state, timeFromStart);

    testWidgets('Initial state before stream emits (defaults to false)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(formulaAlwaysTrueTimed));

      // Default builder displays Check/Cancel based on bool result
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      // Also check tooltip for initial reason
      expect(find.byTooltip('Initializing...'), findsOneWidget); // Or 'Waiting for stream...'
    });

    testWidgets('Displays Success when formula holds', (WidgetTester tester) async {
      final startTime = tester.binding.clock.now();
      Duration elapsed() => tester.binding.clock.now().difference(startTime);

      await tester
          .pumpWidget(buildTestableWidget(formulaAlwaysTrueTimed, initialValue: timed(TestState(true), Duration.zero)));
      expect(find.byIcon(Icons.cancel), findsOneWidget); // Initial is false until evaluation runs

      // Emit states that satisfy the formula within the time bound
      streamController.add(timed(TestState(true), elapsed() + const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump(); // Rebuild
      streamController.add(timed(TestState(true), elapsed() + const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump(); // Rebuild

      // Expect Check icon
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);
      expect(find.byTooltip('Formula holds'), findsOneWidget);
    });

    testWidgets('Displays Failure when formula does not hold', (WidgetTester tester) async {
      final startTime = tester.binding.clock.now();
      Duration elapsed() => tester.binding.clock.now().difference(startTime);

      await tester
          .pumpWidget(buildTestableWidget(formulaAlwaysTrueTimed, initialValue: timed(TestState(true), Duration.zero)));

      // Emit states, one of which violates the formula
      streamController.add(timed(TestState(true), elapsed() + const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump(); // Rebuild
      streamController
          .add(timed(TestState(false), elapsed() + const Duration(milliseconds: 50))); // Violation within interval
      await tester.pump();
      await tester.pump(); // Rebuild

      // Expect Cancel icon
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      // Check tooltip contains failure reason (specific reason depends on evaluator)
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('AlwaysTimed failed')); // Failure reason from evaluator
      // expect(tooltip.message, contains('Atomic failed')); // Example specific reason
    });

    testWidgets('Updates display when formula result changes', (WidgetTester tester) async {
      final startTime = tester.binding.clock.now();
      Duration elapsed() => tester.binding.clock.now().difference(startTime);

      await tester.pumpWidget(buildTestableWidget(formulaEventuallyTrueTimed));

      // Initially formula is false (nothing emitted yet)
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      streamController.add(timed(TestState(false), elapsed() + const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump(); // Rebuild
      // Still false
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      streamController
          .add(timed(TestState(true), elapsed() + const Duration(milliseconds: 150))); // Becomes true within interval
      await tester.pump();
      await tester.pump(); // Rebuild
      // Now displays true
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('Uses custom builder when provided', (WidgetTester tester) async {
      final startTime = tester.binding.clock.now();
      Duration elapsed() => tester.binding.clock.now().difference(startTime);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MtlCheckerWidget<TestState>(
              stream: streamController.stream,
              formula: formulaAlwaysTrueTimed,
              initialValue: timed(TestState(true), Duration.zero),
              builder: (context, result, details) {
                // Updated builder signature
                return Text(result ? 'MTL Holds' : 'MTL Does not hold (${details.reason ?? 'no reason'})');
              },
            ),
          ),
        ),
      );

      // Initial state (false)
      expect(find.textContaining('MTL Does not hold'), findsOneWidget);

      streamController.add(timed(TestState(true), elapsed() + const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump(); // Rebuild

      // Updated state (true)
      expect(find.text('MTL Holds'), findsOneWidget);
    });

    testWidgets('Handles stream closing gracefully', (WidgetTester tester) async {
      final startTime = tester.binding.clock.now();
      Duration elapsed() => tester.binding.clock.now().difference(startTime);

      await tester
          .pumpWidget(buildTestableWidget(formulaAlwaysTrueTimed, initialValue: timed(TestState(true), Duration.zero)));
      expect(find.byIcon(Icons.cancel), findsOneWidget); // Initial false

      streamController.add(timed(TestState(true), elapsed() + const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump(); // Rebuild
      expect(find.byIcon(Icons.check_circle), findsOneWidget); // Becomes true

      await streamController.close();
      await tester.pump(); // Rebuild after stream closes

      // Should still display the last known state (true)
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);
    });
  });
}
