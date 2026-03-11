import 'package:glados/glados.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart';

// Fixed atomic propositions covering 5 reachable truth patterns over int:
//  -2: pEven=T, pPos=F, pZero=F
//  -1: pEven=F, pPos=F, pZero=F
//   0: pEven=T, pPos=F, pZero=T
//   1: pEven=F, pPos=T, pZero=F
//   2: pEven=T, pPos=T, pZero=F
final pEven = state<int>((n) => n % 2 == 0, name: 'pEven');
final pPos = state<int>((n) => n > 0, name: 'pPos');
final pZero = state<int>((n) => n == 0, name: 'pZero');
final pTrue = state<int>((_) => true, name: 'pTrue');
final pFalse = state<int>((_) => false, name: 'pFalse');

const stateValues = [-2, -1, 0, 1, 2];

// Pre-computed depth-0 formulas
final List<Formula<int>> depth0Formulas = [pEven, pPos, pZero, pTrue, pFalse];

// Pre-computed depth-1 formulas
final List<Formula<int>> depth1Formulas = _buildDepth1();

List<Formula<int>> _buildDepth1() {
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
      return f1;
  }
}

extension TemporalLogicGenerators on Any {
  /// Trace<int> with 0-5 events, values from stateValues,
  /// sorted timestamps with small gaps (0-10ms).
  Generator<Trace<int>> get traceOfInt => combine2(
        listWithLengthInRange(0, 6, choose(stateValues)),
        listWithLengthInRange(0, 5, intInRange(0, 11)),
        (List<int> values, List<int> gaps) {
          if (values.isEmpty) return Trace<int>.empty();
          final events = <TraceEvent<int>>[];
          var ts = Duration.zero;
          for (var i = 0; i < values.length; i++) {
            if (i > 0 && i - 1 < gaps.length) {
              ts += Duration(milliseconds: gaps[i - 1]);
            }
            events.add(TraceEvent(timestamp: ts, value: values[i]));
          }
          return Trace(events);
        },
      );

  /// Depth-0 formula (atom)
  Generator<Formula<int>> get atomFormula => choose(depth0Formulas);

  /// Depth-1 formula (pre-computed pool)
  Generator<Formula<int>> get d1Formula => choose(depth1Formulas);

  /// Depth-2 formula (compose depth-1 with random operator)
  Generator<Formula<int>> get d2Formula => combine3(
        intInRange(0, 10),
        choose(depth1Formulas),
        choose(depth1Formulas),
        _buildFromOp,
      );

  /// Pure LTL formula (no MTL nodes) — same as d2Formula for core
  Generator<Formula<int>> get pureLtlFormula => d2Formula;

  /// Start index: 0..5 (covers trace.length for traces up to 5)
  Generator<int> get startIdx => choose([0, 1, 2, 3, 4, 5]);
}
