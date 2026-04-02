import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart'
    show
        CheckStatus,
        EventuallyTimed,
        LtlCheckerWidget,
        MtlCheckerWidget,
        ReleaseTimed,
        SustainedStateCheckerWidget,
        StreamEvaluationStart,
        StreamLtlChecker,
        StreamMtlChecker,
        StreamSustainedStateChecker,
        TimeInterval,
        TraceRecorder,
        WeakUntilTimed,
        evaluateMtlTrace,
        state;
import 'package:temporal_logic_flutter/temporal_logic_flutter_test.dart'
    show satisfiesLtl;

class _ExportTestState {
  final bool value;

  _ExportTestState(this.value);
}

void main() {
  test('re-exports the public flutter surface', () {
    final interval = TimeInterval.upTo(const Duration(seconds: 1));
    final ltlFormula = state<_ExportTestState>((s) => s.value);
    final timedFormula = EventuallyTimed<_ExportTestState>(ltlFormula, interval);
    final releaseFormula = ReleaseTimed<_ExportTestState>(
      ltlFormula,
      state<_ExportTestState>((s) => !s.value),
      interval,
    );
    final weakUntilFormula = WeakUntilTimed<_ExportTestState>(
      ltlFormula,
      state<_ExportTestState>((s) => !s.value),
      interval,
    );
    final checkerType = StreamLtlChecker<_ExportTestState>;
    final mtlCheckerType = StreamMtlChecker<_ExportTestState>;
    final sustainedCheckerType = StreamSustainedStateChecker<_ExportTestState>;
    final widgetType = LtlCheckerWidget<_ExportTestState>;
    final mtlWidgetType = MtlCheckerWidget<_ExportTestState>;
    final sustainedWidgetType = SustainedStateCheckerWidget<_ExportTestState>;
    final recorderType = TraceRecorder<_ExportTestState>;
    final evaluationStart = StreamEvaluationStart.current;
    final status = CheckStatus.success;
    final matcher = satisfiesLtl<_ExportTestState>(ltlFormula);
    final mtlEvaluator = evaluateMtlTrace<_ExportTestState>;

    expect(interval, isA<TimeInterval>());
    expect(timedFormula, isA<EventuallyTimed<_ExportTestState>>());
    expect(releaseFormula, isA<ReleaseTimed<_ExportTestState>>());
    expect(weakUntilFormula, isA<WeakUntilTimed<_ExportTestState>>());
    expect(checkerType, isA<Type>());
    expect(mtlCheckerType, isA<Type>());
    expect(sustainedCheckerType, isA<Type>());
    expect(widgetType, isA<Type>());
    expect(mtlWidgetType, isA<Type>());
    expect(sustainedWidgetType, isA<Type>());
    expect(recorderType, isA<Type>());
    expect(evaluationStart, StreamEvaluationStart.current);
    expect(status, CheckStatus.success);
    expect(matcher, isNotNull);
    expect(mtlEvaluator, isNotNull);
  });
}
