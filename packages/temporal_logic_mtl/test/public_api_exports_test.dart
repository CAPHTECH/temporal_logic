import 'package:temporal_logic_mtl/temporal_logic_mtl.dart'
    show
        AlwaysTimed,
        EvaluationResult,
        EventuallyTimed,
        Formula,
        ReleaseTimed,
        TimeInterval,
        Trace,
        TraceEvent,
        UntilTimed,
        WeakUntilTimed,
        always,
        evaluateMtlTrace,
        state;
import 'package:test/test.dart';

void main() {
  test('re-exports the stable mtl surface', () {
    final response = state<String>((value) => value == 'response',
        name: 'response');
    final interval = TimeInterval.upTo(const Duration(seconds: 1));
    final timedEventually = EventuallyTimed<String>(response, interval);
    final timedAlways = AlwaysTimed<String>(response, interval);
    final timedUntil = UntilTimed<String>(response, response, interval);
    final timedRelease = ReleaseTimed<String>(response, response, interval);
    final timedWeakUntil =
        WeakUntilTimed<String>(response, response, interval);
    final trace = Trace<String>([
      TraceEvent(timestamp: Duration.zero, value: 'response'),
    ]);
    final formula = always<String>(timedEventually);
    final result = evaluateMtlTrace(trace, timedEventually);

    expect(interval, isA<TimeInterval>());
    expect(timedEventually, isA<EventuallyTimed<String>>());
    expect(timedAlways, isA<AlwaysTimed<String>>());
    expect(timedUntil, isA<UntilTimed<String>>());
    expect(timedRelease, isA<ReleaseTimed<String>>());
    expect(timedWeakUntil, isA<WeakUntilTimed<String>>());
    expect(formula, isA<Formula<String>>());
    expect(result, isA<EvaluationResult>());
    expect(result.holds, isTrue);
  });
}
