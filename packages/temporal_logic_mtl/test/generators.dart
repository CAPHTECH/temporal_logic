import 'package:glados/glados.dart';
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';

// Intentionally duplicated from core/test/generators.dart for test isolation.
// Test files are not exported across packages, so sharing is not possible.
final pEven = state<int>((n) => n % 2 == 0, name: 'pEven');
final pPos = state<int>((n) => n > 0, name: 'pPos');
final pZero = state<int>((n) => n == 0, name: 'pZero');
final pTrue = state<int>((_) => true, name: 'pTrue');
final pFalse = state<int>((_) => false, name: 'pFalse');

const stateValues = [-2, -1, 0, 1, 2];

final List<Formula<int>> depth0Formulas = [pEven, pPos, pZero, pTrue, pFalse];

// Pure LTL depth-1 formulas (no timed operators)
final List<Formula<int>> pureLtlDepth1 = _buildPureLtlDepth1();

List<Formula<int>> _buildPureLtlDepth1() {
  final result = <Formula<int>>[...depth0Formulas];
  for (final f in depth0Formulas) {
    result.addAll([Not(f), Always(f), Eventually(f), Next(f)]);
  }
  for (final f1 in depth0Formulas) {
    for (final f2 in depth0Formulas) {
      result.addAll([
        And(f1, f2),
        Or(f1, f2),
        Implies(f1, f2),
        Until(f1, f2),
        WeakUntil(f1, f2),
        Release(f1, f2),
      ]);
    }
  }
  return result;
}

Formula<int> _buildFromOp(int op, Formula<int> f1, Formula<int> f2) {
  switch (op % 10) {
    case 0:
      return Not(f1);
    case 1:
      return And(f1, f2);
    case 2:
      return Or(f1, f2);
    case 3:
      return Implies(f1, f2);
    case 4:
      return Next(f1);
    case 5:
      return Always(f1);
    case 6:
      return Eventually(f1);
    case 7:
      return Until(f1, f2);
    case 8:
      return WeakUntil(f1, f2);
    case 9:
      return Release(f1, f2);
    default:
      throw StateError('unreachable: op % 10 covers 0-9');
  }
}

Formula<int> _buildTimedFormula(
    int op, Formula<int> f1, Formula<int> f2, TimeInterval iv) {
  switch (op) {
    case 0:
      return EventuallyTimed(f1, iv);
    case 1:
      return AlwaysTimed(f1, iv);
    case 2:
      return UntilTimed(f1, f2, iv);
    case 3:
      return ReleaseTimed(f1, f2, iv);
    case 4:
      return WeakUntilTimed(f1, f2, iv);
    default:
      throw StateError('unreachable: callers use choose([0..4])');
  }
}

extension MtlGenerators on Any {
  /// Trace<int> with 0-5 events and realistic timestamps (gaps 0-10ms).
  Generator<Trace<int>> get traceOfInt => combine2(
        listWithLengthInRange(0, 6, choose(stateValues)),
        listWithLengthInRange(0, 5, intInRange(0, 11)),
        (List<int> values, List<int> gaps) {
          if (values.isEmpty) return Trace<int>.empty();
          final events = <TraceEvent<int>>[];
          var ts = Duration.zero;
          for (var i = 0; i < values.length; i++) {
            // When values outnumber gaps, remaining events share the last
            // timestamp — this is intentional to exercise concurrent-event paths.
            if (i > 0 && i - 1 < gaps.length) {
              ts += Duration(milliseconds: gaps[i - 1]);
            }
            events.add(TraceEvent(timestamp: ts, value: values[i]));
          }
          return Trace(events);
        },
      );

  /// TimeInterval with lb <= ub, scaled to plausible trace spans (0-50ms).
  Generator<TimeInterval> get timeInterval => combine2(
        intInRange(0, 51),
        intInRange(0, 51),
        (int lb, int ubOffset) {
          return TimeInterval(
            Duration(milliseconds: lb),
            Duration(milliseconds: lb + ubOffset),
          );
        },
      );

  /// TimeInterval derived from the given trace's actual timestamp span.
  Generator<TimeInterval> traceRelativeInterval(Trace<int> trace) {
    final spanMs = trace.events.length < 2
        ? 10
        : (trace.events.last.timestamp - trace.events.first.timestamp)
                .inMilliseconds +
            1;
    return combine2(
      intInRange(0, spanMs + 1),
      intInRange(0, spanMs + 1),
      (int a, int b) {
        final lb = a < b ? a : b;
        final ub = a < b ? b : a;
        return TimeInterval(
          Duration(milliseconds: lb),
          Duration(milliseconds: ub),
        );
      },
    );
  }

  /// Depth-0 formula (atom)
  Generator<Formula<int>> get atomFormula => choose(depth0Formulas);

  /// Pure LTL depth-1 formula
  Generator<Formula<int>> get pureLtlD1 => choose(pureLtlDepth1);

  /// Pure LTL depth-2 formula
  Generator<Formula<int>> get pureLtlD2 => combine3(
        intInRange(0, 10),
        choose(pureLtlDepth1),
        choose(pureLtlDepth1),
        _buildFromOp,
      );

  /// Timed formula: wraps atoms with timed operators and random intervals.
  Generator<Formula<int>> get timedFormula => combine4(
        choose([0, 1, 2, 3, 4]),
        atomFormula,
        atomFormula,
        timeInterval,
        _buildTimedFormula,
      );

  /// Depth-2 timed formula: wraps LTL depth-1 subformulas with timed operators.
  Generator<Formula<int>> get timedD2Formula => combine4(
        choose([0, 1, 2, 3, 4]),
        pureLtlD1,
        pureLtlD1,
        timeInterval,
        _buildTimedFormula,
      );

  /// Nested timed formula: timed operator over timed subformulas (depth-2 timed).
  /// Produces shapes like G_I(F_J(p)), U_I(p, R_J(q, r)), etc.
  Generator<Formula<int>> get nestedTimedFormula => combine4(
        choose([0, 1, 2, 3, 4]),
        timedFormula,
        timedFormula,
        timeInterval,
        _buildTimedFormula,
      );

  /// Trace paired with a trace-relative interval (dependent generation).
  Generator<(Trace<int>, TimeInterval)> get traceWithRelativeInterval =>
      traceOfInt.bind(
        (trace) => traceRelativeInterval(trace).map((iv) => (trace, iv)),
      );

  /// Start index dependent on trace length (avoids clamp bias).
  Generator<int> startIdxFor(Trace<int> trace) =>
      intInRange(0, trace.length + 1);

  /// Start index: 0..5
  Generator<int> get startIdx => choose([0, 1, 2, 3, 4, 5]);
}
