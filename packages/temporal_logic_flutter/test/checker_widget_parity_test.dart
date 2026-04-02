import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart';

class _WidgetState {
  final bool value;

  const _WidgetState(this.value);
}

Widget _buildParityHarness({
  required Stream<_WidgetState> ltlStream,
  required Stream<TimedValue<_WidgetState>> mtlStream,
  required Formula<_WidgetState> formula,
  _WidgetState? initialValue,
  TimedValue<_WidgetState>? timedInitialValue,
  StreamEvaluationStart evaluationStart = StreamEvaluationStart.beginning,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          LtlCheckerWidget<_WidgetState>(
            stream: ltlStream,
            formula: formula,
            initialValue: initialValue,
            evaluationStart: evaluationStart,
            builder: (context, result) {
              return Text(
                'LTL:${result ? 'T' : 'F'}',
                key: const Key('ltl-output'),
              );
            },
          ),
          MtlCheckerWidget<_WidgetState>(
            stream: mtlStream,
            formula: formula,
            initialValue: timedInitialValue,
            evaluationStart: evaluationStart,
            builder: (context, result, _) {
              return Text(
                'MTL:${result ? 'T' : 'F'}',
                key: const Key('mtl-output'),
              );
            },
          ),
        ],
      ),
    ),
  );
}

void _emitPair(
  StreamController<_WidgetState> ltlController,
  StreamController<TimedValue<_WidgetState>> mtlController,
  bool value,
  int millis,
) {
  ltlController.add(_WidgetState(value));
  mtlController.add(
    TimedValue(_WidgetState(value), Duration(milliseconds: millis)),
  );
}

String _ltlText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('ltl-output'))).data!;

String _mtlText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('mtl-output'))).data!;

void main() {
  group('Widget parity', () {
    testWidgets('matches beginning semantics without an initial value',
        (WidgetTester tester) async {
      final ltlController = StreamController<_WidgetState>.broadcast();
      final mtlController =
          StreamController<TimedValue<_WidgetState>>.broadcast();
      addTearDown(ltlController.close);
      addTearDown(mtlController.close);

      final formula = Always(
        state<_WidgetState>((state) => state.value, name: 'value'),
      );

      await tester.pumpWidget(_buildParityHarness(
        ltlStream: ltlController.stream,
        mtlStream: mtlController.stream,
        formula: formula,
      ));
      await tester.pump();

      expect(_ltlText(tester), 'LTL:T');
      expect(_mtlText(tester), 'MTL:T');

      _emitPair(ltlController, mtlController, false, 100);
      await tester.pump();
      await tester.pump();
      expect(_ltlText(tester), 'LTL:F');
      expect(_mtlText(tester), 'MTL:F');

      _emitPair(ltlController, mtlController, true, 200);
      await tester.pump();
      await tester.pump();
      expect(_ltlText(tester), 'LTL:F');
      expect(_mtlText(tester), 'MTL:F');
    });

    testWidgets('matches current-state semantics with an initial value',
        (WidgetTester tester) async {
      final ltlController = StreamController<_WidgetState>.broadcast();
      final mtlController =
          StreamController<TimedValue<_WidgetState>>.broadcast();
      addTearDown(ltlController.close);
      addTearDown(mtlController.close);

      final formula = Always(
        state<_WidgetState>((state) => state.value, name: 'value'),
      );

      await tester.pumpWidget(_buildParityHarness(
        ltlStream: ltlController.stream,
        mtlStream: mtlController.stream,
        formula: formula,
        initialValue: const _WidgetState(true),
        timedInitialValue: TimedValue(const _WidgetState(true), Duration.zero),
        evaluationStart: StreamEvaluationStart.current,
      ));
      await tester.pump();

      expect(_ltlText(tester), 'LTL:T');
      expect(_mtlText(tester), 'MTL:T');

      _emitPair(ltlController, mtlController, false, 100);
      await tester.pump();
      await tester.pump();
      expect(_ltlText(tester), 'LTL:F');
      expect(_mtlText(tester), 'MTL:F');

      _emitPair(ltlController, mtlController, true, 200);
      await tester.pump();
      await tester.pump();
      expect(_ltlText(tester), 'LTL:T');
      expect(_mtlText(tester), 'MTL:T');
    });
  });
}
