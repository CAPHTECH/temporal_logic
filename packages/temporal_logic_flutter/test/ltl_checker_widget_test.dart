import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart';

// Removed MockStreamLtlChecker and MockFormula classes

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
  group('LtlCheckerWidget', () {
    late StreamController<TestState> streamController;
    late Formula<TestState> formulaAlwaysTrue;
    late Formula<TestState> formulaAlwaysFalse;
    late Formula<TestState> formulaEventuallyTrue;

    setUp(() {
      streamController = StreamController<TestState>.broadcast();
      formulaAlwaysTrue =
          always(state<TestState>((s) => s.value, name: 'p')); // G(p)
      formulaAlwaysFalse =
          always(state<TestState>((s) => !s.value, name: '!p')); // G(!p)
      formulaEventuallyTrue =
          eventually(state<TestState>((s) => s.value, name: 'p')); // F(p)
    });

    tearDown(() {
      if (!streamController.isClosed) {
        streamController.close();
      }
    });

    // Helper to build the widget, now includes initialValue
    Widget buildTestableWidget({
      required Stream<TestState> stream,
      required Formula<TestState> formula,
      TestState? initialValue,
      Widget Function(BuildContext context, bool result)? builder,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: LtlCheckerWidget<TestState>(
            stream: stream,
            formula: formula,
            initialValue: initialValue,
            builder: builder,
          ),
        ),
      );
    }

    testWidgets('Initial state is calculated correctly (G(p) on empty is true)',
        (WidgetTester tester) async {
      // G(p) is vacuously true on an empty trace
      await tester.pumpWidget(buildTestableWidget(
          stream: streamController.stream, formula: formulaAlwaysTrue));

      // Expect Check icon (initial result is true)
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets(
        'Initial state with initialValue is calculated correctly (G(p) on [T])',
        (WidgetTester tester) async {
      // G(p) on trace [T] is true
      await tester.pumpWidget(buildTestableWidget(
        stream: streamController.stream,
        formula: formulaAlwaysTrue,
        initialValue: TestState(true),
      ));

      // Expect Check icon (initial result is true)
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);

      // Add a state that violates G(p)
      streamController.add(TestState(false));
      await tester.pump();
      await tester.pump();

      // Should update to false
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets(
        'Initial state with initialValue is calculated correctly (G(p) on [F])',
        (WidgetTester tester) async {
      // G(p) on trace [F] is false
      await tester.pumpWidget(buildTestableWidget(
        stream: streamController.stream,
        formula: formulaAlwaysTrue,
        initialValue: TestState(false),
      ));

      // Expect Cancel icon (initial result is false)
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('Displays Success when formula holds',
        (WidgetTester tester) async {
      // Start with initial G(p) = true
      await tester.pumpWidget(buildTestableWidget(
          stream: streamController.stream, formula: formulaAlwaysTrue));
      expect(find.byIcon(Icons.check_circle), findsOneWidget,
          reason: "Initial state should be true");

      // Emit states that satisfy the formula
      streamController.add(TestState(true));

      await tester.pump(); // Rebuild widget with new result
      await tester.pump(); // Rebuild widget with new result

      // Expect Check icon (still true)
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('Displays Failure when formula does not hold',
        (WidgetTester tester) async {
      // Start with initial G(p) = true
      await tester.pumpWidget(buildTestableWidget(
          stream: streamController.stream, formula: formulaAlwaysTrue));
      expect(find.byIcon(Icons.check_circle), findsOneWidget,
          reason: "Initial state should be true");

      // Emit states, one of which violates the formula
      streamController.add(TestState(true)); // Stays true
      await tester.pump();
      streamController.add(TestState(false)); // Violation -> becomes false
      await tester.pump();
      await tester.pump(); // Rebuild

      // Expect Cancel icon
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('Updates display when formula result changes',
        (WidgetTester tester) async {
      // F(p) initially false on empty trace
      await tester.pumpWidget(buildTestableWidget(
          stream: streamController.stream, formula: formulaEventuallyTrue));

      // Initially formula is false (nothing emitted yet)
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      streamController.add(TestState(false));
      await tester.pump();
      // F(p) on [F] is false.
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      streamController.add(TestState(true)); // Formula becomes true
      await tester.pump();
      await tester.pump(); // Ensure StreamBuilder rebuilds
      // F(p) on [F, T] is true.
      // Now displays true
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('Uses custom builder when provided',
        (WidgetTester tester) async {
      // G(p) initially true
      await tester.pumpWidget(
        buildTestableWidget(
          stream: streamController.stream,
          formula: formulaAlwaysTrue,
          builder: (context, result) {
            return Text(result ? 'Holds' : 'Does not hold');
          },
        ),
      );

      // Initial state (true for G(p))
      expect(find.text('Holds'), findsOneWidget);

      streamController.add(TestState(true));
      await tester.pump();
      await tester.pump(); // Rebuild
      // Stays true
      expect(find.text('Holds'), findsOneWidget);

      streamController.add(TestState(false));
      await tester.pump();
      await tester.pump(); // Rebuild
      // Becomes false
      expect(find.text('Does not hold'), findsOneWidget);
    });

    testWidgets('Handles stream closing gracefully',
        (WidgetTester tester) async {
      // G(p) initially true
      await tester.pumpWidget(buildTestableWidget(
          stream: streamController.stream, formula: formulaAlwaysTrue));
      expect(find.byIcon(Icons.check_circle), findsOneWidget); // Initial true

      streamController.add(TestState(true));
      await tester.pump();
      await tester.pump(); // Rebuild
      expect(find.byIcon(Icons.check_circle), findsOneWidget); // Stays true

      await streamController.close();
      await tester.pump(); // Process stream closing

      // Should still display the last known state (true)
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('Updates checker when stream changes',
        (WidgetTester tester) async {
      var streamController1 = StreamController<TestState>.broadcast();
      var streamController2 = StreamController<TestState>.broadcast();

      // Build with stream 1, F(p) is initially false
      await tester.pumpWidget(buildTestableWidget(
          stream: streamController1.stream, formula: formulaEventuallyTrue));
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      // Add true event to stream 1 -> F(p) becomes true
      streamController1.add(TestState(true));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Rebuild with stream 2 (which is empty) -> F(p) becomes false again
      await tester.pumpWidget(buildTestableWidget(
          stream: streamController2.stream, formula: formulaEventuallyTrue));
      await tester.pumpAndSettle(); // Ensure all frames/microtasks settle
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      // Add true event to stream 2 -> F(p) becomes true again
      streamController2.add(TestState(true));
      await tester.pump();
      await tester.pump(); // Ensure StreamBuilder rebuilds
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      streamController1.close();
      streamController2.close();
    });

    testWidgets('Updates checker when formula changes',
        (WidgetTester tester) async {
      // Start with G(p), initially true
      await tester.pumpWidget(buildTestableWidget(
          stream: streamController.stream, formula: formulaAlwaysTrue));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Add true event, stays true
      streamController.add(TestState(true));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Rebuild with G(!p), trace is [T], so G(!p) is false
      await tester.pumpWidget(buildTestableWidget(
          stream: streamController.stream, formula: formulaAlwaysFalse));
      await tester.pumpAndSettle(); // Ensure all frames/microtasks settle
      // Initial evaluation of G(!p) on empty trace (new checker) is true
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Add false event, trace is [T, F], G(!p) is still false
      streamController.add(TestState(false));
      await tester.pump();
      await tester.pump(); // Ensure StreamBuilder rebuilds
      // G(!p) starting at index 1 on trace [T, F] evaluates !p on F, which is true.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });
}
