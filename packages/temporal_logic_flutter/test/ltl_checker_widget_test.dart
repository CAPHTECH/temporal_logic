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
      formulaAlwaysTrue = always(state<TestState>((s) => s.value));
      formulaAlwaysFalse = always(state<TestState>((s) => !s.value));
      formulaEventuallyTrue = eventually(state<TestState>((s) => s.value));
    });

    tearDown(() {
      streamController.close();
    });

    Widget buildTestableWidget(Stream<TestState> stream, Formula<TestState> formula) {
      return MaterialApp(
        home: Scaffold(
          body: LtlCheckerWidget<TestState>(stream: stream, formula: formula),
        ),
      );
    }

    testWidgets('Initial state before stream emits (defaults to false)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(streamController.stream, formulaAlwaysTrue));

      // Expect Cancel icon (default result is false)
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('Displays Success when formula holds', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(streamController.stream, formulaAlwaysTrue));

      // Emit states that satisfy the formula
      streamController.add(TestState(true));
      await tester.pump(); // Process stream event
      await tester.pump(); // Rebuild widget with new result
      streamController.add(TestState(true));
      await tester.pump(); // Process stream event
      await tester.pump(); // Rebuild widget with new result

      // Expect Check icon
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('Displays Failure when formula does not hold', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(streamController.stream, formulaAlwaysTrue));

      // Emit states, one of which violates the formula
      streamController.add(TestState(true));
      await tester.pump();
      await tester.pump(); // Rebuild
      streamController.add(TestState(false)); // Violation
      await tester.pump();
      await tester.pump(); // Rebuild

      // Expect Cancel icon
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('Updates display when formula result changes', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(streamController.stream, formulaEventuallyTrue));

      // Initially formula is false (nothing emitted yet)
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      streamController.add(TestState(false));
      await tester.pump();
      await tester.pump(); // Rebuild
      // Still false
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      streamController.add(TestState(true)); // Formula becomes true
      await tester.pump();
      await tester.pump(); // Rebuild
      // Now displays true
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('Uses custom builder when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LtlCheckerWidget<TestState>(
              stream: streamController.stream,
              formula: formulaAlwaysTrue,
              builder: (context, result) {
                return Text(result ? 'Holds' : 'Does not hold');
              },
            ),
          ),
        ),
      );

      // Initial state (false)
      expect(find.text('Does not hold'), findsOneWidget);

      streamController.add(TestState(true));
      await tester.pump();
      await tester.pump(); // Rebuild

      // Updated state (true)
      expect(find.text('Holds'), findsOneWidget);
    });

    testWidgets('Handles stream closing gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(streamController.stream, formulaAlwaysTrue));
      expect(find.byIcon(Icons.cancel), findsOneWidget); // Initial false

      streamController.add(TestState(true));
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
