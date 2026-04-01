import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart';

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
    late Formula<TestState> formulaAlwaysFalseTimed;
    late Formula<TestState> formulaEventuallyTrueTimed;

    setUp(() {
      streamController = StreamController<TimedValue<TestState>>.broadcast();
      formulaAlwaysTrueTimed = AlwaysTimed<TestState>(
        state<TestState>((s) => s.value),
        TimeInterval(Duration.zero, const Duration(milliseconds: 100)),
      );
      formulaAlwaysFalseTimed = AlwaysTimed<TestState>(
        state<TestState>((s) => !s.value),
        TimeInterval(Duration.zero, const Duration(milliseconds: 100)),
      );
      formulaEventuallyTrueTimed = EventuallyTimed<TestState>(
        state<TestState>((s) => s.value),
        TimeInterval(Duration.zero, const Duration(milliseconds: 200)),
      );
    });

    tearDown(() async {
      if (!streamController.isClosed) {
        await streamController.close();
      }
    });

    Widget buildTestableWidget(
      Formula<TestState> formula, {
      TimedValue<TestState>? initialValue,
      StreamEvaluationStart evaluationStart = StreamEvaluationStart.beginning,
      Widget Function(BuildContext, bool, EvaluationResult)? builder,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: MtlCheckerWidget<TestState>(
            stream: streamController.stream,
            formula: formula,
            initialValue: initialValue,
            evaluationStart: evaluationStart,
            builder: builder,
          ),
        ),
      );
    }

    TimedValue<TestState> timed(TestState state, Duration timeFromStart) =>
        TimedValue(state, timeFromStart);

    testWidgets('Initial state reflects the initial evaluation result',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(formulaEventuallyTrueTimed));

      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('EventuallyTimed'));
    });

    testWidgets('Displays success when formula holds',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        formulaAlwaysTrueTimed,
        initialValue: timed(TestState(true), Duration.zero),
      ));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      streamController
          .add(timed(TestState(true), const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump();
      streamController
          .add(timed(TestState(true), const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);
      expect(find.byTooltip('Formula holds'), findsOneWidget);
    });

    testWidgets('Displays failure when formula does not hold',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        formulaAlwaysTrueTimed,
        initialValue: timed(TestState(true), Duration.zero),
      ));

      streamController
          .add(timed(TestState(true), const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump();
      streamController
          .add(timed(TestState(false), const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('AlwaysTimed failed'));
    });

    testWidgets('Updates display when formula result changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(formulaEventuallyTrueTimed));

      expect(find.byIcon(Icons.cancel), findsOneWidget);

      streamController
          .add(timed(TestState(false), const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      streamController
          .add(timed(TestState(true), const Duration(milliseconds: 150)));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('Uses custom builder when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          formulaAlwaysTrueTimed,
          initialValue: timed(TestState(true), Duration.zero),
          builder: (context, result, details) {
            return Text(
              result
                  ? 'MTL Holds'
                  : 'MTL Does not hold (${details.reason ?? 'no reason'})',
            );
          },
        ),
      );

      expect(find.text('MTL Holds'), findsOneWidget);

      streamController
          .add(timed(TestState(true), const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump();

      expect(find.text('MTL Holds'), findsOneWidget);
    });

    testWidgets('Recomputes the initial result when inputs change',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        formulaAlwaysTrueTimed,
        initialValue: timed(TestState(true), Duration.zero),
      ));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.pumpWidget(buildTestableWidget(formulaEventuallyTrueTimed));
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);

      await tester.pumpWidget(buildTestableWidget(
        formulaAlwaysFalseTimed,
        initialValue: timed(TestState(true), Duration.zero),
      ));
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('AlwaysTimed failed'));
    });

    testWidgets('Supports evaluating from the current state when requested',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        formulaEventuallyTrueTimed,
        evaluationStart: StreamEvaluationStart.current,
      ));

      streamController
          .add(timed(TestState(true), const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      streamController
          .add(timed(TestState(false), const Duration(milliseconds: 150)));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('Handles stream closing gracefully',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        formulaAlwaysTrueTimed,
        initialValue: timed(TestState(true), Duration.zero),
      ));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      streamController
          .add(timed(TestState(true), const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await streamController.close();
      await tester.pump();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);
    });
  });
}
