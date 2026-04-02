import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';
import 'package:temporal_logic_mtl/src/mtl_legacy_helpers.dart';
import 'package:test/test.dart';

void main() {
  final trace = Trace([
    TraceEvent(value: 'a', timestamp: Duration.zero),
    TraceEvent(value: 'b', timestamp: const Duration(milliseconds: 100)),
    TraceEvent(value: 'c', timestamp: const Duration(milliseconds: 200)),
  ]);

  final pB = state<String>((s) => s == 'b', name: 'pB');
  final pC = state<String>((s) => s == 'c', name: 'pC');
  final pNotC = state<String>((s) => s != 'c', name: 'pNotC');

  test('legacy eventually helper matches the timed evaluator', () {
    final interval = TimeInterval.upTo(const Duration(milliseconds: 100));

    expect(checkEventuallyWithin(trace, interval, pB), isTrue);
    expect(
      evaluateMtlTrace(trace, EventuallyTimed(pB, interval)).holds,
      isTrue,
    );
  });

  test('legacy always helper remains a compatibility layer', () {
    final interval = TimeInterval.upTo(const Duration(milliseconds: 100));

    expect(checkAlwaysWithin(trace, interval, pNotC), isTrue);
    expect(
      evaluateMtlTrace(trace, AlwaysTimed(pNotC, interval)).holds,
      isTrue,
    );
  });

  test('legacy until helper matches the timed evaluator', () {
    final interval = TimeInterval.upTo(const Duration(milliseconds: 200));

    expect(checkUntilWithin(trace, interval, pNotC, pC), isTrue);
    expect(
      evaluateMtlTrace(trace, UntilTimed(pNotC, pC, interval)).holds,
      isTrue,
    );
  });
}
