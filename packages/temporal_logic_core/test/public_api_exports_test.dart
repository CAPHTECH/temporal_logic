import 'package:temporal_logic_core/temporal_logic_core.dart'
    show
        Always,
        AtomicProposition,
        EvaluationResult,
        Formula,
        TimedValue,
        Trace,
        TraceEvent,
        always,
        evaluateLtl,
        evaluateTrace,
        state;
import 'package:test/test.dart';

void main() {
  test('re-exports the stable core surface', () {
    final isEven = state<int>((value) => value.isEven, name: 'isEven');
    final formula = always<int>(isEven);
    final trace = Trace<int>.fromList([2, 4, 6]);
    final timedValue = TimedValue(2, Duration.zero);
    final result = evaluateTrace(trace, formula);

    expect(isEven, isA<AtomicProposition<int>>());
    expect(formula, isA<Formula<int>>());
    expect(formula, isA<Always<int>>());
    expect(trace.events.first, isA<TraceEvent<int>>());
    expect(timedValue, isA<TimedValue<int>>());
    expect(result, isA<EvaluationResult>());
    expect(result.holds, isTrue);
    expect(evaluateLtl(formula, [2, 4, 6]), isTrue);
  });
}
