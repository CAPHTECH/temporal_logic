import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart';

class _ProbeState {
  final bool value;

  const _ProbeState(this.value);
}

class _EvaluationCounter {
  int calls = 0;

  bool evaluate(_ProbeState state) {
    calls++;
    return state.value;
  }
}

Future<void> _flushWidgetUpdates(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Widget _buildLtlWidget({
  required Stream<_ProbeState> stream,
  required Formula<_ProbeState> formula,
  _ProbeState? initialValue,
  StreamEvaluationStart evaluationStart = StreamEvaluationStart.beginning,
}) {
  return MaterialApp(
    home: Scaffold(
      body: LtlCheckerWidget<_ProbeState>(
        stream: stream,
        formula: formula,
        initialValue: initialValue,
        evaluationStart: evaluationStart,
      ),
    ),
  );
}

Widget _buildMtlWidget({
  required Stream<TimedValue<_ProbeState>> stream,
  required Formula<_ProbeState> formula,
  TimedValue<_ProbeState>? initialValue,
  StreamEvaluationStart evaluationStart = StreamEvaluationStart.beginning,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MtlCheckerWidget<_ProbeState>(
        stream: stream,
        formula: formula,
        initialValue: initialValue,
        evaluationStart: evaluationStart,
      ),
    ),
  );
}

void main() {
  group('LtlCheckerWidget reinitialization contract', () {
    testWidgets('does not reinitialize for identical inputs',
        (WidgetTester tester) async {
      final counter = _EvaluationCounter();
      final streamController = StreamController<_ProbeState>.broadcast();
      addTearDown(streamController.close);

      final formula = eventually(
        state<_ProbeState>(counter.evaluate, name: 'probe'),
      );

      await tester.pumpWidget(_buildLtlWidget(
        stream: streamController.stream,
        formula: formula,
        initialValue: const _ProbeState(false),
      ));
      await _flushWidgetUpdates(tester);

      expect(counter.calls, 2);
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      await tester.pumpWidget(_buildLtlWidget(
        stream: streamController.stream,
        formula: formula,
        initialValue: const _ProbeState(false),
      ));
      await _flushWidgetUpdates(tester);

      expect(counter.calls, 2);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('reinitializes when initialValue changes',
        (WidgetTester tester) async {
      final counter = _EvaluationCounter();
      final streamController = StreamController<_ProbeState>.broadcast();
      addTearDown(streamController.close);

      final formula = eventually(
        state<_ProbeState>(counter.evaluate, name: 'probe'),
      );

      await tester.pumpWidget(_buildLtlWidget(
        stream: streamController.stream,
        formula: formula,
        initialValue: const _ProbeState(true),
      ));
      await _flushWidgetUpdates(tester);

      expect(counter.calls, 2);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.pumpWidget(_buildLtlWidget(
        stream: streamController.stream,
        formula: formula,
        initialValue: const _ProbeState(false),
      ));
      await _flushWidgetUpdates(tester);

      expect(counter.calls, 4);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('reinitializes when evaluationStart changes',
        (WidgetTester tester) async {
      final streamController = StreamController<_ProbeState>.broadcast();
      addTearDown(streamController.close);

      final formula = eventually(
        state<_ProbeState>((state) => state.value, name: 'probe'),
      );

      await tester.pumpWidget(_buildLtlWidget(
        stream: streamController.stream,
        formula: formula,
        initialValue: const _ProbeState(false),
        evaluationStart: StreamEvaluationStart.beginning,
      ));
      await _flushWidgetUpdates(tester);
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      streamController.add(const _ProbeState(true));
      await _flushWidgetUpdates(tester);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.pumpWidget(_buildLtlWidget(
        stream: streamController.stream,
        formula: formula,
        initialValue: const _ProbeState(false),
        evaluationStart: StreamEvaluationStart.current,
      ));
      await _flushWidgetUpdates(tester);

      streamController.add(const _ProbeState(false));
      await _flushWidgetUpdates(tester);

      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });
  });

  group('MtlCheckerWidget reinitialization contract', () {
    TimedValue<_ProbeState> timed(_ProbeState state, int milliseconds) {
      return TimedValue(state, Duration(milliseconds: milliseconds));
    }

    testWidgets('does not reinitialize for identical inputs',
        (WidgetTester tester) async {
      final counter = _EvaluationCounter();
      final streamController =
          StreamController<TimedValue<_ProbeState>>.broadcast();
      addTearDown(streamController.close);

      final formula = EventuallyTimed<_ProbeState>(
        state<_ProbeState>(counter.evaluate, name: 'probe'),
        TimeInterval(Duration.zero, const Duration(milliseconds: 100)),
      );

      await tester.pumpWidget(_buildMtlWidget(
        stream: streamController.stream,
        formula: formula,
        initialValue: timed(const _ProbeState(false), 0),
      ));
      await _flushWidgetUpdates(tester);

      expect(counter.calls, 2);
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      await tester.pumpWidget(_buildMtlWidget(
        stream: streamController.stream,
        formula: formula,
        initialValue: timed(const _ProbeState(false), 0),
      ));
      await _flushWidgetUpdates(tester);

      expect(counter.calls, 2);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('reinitializes when initialValue changes',
        (WidgetTester tester) async {
      final counter = _EvaluationCounter();
      final streamController =
          StreamController<TimedValue<_ProbeState>>.broadcast();
      addTearDown(streamController.close);

      final formula = EventuallyTimed<_ProbeState>(
        state<_ProbeState>(counter.evaluate, name: 'probe'),
        TimeInterval(Duration.zero, const Duration(milliseconds: 100)),
      );

      await tester.pumpWidget(_buildMtlWidget(
        stream: streamController.stream,
        formula: formula,
        initialValue: timed(const _ProbeState(true), 0),
      ));
      await _flushWidgetUpdates(tester);

      expect(counter.calls, 2);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.pumpWidget(_buildMtlWidget(
        stream: streamController.stream,
        formula: formula,
        initialValue: timed(const _ProbeState(false), 0),
      ));
      await _flushWidgetUpdates(tester);

      expect(counter.calls, 4);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('reinitializes when evaluationStart changes',
        (WidgetTester tester) async {
      final streamController =
          StreamController<TimedValue<_ProbeState>>.broadcast();
      addTearDown(streamController.close);

      final formula = EventuallyTimed<_ProbeState>(
        state<_ProbeState>((state) => state.value, name: 'probe'),
        TimeInterval(Duration.zero, const Duration(milliseconds: 100)),
      );

      await tester.pumpWidget(_buildMtlWidget(
        stream: streamController.stream,
        formula: formula,
        initialValue: timed(const _ProbeState(false), 0),
        evaluationStart: StreamEvaluationStart.beginning,
      ));
      await _flushWidgetUpdates(tester);
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      streamController.add(timed(const _ProbeState(true), 10));
      await _flushWidgetUpdates(tester);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.pumpWidget(_buildMtlWidget(
        stream: streamController.stream,
        formula: formula,
        initialValue: timed(const _ProbeState(false), 0),
        evaluationStart: StreamEvaluationStart.current,
      ));
      await _flushWidgetUpdates(tester);

      streamController.add(timed(const _ProbeState(false), 20));
      await _flushWidgetUpdates(tester);

      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });
  });
}
