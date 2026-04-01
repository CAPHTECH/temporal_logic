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
      streamController = StreamController<TimedValue<TestState>>.broadcast();
    });

    tearDown(() async {
      if (!streamController.isClosed) {
        await streamController.close();
      }
    });

    Widget buildTestableWidget({
      TimedValue<TestState>? initialValue,
      Widget Function(BuildContext, CheckStatus)? builder,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SustainedStateCheckerWidget<TestState>(
            stream: streamController.stream,
            targetState: targetState,
            sustainDuration: sustainDuration,
            initialValue: initialValue,
            builder: builder,
          ),
        ),
      );
    }

    TimedValue<TestState> timed(TestState state, Duration timeFromStart) =>
        TimedValue(state, timeFromStart);

    testWidgets('Initial state is failure when initial value is not target',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        initialValue: timed(TestState.initial, Duration.zero),
      ));

      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('Initial state is pending when initial value matches target',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        initialValue: timed(TestState.target, Duration.zero),
      ));

      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('Transitions to success when target state is sustained',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        initialValue: timed(TestState.initial, Duration.zero),
      ));
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      streamController
          .add(timed(TestState.target, const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);

      streamController.add(
        timed(TestState.target, const Duration(milliseconds: 120)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('Transitions to failure if it leaves target early',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        initialValue: timed(TestState.initial, Duration.zero),
      ));

      streamController
          .add(timed(TestState.target, const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump();

      streamController
          .add(timed(TestState.other, const Duration(milliseconds: 60)));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('Resets to pending and succeeds if it re-enters target',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        initialValue: timed(TestState.initial, Duration.zero),
      ));

      streamController
          .add(timed(TestState.target, const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);

      streamController
          .add(timed(TestState.other, const Duration(milliseconds: 60)));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      streamController
          .add(timed(TestState.target, const Duration(milliseconds: 70)));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);

      streamController
          .add(timed(TestState.target, const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('Uses custom builder when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          initialValue: timed(TestState.initial, Duration.zero),
          builder: (context, status) => Text('Status: ${status.name}'),
        ),
      );

      expect(find.text('Status: failure'), findsOneWidget);

      streamController
          .add(timed(TestState.target, const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump();
      expect(find.text('Status: pending'), findsOneWidget);

      streamController
          .add(timed(TestState.target, const Duration(milliseconds: 150)));
      await tester.pump();
      await tester.pump();
      expect(find.text('Status: success'), findsOneWidget);
    });

    testWidgets('Handles stream closing gracefully after success',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        initialValue: timed(TestState.initial, Duration.zero),
      ));

      streamController
          .add(timed(TestState.target, const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump();
      streamController
          .add(timed(TestState.target, const Duration(milliseconds: 150)));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await streamController.close();
      await tester.pump();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('Transitions to failure if stream ends while pending',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        initialValue: timed(TestState.initial, Duration.zero),
      ));

      streamController
          .add(timed(TestState.target, const Duration(milliseconds: 10)));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);

      await streamController.close();
      await tester.pump();

      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });
  });
}
