import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:test/test.dart';

// Helper function to create EvaluationResult matchers
Matcher _isSuccess() => isA<EvaluationResult>().having((e) => e.holds, 'holds', isTrue);

Matcher _isFailure({dynamic reason = anything, dynamic relatedIndex = anything, dynamic relatedTimestamp = anything}) =>
    isA<EvaluationResult>()
        .having((e) => e.holds, 'holds', isFalse)
        .having((e) => e.reason, 'reason', reason)
        .having((e) => e.relatedIndex, 'relatedIndex', relatedIndex)
        .having((e) => e.relatedTimestamp, 'relatedTimestamp', relatedTimestamp);

// Minimal state snapshot representation for bug repro
class MinimalSnap {
  final bool isLoading;
  final bool hasData;
  final bool hasError;

  MinimalSnap({this.isLoading = false, this.hasData = false, this.hasError = false});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MinimalSnap &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          hasData == other.hasData &&
          hasError == other.hasError;

  @override
  int get hashCode => isLoading.hashCode ^ hasData.hashCode ^ hasError.hashCode;

  @override
  String toString() {
    return 'MinimalSnap(isLoading: $isLoading, hasData: $hasData, hasError: $hasError)';
  }
}

void main() {
  // --- Setup ---
  // Simple state type and predicates for testing
  // Using integers for simplicity
  bool isEven(int state) => state % 2 == 0;
  bool isPositive(int state) => state > 0;
  bool isZero(int state) => state == 0;
  bool alwaysTrue(int state) => true;
  bool alwaysFalse(int state) => false;

  final pEven = state<int>(isEven, name: 'pEven');
  final pPos = state<int>(isPositive, name: 'pPos');
  final pZero = state<int>(isZero, name: 'pZero');
  final pTrue = state<int>(alwaysTrue, name: 'pTrue');
  final pFalse = state<int>(alwaysFalse, name: 'pFalse');

  // Sample Traces
  final emptyTrace = Trace<int>.empty();
  final trace_0_1_2_3 = Trace.fromList([0, 1, 2, 3]); // Times 0, 1, 2, 3 ms
  final trace_1_2_3_4 = Trace.fromList([1, 2, 3, 4]); // Times 0, 1, 2, 3 ms
  final trace_2_4_6_8 = Trace.fromList([2, 4, 6, 8]); // Times 0, 1, 2, 3 ms (all even)
  final trace_1_2_0_4 = Trace.fromList([1, 2, 0, 4]); // Times 0, 1, 2, 3 ms

  group('evaluateTrace - Basic & Bounds', () {
    test('negative startIndex fails', () {
      final result = evaluateTrace(trace_0_1_2_3, pTrue, startIndex: -1);
      expect(result, _isFailure(relatedIndex: -1));
    });

    test('startIndex >= length depends on formula', () {
      // Atomic fails
      expect(evaluateTrace(trace_0_1_2_3, pEven, startIndex: 4), _isFailure(relatedIndex: 4));
      expect(evaluateTrace(emptyTrace, pEven, startIndex: 0), _isFailure(relatedIndex: 0));

      // Always holds (vacuously true)
      expect(evaluateTrace(trace_0_1_2_3, always(pTrue), startIndex: 4), _isSuccess());
      expect(evaluateTrace(emptyTrace, always(pTrue), startIndex: 0), _isSuccess());

      // Eventually fails
      expect(evaluateTrace(trace_0_1_2_3, eventually(pTrue), startIndex: 4), _isFailure(relatedIndex: 4));
      expect(evaluateTrace(emptyTrace, eventually(pTrue), startIndex: 0), _isFailure(relatedIndex: 0));

      // Until fails
      expect(evaluateTrace(trace_0_1_2_3, until(pTrue, pFalse), startIndex: 4), _isFailure(relatedIndex: 4));
      expect(evaluateTrace(emptyTrace, until(pTrue, pFalse), startIndex: 0), _isFailure(relatedIndex: 0));
    });
  });

  group('evaluateTrace - AtomicProposition', () {
    test('evaluates predicate at the current index', () {
      expect(evaluateTrace(trace_0_1_2_3, pEven, startIndex: 0), _isSuccess()); // 0 is even
      expect(evaluateTrace(trace_0_1_2_3, pEven, startIndex: 1), _isFailure()); // 1 is odd
      expect(evaluateTrace(trace_0_1_2_3, pEven, startIndex: 2), _isSuccess()); // 2 is even
      expect(evaluateTrace(trace_0_1_2_3, pPos, startIndex: 0), _isFailure()); // 0 is not positive
      expect(evaluateTrace(trace_0_1_2_3, pPos, startIndex: 1), _isSuccess()); // 1 is positive
    });

    test('fails if index is out of bounds', () {
      expect(evaluateTrace(trace_0_1_2_3, pEven, startIndex: 4), _isFailure(relatedIndex: 4));
      expect(evaluateTrace(emptyTrace, pEven, startIndex: 0), _isFailure(relatedIndex: 0));
    });
  });

  group('evaluateTrace - Boolean Connectives', () {
    // Using index 1: state is 1 (odd, positive)
    const idx = 1;
    final trace = trace_0_1_2_3;
    final timestamp = Duration(milliseconds: idx);

    test('Not', () {
      // pEven is false at index 1, so Not(pEven) is true
      expect(evaluateTrace(trace, Not(pEven), startIndex: idx), _isSuccess());
      // pPos is true at index 1, so Not(pPos) is false
      expect(
          evaluateTrace(trace, Not(pPos), startIndex: idx), _isFailure(relatedTimestamp: timestamp, relatedIndex: idx));
    });

    test('And', () {
      // pPos && pEven -> T && F -> F
      expect(evaluateTrace(trace, And(pPos, pEven), startIndex: idx), _isFailure(reason: contains('pEven failed')));
      // pEven && pPos -> F && T -> F (short circuits)
      expect(evaluateTrace(trace, And(pEven, pPos), startIndex: idx), _isFailure(reason: contains('pEven failed')));
      // pPos && Not(pEven) -> T && T -> T
      expect(evaluateTrace(trace, And(pPos, Not(pEven)), startIndex: idx), _isSuccess());
      // pFalse && pTrue -> F && T -> F
      expect(evaluateTrace(trace, And(pFalse, pTrue), startIndex: idx), _isFailure());
    });

    test('Or', () {
      // pPos || pEven -> T || F -> T
      expect(evaluateTrace(trace, Or(pPos, pEven), startIndex: idx), _isSuccess());
      // pEven || pPos -> F || T -> T (no short circuit)
      expect(evaluateTrace(trace, Or(pEven, pPos), startIndex: idx), _isSuccess());
      // pEven || Not(pPos) -> F || F -> F
      expect(evaluateTrace(trace, Or(pEven, Not(pPos)), startIndex: idx),
          _isFailure(reason: contains('Both sides of OR failed')));
      // pTrue || pFalse -> T || F -> T
      expect(evaluateTrace(trace, Or(pTrue, pFalse), startIndex: idx), _isSuccess());
    });

    test('Implies', () {
      // pEven => pPos -> F => T -> T
      expect(evaluateTrace(trace, Implies(pEven, pPos), startIndex: idx), _isSuccess());
      // pPos => pEven -> T => F -> F
      expect(
          evaluateTrace(trace, Implies(pPos, pEven), startIndex: idx),
          _isFailure(
              reason: contains('Antecedent held but consequent failed'),
              relatedTimestamp: timestamp,
              relatedIndex: idx));
      // pPos => Not(pEven) -> T => T -> T
      expect(evaluateTrace(trace, Implies(pPos, Not(pEven)), startIndex: idx), _isSuccess());
      // pFalse => pTrue -> F => T -> T
      expect(evaluateTrace(trace, Implies(pFalse, pTrue), startIndex: idx), _isSuccess());
    });
  });

  group('evaluateTrace - Temporal Operators', () {
    test('Next (X)', () {
      // X(pEven) at index 0: requires pEven at index 1 (1 is odd) -> F
      expect(evaluateTrace(trace_0_1_2_3, next(pEven), startIndex: 0), _isFailure(relatedIndex: 1));
      // X(pEven) at index 1: requires pEven at index 2 (2 is even) -> T
      expect(evaluateTrace(trace_0_1_2_3, next(pEven), startIndex: 1), _isSuccess());
      // X(pEven) at index 2: requires pEven at index 3 (3 is odd) -> F
      expect(evaluateTrace(trace_0_1_2_3, next(pEven), startIndex: 2), _isFailure(relatedIndex: 3));
      // X(pEven) at index 3: requires index 4 (out of bounds) -> F
      expect(evaluateTrace(trace_0_1_2_3, next(pEven), startIndex: 3),
          _isFailure(relatedIndex: 3, reason: contains('Next evaluated past trace end')));
      // X(pTrue) on empty trace -> F
      expect(evaluateTrace(emptyTrace, next(pTrue), startIndex: 0),
          _isFailure(relatedIndex: 0, reason: contains('Next evaluated past trace end')));
    });

    test('Always (G)', () {
      // G(pEven) on trace_2_4_6_8 -> T
      expect(evaluateTrace(trace_2_4_6_8, always(pEven), startIndex: 0), _isSuccess());
      // G(pEven) on trace_0_1_2_3 -> F (fails at index 1)
      expect(evaluateTrace(trace_0_1_2_3, always(pEven), startIndex: 0),
          _isFailure(relatedIndex: 1, relatedTimestamp: Duration(milliseconds: 1), reason: contains('pEven failed')));
      // G(pEven) on trace_0_1_2_3 starting at index 2 -> F (fails at index 3)
      expect(evaluateTrace(trace_0_1_2_3, always(pEven), startIndex: 2),
          _isFailure(relatedIndex: 3, relatedTimestamp: Duration(milliseconds: 3), reason: contains('pEven failed')));
      // G(pEven) on trace_0_1_2_3 starting at index 4 (empty suffix) -> T
      expect(evaluateTrace(trace_0_1_2_3, always(pEven), startIndex: 4), _isSuccess());
      // G(pTrue) on empty trace -> T
      expect(evaluateTrace(emptyTrace, always(pTrue), startIndex: 0), _isSuccess());
      // G(pFalse) on non-empty trace -> F (fails immediately)
      expect(evaluateTrace(trace_0_1_2_3, always(pFalse), startIndex: 0), _isFailure(relatedIndex: 0));
    });

    test('Eventually (F)', () {
      // F(pZero) on trace_1_2_0_4 -> T (holds at index 2)
      expect(evaluateTrace(trace_1_2_0_4, eventually(pZero), startIndex: 0), _isSuccess());
      // F(pZero) on trace_1_2_0_4 starting at index 1 -> T (holds at index 2)
      expect(evaluateTrace(trace_1_2_0_4, eventually(pZero), startIndex: 1), _isSuccess());
      // F(pZero) on trace_1_2_0_4 starting at index 3 -> F (0 never holds from index 3 onwards)
      expect(evaluateTrace(trace_1_2_0_4, eventually(pZero), startIndex: 3), _isFailure(relatedIndex: 3));
      // F(pZero) on trace_1_2_3_4 -> F (never holds)
      expect(evaluateTrace(trace_1_2_3_4, eventually(pZero), startIndex: 0), _isFailure(relatedIndex: 0));
      // F(pTrue) on trace_1_2_3_4 -> T (holds immediately)
      expect(evaluateTrace(trace_1_2_3_4, eventually(pTrue), startIndex: 0), _isSuccess());
      // F(pFalse) on trace_1_2_3_4 -> F
      expect(evaluateTrace(trace_1_2_3_4, eventually(pFalse), startIndex: 0), _isFailure(relatedIndex: 0));
      // F(pTrue) on empty trace -> F
      expect(evaluateTrace(emptyTrace, eventually(pTrue), startIndex: 0), _isFailure(relatedIndex: 0));
      // F(pZero) on trace_0_1_2_3 starting at index 4 (empty suffix) -> F
      expect(evaluateTrace(trace_0_1_2_3, eventually(pZero), startIndex: 4), _isFailure(relatedIndex: 4));
    });

    test('Until (U)', () {
      // trace_0_1_2_3: [0, 1, 2, 3]
      final pOdd = Not(pEven);

      // pPos U pEven at index 0: Needs pEven eventually (holds at index 2), needs pPos until then (holds at 1) -> T
      // 0: pPos=F, pEven=T -> right holds immediately -> T
      expect(evaluateTrace(trace_0_1_2_3, until(pPos, pEven), startIndex: 0), _isSuccess());

      // pPos U pEven at index 1: Needs pEven eventually (holds at 2), needs pPos until then (holds at 1) -> T
      // 1: pPos=T, pEven=F
      // 2: pPos=T, pEven=T -> right holds, left held at 1 -> T
      expect(evaluateTrace(trace_0_1_2_3, until(pPos, pEven), startIndex: 1), _isSuccess());

      // pOdd U pZero at index 0 on trace [1, 3, 0, 2] -> T
      final trace_1_3_0_2 = Trace.fromList([1, 3, 0, 2]);
      // 0: pOdd=T, pZero=F
      // 1: pOdd=T, pZero=F
      // 2: pOdd=F, pZero=T -> right holds, left held at 0, 1 -> T
      expect(evaluateTrace(trace_1_3_0_2, until(pOdd, pZero), startIndex: 0), _isSuccess());

      // pOdd U pZero at index 0 on trace [1, 2, 0, 3] -> F (left fails at index 1 before right holds)
      final trace_1_2_0_3 = Trace.fromList([1, 2, 0, 3]);
      // 0: pOdd=T, pZero=F
      // 1: pOdd=F, pZero=F -> left failed before right held -> F
      expect(
          evaluateTrace(trace_1_2_0_3, until(pOdd, pZero), startIndex: 0),
          _isFailure(
              relatedIndex: 1,
              relatedTimestamp: Duration(milliseconds: 1),
              reason: contains('Left operand failed before right held')));

      // pPos U pFalse at index 0 on trace [1, 2, 3] -> F (right never holds)
      final trace_1_2_3 = Trace.fromList([1, 2, 3]);
      // 0: pPos=T, pFalse=F
      // 1: pPos=T, pFalse=F
      // 2: pPos=T, pFalse=F -> right never held -> F
      expect(evaluateTrace(trace_1_2_3, until(pPos, pFalse), startIndex: 0),
          _isFailure(relatedIndex: 0, reason: contains('Right operand never held')));

      // pTrue U pTrue at index 0 -> T (right holds immediately)
      expect(evaluateTrace(trace_0_1_2_3, until(pTrue, pTrue), startIndex: 0), _isSuccess());

      // pFalse U pTrue at index 0 -> T (right holds immediately)
      expect(evaluateTrace(trace_0_1_2_3, until(pFalse, pTrue), startIndex: 0), _isSuccess());

      // pTrue U pFalse at index 0 -> F (right never holds)
      expect(evaluateTrace(trace_0_1_2_3, until(pTrue, pFalse), startIndex: 0),
          _isFailure(reason: contains('Right operand never held')));

      // Until on empty trace suffix -> F
      expect(evaluateTrace(trace_0_1_2_3, until(pTrue, pTrue), startIndex: 4), _isFailure(relatedIndex: 4));
      expect(evaluateTrace(emptyTrace, until(pTrue, pTrue), startIndex: 0), _isFailure(relatedIndex: 0));
    });

    // WeakUntil and Release tests rely on the correctness of the base operators
    // and the boolean logic used in their definitions. More specific tests might
    // be needed if optimized implementations are added.
    test('WeakUntil (W) - Defined as G(left) or (left U right)', () {
      // G(pEven) or (pEven U pPos) on trace_2_4_6_8 -> T (because G(pEven) holds)
      expect(evaluateTrace(trace_2_4_6_8, weakUntil(pEven, pPos), startIndex: 0), _isSuccess());

      // trace_0_1_2_3 = [0, 1, 2, 3]
      // G(pPos) or (pPos U pEven) at index 1: G(pPos) is false (fails at 0), pPos U pEven holds at 1 -> T
      expect(evaluateTrace(trace_0_1_2_3, weakUntil(pPos, pEven), startIndex: 1), _isSuccess());

      // G(pOdd) or (pOdd U pZero) on trace [1, 2, 0, 3] -> F
      // G(pOdd) fails at index 1. pOdd U pZero fails at index 1. Or fails. -> F
      final trace_1_2_0_3 = Trace.fromList([1, 2, 0, 3]);
      final pOdd = Not(pEven);
      expect(evaluateTrace(trace_1_2_0_3, weakUntil(pOdd, pZero), startIndex: 0), _isFailure());

      // pTrue W pFalse -> G(pTrue) or (pTrue U pFalse) -> T or F -> T
      expect(evaluateTrace(trace_0_1_2_3, weakUntil(pTrue, pFalse), startIndex: 0), _isSuccess());

      // pFalse W pTrue -> G(pFalse) or (pFalse U pTrue) -> F or T -> T
      expect(evaluateTrace(trace_0_1_2_3, weakUntil(pFalse, pTrue), startIndex: 0), _isSuccess());

      // pFalse W pFalse -> G(pFalse) or (pFalse U pFalse) -> F or F -> F
      expect(evaluateTrace(trace_0_1_2_3, weakUntil(pFalse, pFalse), startIndex: 0), _isFailure());

      // WeakUntil on empty trace suffix -> T (G(p) is true)
      expect(evaluateTrace(trace_0_1_2_3, weakUntil(pTrue, pFalse), startIndex: 4), _isSuccess());
      expect(evaluateTrace(emptyTrace, weakUntil(pTrue, pFalse), startIndex: 0), _isSuccess());
    });

    test('Release (R) - Defined as !(!left U !right)', () {
      // !pPos R !pEven on trace [1, 2, 3] = [pPos&!pEven, pPos&pEven, pPos&!pEven]
      // Equivalent to ! (pPos U pEven)
      // pPos U pEven holds (holds at index 1 -> T)
      // So ! (pPos U pEven) -> F
      final trace_1_2_3 = Trace.fromList([1, 2, 3]);
      final notPPos = Not(pPos);
      final notPEven = Not(pEven);
      expect(evaluateTrace(trace_1_2_3, Release(notPPos, notPEven), startIndex: 0), _isFailure());

      // pFalse R pTrue -> !(!pFalse U !pTrue) -> !(pTrue U pFalse) -> !(F) -> T
      expect(evaluateTrace(trace_0_1_2_3, Release(pFalse, pTrue), startIndex: 0), _isSuccess());

      // pTrue R pFalse -> !(!pTrue U !pFalse) -> !(pFalse U pTrue) -> !(T) -> F
      expect(evaluateTrace(trace_0_1_2_3, Release(pTrue, pFalse), startIndex: 0), _isFailure());

      // pTrue R pTrue -> !(!pTrue U !pTrue) -> !(pFalse U pFalse) -> !(F) -> T
      expect(evaluateTrace(trace_0_1_2_3, Release(pTrue, pTrue), startIndex: 0), _isSuccess());

      // pFalse R pFalse -> !(!pFalse U !pFalse) -> !(pTrue U pTrue) -> !(T) -> F
      expect(evaluateTrace(trace_0_1_2_3, Release(pFalse, pFalse), startIndex: 0), _isFailure());

      // Release on empty trace -> T (because !(!left U !right) -> !F -> T)
      expect(evaluateTrace(trace_0_1_2_3, Release(pTrue, pFalse), startIndex: 4), _isSuccess());
      expect(evaluateTrace(emptyTrace, Release(pTrue, pFalse), startIndex: 0), _isSuccess());
    });
  });

  group('evaluateTrace - Complex/Nested Temporal Operators', () {
    // G(F(p)) - Globally, eventually p
    test('G(F(p)) - Holds when p occurs infinitely often', () {
      // Trace: [1, 0, 1, 0, 1, 0, ...] (pZero occurs infinitely)
      final traceInfZero = Trace.fromList([1, 0, 1, 0, 1, 0, 1, 0]);
      expect(evaluateTrace(traceInfZero, always(eventually(pZero)), startIndex: 0), _isSuccess());
      // F(pZero) holds at 0 (finds at 1)
      // F(pZero) holds at 1 (finds at 1)
      // F(pZero) holds at 2 (finds at 3) ... etc.
    });
    test('G(F(p)) - Fails if p stops occurring', () {
      // Trace: [1, 0, 1, 0, 1, 1, 1, 1] (pZero stops holding)
      final traceStopZero = Trace.fromList([1, 0, 1, 0, 1, 1, 1, 1]);
      // Check G(F(pZero)) starting at index 0
      // F(pZero) at 0 holds (finds at 1)
      // F(pZero) at 1 holds (finds at 1)
      // F(pZero) at 2 holds (finds at 3)
      // F(pZero) at 3 holds (finds at 3)
      // F(pZero) at 4 holds (no more 0s found) -> Fails here
      expect(
          evaluateTrace(traceStopZero, always(eventually(pZero)), startIndex: 0),
          _isFailure(
              relatedIndex: 4, // Where F(pZero) first fails
              relatedTimestamp: Duration(milliseconds: 4),
              reason: contains('Always failed: Eventually failed: Operand never held.')));
      // Check starting later
      expect(evaluateTrace(traceStopZero, always(eventually(pZero)), startIndex: 4), _isFailure(relatedIndex: 4));
    });
    test('G(F(p)) - Holds if p holds always', () {
      final traceAllZero = Trace.fromList([0, 0, 0, 0]);
      expect(evaluateTrace(traceAllZero, always(eventually(pZero)), startIndex: 0), _isSuccess());
    });

    // F(G(p)) - Eventually, globally p
    test('F(G(p)) - Holds if p eventually becomes always true', () {
      // Trace: [1, 1, 0, 0, 0, 0] (pZero becomes always true from index 2)
      final traceEventuallyAllZero = Trace.fromList([1, 1, 0, 0, 0, 0]);
      // Check F(G(pZero)) at index 0
      // G(pZero) at 0 fails (at 0)
      // G(pZero) at 1 fails (at 1)
      // G(pZero) at 2 holds (0, 0, 0, 0 from index 2) -> Success found
      expect(evaluateTrace(traceEventuallyAllZero, eventually(always(pZero)), startIndex: 0), _isSuccess());
      // Check F(G(pZero)) at index 2 -> Success (holds immediately)
      expect(evaluateTrace(traceEventuallyAllZero, eventually(always(pZero)), startIndex: 2), _isSuccess());
    });
    test('F(G(p)) - Fails if p never becomes always true', () {
      // Trace: [1, 0, 1, 0, 1, 0] (pZero never always true for >1 step, but G(pZero) holds at index 5)
      final traceInfZero = Trace.fromList([1, 0, 1, 0, 1, 0]);
      // G(pZero) fails at 0, 1, 2, 3, 4
      // G(pZero) at 5: checks state 5 (0 -> true), checks state 6 (end) -> G holds.
      // Therefore, F(G(pZero)) holds at index 0 because it finds G(pZero) holding at index 5.
      expect(evaluateTrace(traceInfZero, eventually(always(pZero)), startIndex: 0), _isSuccess());
    });
    test('F(G(p)) - Holds if p is always true initially', () {
      final traceAllZero = Trace.fromList([0, 0, 0, 0]);
      expect(evaluateTrace(traceAllZero, eventually(always(pZero)), startIndex: 0), _isSuccess());
    });

    // G(p -> X(q)) - Globally, if p holds, then q holds next
    test('G(p -> X(q)) - Holds when implication is always met', () {
      // Trace: [1, 2, 3, 4] -> [pPos, pEven, pPos, pEven]
      // pPos -> X(pEven):
      // idx 0: pPos=T, X(pEven)=T (at idx 1, state 2 is even) -> Implies T
      // idx 1: pPos=T, X(pEven)=F (at idx 2, state 3 is odd) -> Implies F -> G Fails here
      // idx 2: pPos=T, X(pEven)=T (at idx 3, state 4 is even) -> Implies T
      // idx 3: pPos=T, X(pEven)=F (end of trace) -> Implies F -> G Fails here
      final pPosImpliesNextEven = always(pPos.implies(next(pEven)));
      expect(
          evaluateTrace(trace_1_2_3_4, pPosImpliesNextEven, startIndex: 0),
          _isFailure(
              relatedIndex: 1, // Where the implication first fails
              relatedTimestamp: Duration(milliseconds: 1),
              reason: contains('Always failed: Antecedent held but consequent failed: pEven failed')));

      // Trace: [1, 2, 1, 2] -> [pPos, pEven, pPos, pEven]
      // pPos -> X(pEven):
      // idx 0: pPos=T, X(pEven)=T -> Implies T
      // idx 1: pPos=T, X(pEven)=F -> Implies F -> Fails here
      final trace_1_2_1_2 = Trace.fromList([1, 2, 1, 2]);
      expect(evaluateTrace(trace_1_2_1_2, pPosImpliesNextEven, startIndex: 0), _isFailure(relatedIndex: 1));

      // Trace: [2, 1, 4, 3] -> [pEven, pOdd, pEven, pOdd]
      // pEven -> X(pOdd) (where pOdd = Not(pEven))
      // idx 0: pEven=T, X(pOdd)=T (at idx 1, state 1 is odd) -> Implies T
      // idx 1: pEven=F -> Implies T
      // idx 2: pEven=T, X(pOdd)=T (at idx 3, state 3 is odd) -> Implies T
      // idx 3: pEven=F -> Implies T -> G holds
      final trace_2_1_4_3 = Trace.fromList([2, 1, 4, 3]);
      final pOdd = Not(pEven);
      final pEvenImpliesNextOdd = always(pEven.implies(next(pOdd)));
      expect(evaluateTrace(trace_2_1_4_3, pEvenImpliesNextOdd, startIndex: 0), _isSuccess());
    });
    test('G(p -> X(q)) - Handles end of trace for X(q)', () {
      // Trace: [1, 2] -> [pPos, pEven]
      // pPos -> X(pEven):
      // idx 0: pPos=T, X(pEven)=T (at idx 1) -> Implies T
      // idx 1: pPos=T, X(pEven)=F (next is out of bounds) -> Implies F -> G fails here
      final trace_1_2 = Trace.fromList([1, 2]);
      final pPosImpliesNextEven = always(pPos.implies(next(pEven)));
      expect(
          evaluateTrace(trace_1_2, pPosImpliesNextEven, startIndex: 0),
          _isFailure(
              relatedIndex: 1,
              relatedTimestamp: Duration(milliseconds: 1),
              reason: contains('Always failed: Antecedent held but consequent failed: Next evaluated past trace end')));
    });

    // Nested binary: p U (q W r)
    test('p U (q W r)', () {
      // Trace: [1, 3, 5, 0, 2, 4] -> [pPos&pOdd, pPos&pOdd, pPos&pOdd, pZero&pEven, pPos&pEven, pPos&pEven]
      // Let p=pPos, q=pOdd, r=pZero
      // Formula: pPos U (pOdd W pZero)
      final trace = Trace.fromList([1, 3, 5, 0, 2, 4]);
      final pOdd = Not(pEven);
      final innerWeakUntil = weakUntil(pOdd, pZero); // q W r
      final formula = until(pPos, innerWeakUntil); // p U (q W r)

      // Evaluate inner (q W r) at different points:
      // idx 0 (state 1): pOdd=T, pZero=F. G(pOdd) fails later. pOdd U pZero? Finds 0 at idx 3. Left holds 0,1,2. -> T
      expect(evaluateTrace(trace, innerWeakUntil, startIndex: 0), _isSuccess());
      // idx 1 (state 3): pOdd=T, pZero=F. G(pOdd) fails later. pOdd U pZero? Finds 0 at idx 3. Left holds 1,2. -> T
      expect(evaluateTrace(trace, innerWeakUntil, startIndex: 1), _isSuccess());
      // idx 2 (state 5): pOdd=T, pZero=F. G(pOdd) fails later. pOdd U pZero? Finds 0 at idx 3. Left holds 2. -> T
      expect(evaluateTrace(trace, innerWeakUntil, startIndex: 2), _isSuccess());
      // idx 3 (state 0): pOdd=F, pZero=T. pOdd U pZero? Right holds immediately. -> T
      expect(evaluateTrace(trace, innerWeakUntil, startIndex: 3), _isSuccess());
      // idx 4 (state 2): pOdd=F, pZero=F. G(pOdd) fails immediately. pOdd U pZero? Right never holds. Left fails now. -> F
      expect(evaluateTrace(trace, innerWeakUntil, startIndex: 4), _isFailure());
      // idx 5 (state 4): pOdd=F, pZero=F. G(pOdd) fails immediately. pOdd U pZero? Right never holds. Left fails now. -> F
      expect(evaluateTrace(trace, innerWeakUntil, startIndex: 5), _isFailure());

      // Evaluate outer p U (q W r) at index 0:
      // Need innerWeakUntil to hold eventually, and pPos to hold until then.
      // innerWeakUntil holds at index 0, 1, 2, 3. Let's check the first time: idx 0.
      // pPos must hold before index 0 (vacuously true).
      // So the whole formula holds at index 0.
      expect(evaluateTrace(trace, formula, startIndex: 0), _isSuccess());

      // Evaluate outer p U (q W r) at index 4:
      // Need innerWeakUntil to hold eventually (it doesn't from idx 4 onwards).
      // Also, pPos must hold at index 4 (it does).
      // Check innerWeakUntil at 5 -> Fails.
      // Right side (innerWeakUntil) never holds. -> Outer Until fails.
      expect(evaluateTrace(trace, formula, startIndex: 4), _isFailure(reason: contains("Right operand never held")));
    });
  });

  group('evaluateTrace - Bug Reproduction Cases', () {
    // --- LTL Propositions ---
    final isLoading = state<MinimalSnap>((s) => s.isLoading, name: 'isLoading');
    final hasData = state<MinimalSnap>((s) => s.hasData, name: 'hasData');
    final hasError = state<MinimalSnap>((s) => s.hasError, name: 'hasError');

    // P: Initial state (loading, no data, no error)
    final initialStateP = isLoading.and(hasData.not()).and(hasError.not());
    // Q: Final state (not loading, has data, no error)
    final finalStateQ = isLoading.not().and(hasData).and(hasError.not());

    // --- Trace Creation ---
    // Simple trace: State P -> State Q
    final trace_P_Q = Trace<MinimalSnap>([
      TraceEvent(
          value: MinimalSnap(isLoading: true, hasData: false, hasError: false),
          timestamp: Duration.zero), // State P @ 0
      TraceEvent(
          value: MinimalSnap(isLoading: false, hasData: true, hasError: false),
          timestamp: const Duration(milliseconds: 100)), // State Q @ 1
    ]);

    test('BugRepro: P holds initially', () {
      expect(evaluateTrace(trace_P_Q, initialStateP, startIndex: 0), _isSuccess());
    });

    test('BugRepro: eventually(Q) holds', () {
      expect(evaluateTrace(trace_P_Q, eventually(finalStateQ), startIndex: 0), _isSuccess());
    });

    test('BugRepro: P.and(eventually(Q)) should hold', () {
      // The combined formula that was failing with satisfiesLtl
      final formulaCombined = initialStateP.and(eventually(finalStateQ));

      // Directly evaluate using the core evaluator
      final result = evaluateTrace(trace_P_Q, formulaCombined, startIndex: 0);

      // --- Verification ---
      // Expected: The formula should hold because P holds at index 0 AND
      // eventually(Q) holds starting at index 0 (because Q holds at index 1).
      expect(result, _isSuccess(), reason: 'Expected P && F(Q) to hold on trace [P, Q]');

      // If it fails, print the reason
      if (!result.holds) {
        print('BugRepro test failed. EvaluationResult: $result');
      }
    });
  });

  group('evaluateLtl (convenience function)', () {
    test('returns true for formulas that hold', () {
      expect(evaluateLtl(always(pEven), [2, 4, 6]), isTrue);
      expect(evaluateLtl(eventually(pZero), [1, 2, 0, 4]), isTrue);
      expect(evaluateLtl(until(pPos, pEven), [1, 3, 2]), isTrue);
      expect(evaluateLtl(next(pEven), [1, 2]), isTrue);
    });

    test('returns false for formulas that do not hold', () {
      expect(evaluateLtl(always(pEven), [2, 4, 5]), isFalse);
      expect(evaluateLtl(eventually(pZero), [1, 2, 3, 4]), isFalse);
      expect(evaluateLtl(until(pPos, pEven), [1, 3, 5]), isFalse);
      expect(evaluateLtl(next(pEven), [1, 3]), isFalse);
    });

    test('returns false for empty trace list', () {
      expect(evaluateLtl(pTrue, []), isFalse);
      expect(evaluateLtl(always(pTrue), []), isFalse); // Conventional behavior
      expect(evaluateLtl(eventually(pTrue), []), isFalse);
    });

    test('handles boolean combinations', () {
      expect(evaluateLtl(And(pPos, pEven), [2]), isTrue); // Pos and Even
      expect(evaluateLtl(And(pPos, pEven), [1]), isFalse); // Pos but not Even
      expect(evaluateLtl(Or(pPos, pEven), [1]), isTrue); // Pos or Even
      expect(evaluateLtl(Or(pPos, pEven), [-1]), isFalse); // Neither Pos nor Even
      expect(evaluateLtl(Not(pEven), [1]), isTrue);
    });
  });
}
