import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';
import 'package:test/test.dart';

/// Helper to evaluate MTL formulas.
EvaluationResult evalM<T>(Trace<T> trace, Formula<T> formula,
    {int startIndex = 0}) {
  return evaluateMtlTrace(trace, formula, startIndex: startIndex);
}

void main() {
  // Shared trace: (a @ 0ms) -> (b @ 100ms) -> (c @ 300ms) -> (d @ 600ms) -> (e @ 1000ms)
  final va = TraceEvent(value: 'a', timestamp: Duration.zero);
  final vb =
      TraceEvent(value: 'b', timestamp: const Duration(milliseconds: 100));
  final vc =
      TraceEvent(value: 'c', timestamp: const Duration(milliseconds: 300));
  final vd =
      TraceEvent(value: 'd', timestamp: const Duration(milliseconds: 600));
  final ve =
      TraceEvent(value: 'e', timestamp: const Duration(milliseconds: 1000));
  final trace = Trace([va, vb, vc, vd, ve]);

  final pA = state<String>((s) => s == 'a', name: 'pA');
  final pB = state<String>((s) => s == 'b', name: 'pB');
  final pC = state<String>((s) => s == 'c', name: 'pC');
  final pD = state<String>((s) => s == 'd', name: 'pD');
  final pE = state<String>((s) => s == 'e', name: 'pE');
  final pTrue = state<String>((_) => true, name: 'pTrue');
  final pFalse = state<String>((_) => false, name: 'pFalse');
  final pNotE = state<String>((s) => s != 'e', name: 'pNotE');

  group('EventuallyTimed edge cases', () {
    test('zero-width interval at t>0 where event exists', () {
      // F_[100ms,100ms] pB from index 0 -> event 'b' at exactly 100ms
      final formula = EventuallyTimed(
          pB, TimeInterval.exactly(const Duration(milliseconds: 100)));
      expect(evalM(trace, formula).holds, isTrue);
    });

    test('zero-width interval at t>0 where no event exists', () {
      // F_[200ms,200ms] pTrue from index 0 -> no event at exactly 200ms
      final formula = EventuallyTimed(
          pTrue, TimeInterval.exactly(const Duration(milliseconds: 200)));
      expect(evalM(trace, formula).holds, isFalse);
    });

    test('interval entirely before any matching event', () {
      // F_[0,50ms] pB -> 'b' is at 100ms, outside [0,50]
      final formula = EventuallyTimed(
          pB, TimeInterval(Duration.zero, const Duration(milliseconds: 50)));
      expect(evalM(trace, formula).holds, isFalse);
    });

    test('interval entirely after all events', () {
      // F_[1500ms,2000ms] pTrue -> no events in that range
      final formula = EventuallyTimed(
          pTrue,
          TimeInterval(const Duration(milliseconds: 1500),
              const Duration(milliseconds: 2000)));
      expect(evalM(trace, formula).holds, isFalse);
    });

    test('startIndex > 0 shifts interval anchor', () {
      // From index 0: F_[0,100ms] pB -> true (b at 100ms)
      expect(
          evalM(
                  trace,
                  EventuallyTimed(
                      pB, TimeInterval.upTo(const Duration(milliseconds: 100))))
              .holds,
          isTrue);

      // From index 1 (t=100ms): F_[0,100ms] pC -> anchored at 100ms, so [100ms,200ms]
      // 'c' is at 300ms, outside. Should be false.
      expect(
          evalM(
                  trace,
                  EventuallyTimed(
                      pC, TimeInterval.upTo(const Duration(milliseconds: 100))),
                  startIndex: 1)
              .holds,
          isFalse);

      // From index 1 (t=100ms): F_[0,200ms] pC -> anchored at 100ms, so [100ms,300ms]
      // 'c' is at 300ms, timeDiff = 200ms, inside [0,200ms]. Should be true.
      expect(
          evalM(
                  trace,
                  EventuallyTimed(
                      pC, TimeInterval.upTo(const Duration(milliseconds: 200))),
                  startIndex: 1)
              .holds,
          isTrue);
    });

    test('event at exact lower bound', () {
      // F_[100ms,500ms] pB from index 0 -> 'b' at 100ms = lower bound
      final formula = EventuallyTimed(
          pB,
          TimeInterval(const Duration(milliseconds: 100),
              const Duration(milliseconds: 500)));
      expect(evalM(trace, formula).holds, isTrue);
    });

    test('event at exact upper bound', () {
      // F_[500ms,1000ms] pE from index 0 -> 'e' at 1000ms = upper bound
      final formula = EventuallyTimed(
          pE,
          TimeInterval(const Duration(milliseconds: 500),
              const Duration(milliseconds: 1000)));
      expect(evalM(trace, formula).holds, isTrue);
    });

    test('event 1ms outside upper bound', () {
      // F_[500ms,999ms] pE from index 0 -> 'e' at 1000ms, just outside
      final formula = EventuallyTimed(
          pE,
          TimeInterval(const Duration(milliseconds: 500),
              const Duration(milliseconds: 999)));
      expect(evalM(trace, formula).holds, isFalse);
    });

    test('event 1ms outside lower bound', () {
      // F_[101ms,500ms] pB from index 0 -> 'b' at 100ms, just outside lower
      final formula = EventuallyTimed(
          pB,
          TimeInterval(const Duration(milliseconds: 101),
              const Duration(milliseconds: 500)));
      expect(evalM(trace, formula).holds, isFalse);
    });
  });

  group('AlwaysTimed edge cases', () {
    test('no events in interval (vacuous truth with gap)', () {
      // G_[150ms,250ms] pFalse from index 0 -> no events in [150ms,250ms], vacuously true
      final formula = AlwaysTimed(
          pFalse,
          TimeInterval(const Duration(milliseconds: 150),
              const Duration(milliseconds: 250)));
      expect(evalM(trace, formula).holds, isTrue);
    });

    test('single event in interval', () {
      // G_[100ms,200ms] pB from index 0 -> only 'b' at 100ms in [100ms,200ms]
      final formula = AlwaysTimed(
          pB,
          TimeInterval(const Duration(milliseconds: 100),
              const Duration(milliseconds: 200)));
      expect(evalM(trace, formula).holds, isTrue);
    });

    test('single event in interval fails', () {
      // G_[100ms,200ms] pA from index 0 -> only 'b' at 100ms, pA fails
      final formula = AlwaysTimed(
          pA,
          TimeInterval(const Duration(milliseconds: 100),
              const Duration(milliseconds: 200)));
      expect(evalM(trace, formula).holds, isFalse);
    });

    test('startIndex > 0 shifts interval anchor', () {
      // From index 2 (t=300ms): G_[0,300ms] pNotE
      // Events at 300ms('c'), 600ms('d'). Both satisfy pNotE.
      expect(
          evalM(
                  trace,
                  AlwaysTimed(pNotE,
                      TimeInterval.upTo(const Duration(milliseconds: 300))),
                  startIndex: 2)
              .holds,
          isTrue);

      // From index 2 (t=300ms): G_[0,700ms] pNotE
      // Events at 300ms('c'), 600ms('d'), 1000ms('e'). 'e' fails pNotE.
      expect(
          evalM(
                  trace,
                  AlwaysTimed(pNotE,
                      TimeInterval.upTo(const Duration(milliseconds: 700))),
                  startIndex: 2)
              .holds,
          isFalse);
    });

    test('event at exact lower and upper bounds must hold', () {
      // G_[100ms,300ms] (s == b || s == c) from index 0
      final pBorC = state<String>((s) => s == 'b' || s == 'c', name: 'pBorC');
      final formula = AlwaysTimed(
          pBorC,
          TimeInterval(const Duration(milliseconds: 100),
              const Duration(milliseconds: 300)));
      expect(evalM(trace, formula).holds, isTrue);
    });
  });

  group('UntilTimed edge cases', () {
    test('neither condition holds', () {
      // pFalse U_[0,1000ms] pFalse -> both false, fails
      final formula = UntilTimed(pFalse, pFalse,
          TimeInterval.upTo(const Duration(milliseconds: 1000)));
      expect(evalM(trace, formula).holds, isFalse);
    });

    test('right holds only at exact lower bound', () {
      // pNotE U_[100ms,100ms] pB from index 0 -> 'b' at 100ms exactly
      final formula = UntilTimed(
          pNotE, pB, TimeInterval.exactly(const Duration(milliseconds: 100)));
      // pNotE must hold for indices before 'b' (only index 0, 'a' -> true)
      expect(evalM(trace, formula).holds, isTrue);
    });

    test('right holds only at exact upper bound', () {
      // pNotE U_[500ms,600ms] pD from index 0 -> 'd' at 600ms
      final formula = UntilTimed(
          pNotE,
          pD,
          TimeInterval(const Duration(milliseconds: 500),
              const Duration(milliseconds: 600)));
      // pNotE must hold for all indices 0..2 (a,b,c -> all not 'e')
      expect(evalM(trace, formula).holds, isTrue);
    });

    test('left fails immediately', () {
      // pFalse U_[0,1000ms] pE -> left fails at index 0
      final formula = UntilTimed(
          pFalse, pE, TimeInterval.upTo(const Duration(milliseconds: 1000)));
      expect(evalM(trace, formula).holds, isFalse);
    });

    test('startIndex > 0', () {
      // From index 2 (t=300ms): pNotE U_[0,300ms] pD
      // timeDiff for 'd' from 300ms = 300ms, in [0,300ms].
      // pNotE must hold at index 2 ('c' -> true).
      expect(
          evalM(
                  trace,
                  UntilTimed(pNotE, pD,
                      TimeInterval.upTo(const Duration(milliseconds: 300))),
                  startIndex: 2)
              .holds,
          isTrue);

      // From index 2 (t=300ms): pNotE U_[0,200ms] pD
      // timeDiff for 'd' from 300ms = 300ms, outside [0,200ms]. Fails.
      expect(
          evalM(
                  trace,
                  UntilTimed(pNotE, pD,
                      TimeInterval.upTo(const Duration(milliseconds: 200))),
                  startIndex: 2)
              .holds,
          isFalse);
    });

    test('left fails before interval opens (lowerBound > 0)', () {
      // pA U_[200ms,600ms] pD from index 0
      // pA fails at index 1 (t=100ms), which is before the interval opens at 200ms.
      // The implementation requires left from startIndex onward, so this should fail.
      final formula = UntilTimed(
          pA,
          pD,
          TimeInterval(const Duration(milliseconds: 200),
              const Duration(milliseconds: 600)));
      expect(evalM(trace, formula).holds, isFalse);
    });
  });

  group('ReleaseTimed edge cases', () {
    test('right holds throughout (left never releases)', () {
      // pFalse R_[0,600ms] pNotE -> right (pNotE) holds for all events in [0,600ms]
      // left (pFalse) never holds. G_I pNotE holds, so Release holds.
      final formula = ReleaseTimed(
          pFalse, pNotE, TimeInterval.upTo(const Duration(milliseconds: 600)));
      expect(evalM(trace, formula).holds, isTrue);
    });

    test('right fails at one point', () {
      // pFalse R_[0,1000ms] pNotE -> 'e' at 1000ms fails pNotE
      // left (pFalse) never holds. G_I pNotE fails. Release = !(!pFalse U_I !pNotE).
      // !pFalse = pTrue, !pNotE = pE. pTrue U_[0,1000ms] pE -> pE at 1000ms, pTrue holds before -> Until holds.
      // Release = !true = false.
      final formula = ReleaseTimed(
          pFalse, pNotE, TimeInterval.upTo(const Duration(milliseconds: 1000)));
      expect(evalM(trace, formula).holds, isFalse);
    });

    test('startIndex > 0', () {
      // From index 3 (t=600ms): pFalse R_[0,400ms] pTrue
      // All events in [600ms, 1000ms] satisfy pTrue. Release holds.
      expect(
          evalM(
                  trace,
                  ReleaseTimed(pFalse, pTrue,
                      TimeInterval.upTo(const Duration(milliseconds: 400))),
                  startIndex: 3)
              .holds,
          isTrue);
    });

    test('left releases exactly when right fails', () {
      // pE R_[0,1000ms] pNotE from index 0
      // Release = !(!pE U_[0,1000ms] !pNotE) = !(pNotE_neg U pE_neg)
      // !pE holds at indices 0-3, !pNotE = pE holds at index 4 (t=1000ms)
      // Until: !pE(true) until !pNotE(pE at 1000ms) -> holds. Release = false.
      final formula = ReleaseTimed(
          pE, pNotE, TimeInterval.upTo(const Duration(milliseconds: 1000)));
      expect(evalM(trace, formula).holds, isFalse);
    });
  });

  group('WeakUntilTimed edge cases', () {
    test('left holds throughout (G_I path)', () {
      // pNotE W_[0,600ms] pFalse -> G_[0,600ms] pNotE holds (a,b,c,d all not 'e')
      final formula = WeakUntilTimed(
          pNotE, pFalse, TimeInterval.upTo(const Duration(milliseconds: 600)));
      expect(evalM(trace, formula).holds, isTrue);
    });

    test('both paths fail', () {
      // pA W_[0,600ms] pFalse -> G_[0,600ms] pA fails at index 1.
      // pA U_[0,600ms] pFalse -> pFalse never holds. Both fail.
      final formula = WeakUntilTimed(
          pA, pFalse, TimeInterval.upTo(const Duration(milliseconds: 600)));
      expect(evalM(trace, formula).holds, isFalse);
    });

    test('startIndex > 0', () {
      // From index 3 (t=600ms): pTrue W_[0,400ms] pFalse
      // G_[0,400ms] pTrue from index 3 -> holds (d,e both satisfy pTrue)
      expect(
          evalM(
                  trace,
                  WeakUntilTimed(pTrue, pFalse,
                      TimeInterval.upTo(const Duration(milliseconds: 400))),
                  startIndex: 3)
              .holds,
          isTrue);
    });

    test('U_I path succeeds when G_I fails', () {
      // pNotE W_[0,1000ms] pE
      // G_[0,1000ms] pNotE fails at e (1000ms).
      // pNotE U_[0,1000ms] pE -> pE at 1000ms, pNotE holds before -> Until holds.
      // WeakUntil = G_I || U_I -> true.
      final formula = WeakUntilTimed(
          pNotE, pE, TimeInterval.upTo(const Duration(milliseconds: 1000)));
      expect(evalM(trace, formula).holds, isTrue);
    });
  });

  group('Duplicate timestamps', () {
    // Trace with duplicate timestamps: two events at the same time
    final dupTrace = Trace([
      TraceEvent(value: 'x', timestamp: Duration.zero),
      TraceEvent(value: 'y', timestamp: const Duration(milliseconds: 100)),
      TraceEvent(value: 'z', timestamp: const Duration(milliseconds: 100)),
      TraceEvent(value: 'w', timestamp: const Duration(milliseconds: 200)),
    ]);

    final pY = state<String>((s) => s == 'y', name: 'pY');
    final pZ = state<String>((s) => s == 'z', name: 'pZ');

    test('F_[100ms,100ms] sees both events at same timestamp', () {
      // Both y and z are at 100ms
      expect(
          evalM(
                  dupTrace,
                  EventuallyTimed(pY,
                      TimeInterval.exactly(const Duration(milliseconds: 100))))
              .holds,
          isTrue);
      expect(
          evalM(
                  dupTrace,
                  EventuallyTimed(pZ,
                      TimeInterval.exactly(const Duration(milliseconds: 100))))
              .holds,
          isTrue);
    });

    test('G_[100ms,100ms] requires all events at that timestamp', () {
      // Both y and z at 100ms. pY is false for z. G should fail.
      expect(
          evalM(
                  dupTrace,
                  AlwaysTimed(pY,
                      TimeInterval.exactly(const Duration(milliseconds: 100))))
              .holds,
          isFalse);
    });

    test('U_[0,100ms] with duplicate timestamps', () {
      final pNotW = state<String>((s) => s != 'w', name: 'pNotW');
      // pNotW U_[0,100ms] pZ -> 'z' at 100ms, pNotW holds at x(0ms),y(100ms)
      expect(
          evalM(
                  dupTrace,
                  UntilTimed(pNotW, pZ,
                      TimeInterval.upTo(const Duration(milliseconds: 100))))
              .holds,
          isTrue);
    });
  });

  group('Vacuous intervals (no events in suffix)', () {
    final singleTrace = Trace([
      TraceEvent(value: 'only', timestamp: Duration.zero),
    ]);

    test('AlwaysTimed vacuously true when interval has no events', () {
      final formula = AlwaysTimed(
          pFalse,
          TimeInterval(const Duration(milliseconds: 100),
              const Duration(milliseconds: 200)));
      expect(evalM(singleTrace, formula).holds, isTrue);
    });

    test('EventuallyTimed false when interval has no events', () {
      final formula = EventuallyTimed(
          pTrue,
          TimeInterval(const Duration(milliseconds: 100),
              const Duration(milliseconds: 200)));
      expect(evalM(singleTrace, formula).holds, isFalse);
    });

    test('UntilTimed false when interval has no events', () {
      final formula = UntilTimed(
          pTrue,
          pTrue,
          TimeInterval(const Duration(milliseconds: 100),
              const Duration(milliseconds: 200)));
      expect(evalM(singleTrace, formula).holds, isFalse);
    });

    test('ReleaseTimed true when interval has no events', () {
      final formula = ReleaseTimed(
          pFalse,
          pFalse,
          TimeInterval(const Duration(milliseconds: 100),
              const Duration(milliseconds: 200)));
      expect(evalM(singleTrace, formula).holds, isTrue);
    });

    test('WeakUntilTimed true when interval has no events', () {
      final formula = WeakUntilTimed(
          pFalse,
          pFalse,
          TimeInterval(const Duration(milliseconds: 100),
              const Duration(milliseconds: 200)));
      expect(evalM(singleTrace, formula).holds, isTrue);
    });
  });
}
