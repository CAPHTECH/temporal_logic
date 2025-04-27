import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';
import 'package:test/test.dart';
// No longer need direct import from core for Trace/TimedValue if re-exported by mtl
// import 'package:temporal_logic_core/temporal_logic_core.dart';

void main() {
  group('TimedValue / TraceEvent', () {
    // Renamed for clarity
    test('Equality and toString', () {
      // Using TraceEvent as it's the element type within Trace
      final t1 = TraceEvent(value: 'a', timestamp: const Duration(seconds: 1));
      final t2 = TraceEvent(value: 'a', timestamp: const Duration(seconds: 1));
      final t3 = TraceEvent(value: 'b', timestamp: const Duration(seconds: 1));
      final t4 = TraceEvent(value: 'a', timestamp: const Duration(seconds: 2));

      expect(t1, equals(t2));
      expect(t1, isNot(equals(t3)));
      expect(t1, isNot(equals(t4)));
      expect(t1.hashCode, equals(t2.hashCode));
      // TraceEvent.toString format might differ, adjust if needed based on core implementation
      // Assuming it's like: 'value @ timestamp_ms ms'
      expect(t1.toString(), equals('a @ 1000ms'));
    });
  });

  group('Trace (from core)', () {
    final v0 = TraceEvent(value: 0, timestamp: Duration.zero);
    final v1 = TraceEvent(value: 1, timestamp: const Duration(milliseconds: 500));
    final v2 = TraceEvent(value: 2, timestamp: const Duration(seconds: 1));
    final v3 = TraceEvent(value: 2, timestamp: const Duration(seconds: 2));
    final trace = Trace([v0, v1, v2, v3]); // Use Trace constructor

    test('Properties (length, isEmpty, first, last)', () {
      // Removed duration test
      expect(trace.isEmpty, isFalse);
      expect(trace.length, 4);
      expect(trace.events.first, v0); // Access events list
      expect(trace.events.last, v3); // Access events list
      // Duration isn't a direct property of Trace, calculate if needed:
      // expect(trace.events.last.timestamp - trace.events.first.timestamp, const Duration(seconds: 2));
      expect(Trace.empty().isEmpty, isTrue);
      // Duration test removed for empty trace too
    });

    test('Indexer access via events list', () {
      expect(trace.events[0], v0);
      expect(trace.events[1], v1);
      expect(() => trace.events[4], throwsRangeError);
    });

    // subTrace is not a method on Trace in core package. Remove test.
    // test('subTrace correctly adjusts timestamps', () { ... });
    // test('subTrace handles edge cases', () { ... });

    test('Trace constructor allows monotonic timestamps', () {
      // Assertion logic is now internal to Trace constructor if implemented.
      // Test creation instead of assertion.
      expect(() => Trace([v1, v0]), throwsA(isA<AssertionError>())); // Assuming core Trace asserts
      expect(() => Trace([v0, v1]), returnsNormally);
    });

    // Helper to extract states if needed (core doesn't have statesSublist)
    List<T> getStates<T>(Trace<T> t) => t.events.map((e) => e.value).toList();
  });

  group('TimeInterval', () {
    test('Constructors and contains', () {
      final i1 = TimeInterval(const Duration(seconds: 1), const Duration(seconds: 3));
      expect(i1.contains(const Duration(seconds: 1)), isTrue);
      expect(i1.contains(const Duration(seconds: 2)), isTrue);
      expect(i1.contains(const Duration(seconds: 3)), isTrue);
      expect(i1.contains(const Duration(milliseconds: 999)), isFalse);
      expect(i1.contains(const Duration(milliseconds: 3001)), isFalse);

      final iUpTo = TimeInterval.upTo(const Duration(seconds: 2));
      expect(iUpTo.lowerBound, Duration.zero);
      expect(iUpTo.upperBound, const Duration(seconds: 2));

      final iExactly = TimeInterval.exactly(const Duration(seconds: 1));
      expect(iExactly.lowerBound, const Duration(seconds: 1));
      expect(iExactly.upperBound, const Duration(seconds: 1));
    });
  });

  // Helper to evaluate formulas using the new evaluator
  EvaluationResult evalM<T>(Trace<T> trace, Formula<T> formula) {
    return evaluateMtlTrace(trace, formula); // Use the new unified evaluator
  }

  group('MTL Formula Basic Checks (using evaluateMtlTrace)', () {
    // Trace: (0 @ 0ms) -> (1 @ 500ms) -> (2 @ 1000ms) -> (2 @ 2000ms)
    final v0 = TraceEvent(value: 0, timestamp: Duration.zero);
    final v1 = TraceEvent(value: 1, timestamp: const Duration(milliseconds: 500));
    final v2 = TraceEvent(value: 2, timestamp: const Duration(seconds: 1));
    final v3 = TraceEvent(value: 2, timestamp: const Duration(seconds: 2));
    final trace = Trace([v0, v1, v2, v3]);
    final emptyTrace = Trace<int>([]);

    final p0 = state<int>((s) => s == 0, name: 'p0');
    final p1 = state<int>((s) => s == 1, name: 'p1');
    final p2 = state<int>((s) => s == 2, name: 'p2');
    final pNonNegative = state<int>((s) => s >= 0, name: 'pNN');

    test('Atomic Propositions', () {
      expect(evalM(trace, p0).holds, isTrue);
      expect(evalM(trace, p1).holds, isFalse);
      expect(evalM(trace, pNonNegative).holds, isTrue);
      expect(evalM(emptyTrace, p0).holds, isFalse);
    });

    test('Logical Connectives', () {
      expect(evalM(trace, p0.and(pNonNegative)).holds, isTrue);
      expect(evalM(trace, p0.and(p1)).holds, isFalse);
      expect(evalM(trace, p1.or(p0)).holds, isTrue);
      expect(evalM(trace, p1.or(p2)).holds, isFalse); // p1(false) or p2(false) at index 0
      expect(evalM(trace, p0.implies(pNonNegative)).holds, isTrue);
      expect(evalM(trace, p1.implies(p0)).holds, isTrue); // !p1(true) implies p0(true) at index 0
      expect(evalM(trace, p0.implies(p1)).holds, isFalse); // p0(true) implies p1(false) at index 0
      expect(evalM(trace, p0.not()).holds, isFalse);
      expect(evalM(trace, p1.not()).holds, isTrue);
    });

    // Add tests for LTL operators using evaluateMtlTrace if needed
    test('LTL Temporal Operators (Next, Eventually, Always)', () {
      final p1_at_1 = state<int>((s) => s == 1);
      final p2_at_2 = state<int>((s) => s == 2);
      expect(evalM(trace, Next(p1_at_1)).holds, isTrue); // X(s==1) at index 0 -> check index 1
      expect(evalM(trace, Next(p0)).holds, isFalse); // X(s==0) at index 0 -> check index 1
      expect(evalM(trace, Eventually(p1)).holds, isTrue); // F(s==1)
      expect(evalM(trace, Always(pNonNegative)).holds, isTrue); // G(s>=0)
      expect(evalM(trace, Always(p2)).holds, isFalse); // G(s==2)
    });
  });

  group('MTL Timed Operators (using evaluateMtlTrace)', () {
    // Trace: (a @ 0ms) -> (b @ 100ms) -> (c @ 300ms) -> (d @ 600ms) -> (e @ 1000ms)
    final va = TraceEvent(value: 'a', timestamp: Duration.zero);
    final vb = TraceEvent(value: 'b', timestamp: const Duration(milliseconds: 100));
    final vc = TraceEvent(value: 'c', timestamp: const Duration(milliseconds: 300));
    final vd = TraceEvent(value: 'd', timestamp: const Duration(milliseconds: 600));
    final ve = TraceEvent(value: 'e', timestamp: const Duration(milliseconds: 1000));
    final trace = Trace([va, vb, vc, vd, ve]);

    final pA = state<String>((s) => s == 'a');
    final pB = state<String>((s) => s == 'b');
    final pC = state<String>((s) => s == 'c');
    final pD = state<String>((s) => s == 'd');
    final pE = state<String>((s) => s == 'e');

    test('EventuallyTimed (F_I)', () {
      // F_[0, 150ms] pB
      expect(evalM(trace, EventuallyTimed(pB, TimeInterval(Duration.zero, const Duration(milliseconds: 150)))).holds,
          isTrue);
      // F_[100ms, 100ms] pB
      expect(evalM(trace, EventuallyTimed(pB, TimeInterval.exactly(const Duration(milliseconds: 100)))).holds, isTrue);
      // F_[0, 50ms] pB
      expect(evalM(trace, EventuallyTimed(pB, TimeInterval(Duration.zero, const Duration(milliseconds: 50)))).holds,
          isFalse);
      // F_[150ms, 400ms] pC
      expect(
          evalM(
                  trace,
                  EventuallyTimed(
                      pC, TimeInterval(const Duration(milliseconds: 150), const Duration(milliseconds: 400))))
              .holds,
          isTrue);
      // F_[150ms, 250ms] pC
      expect(
          evalM(
                  trace,
                  EventuallyTimed(
                      pC, TimeInterval(const Duration(milliseconds: 150), const Duration(milliseconds: 250))))
              .holds,
          isFalse);
      // F_[0, 1000ms] pE
      expect(evalM(trace, EventuallyTimed(pE, TimeInterval.upTo(const Duration(milliseconds: 1000)))).holds, isTrue);
      // F_[0, 999ms] pE
      expect(evalM(trace, EventuallyTimed(pE, TimeInterval.upTo(const Duration(milliseconds: 999)))).holds, isFalse);
    });

    test('AlwaysTimed (G_I)', () {
      final pNotE = state<String>((s) => s != 'e', name: 'pNotE');
      // G_[0, 600ms] pNotE
      expect(evalM(trace, AlwaysTimed(pNotE, TimeInterval(Duration.zero, const Duration(milliseconds: 600)))).holds,
          isTrue);
      // G_[0, 1000ms] pNotE
      expect(evalM(trace, AlwaysTimed(pNotE, TimeInterval(Duration.zero, const Duration(milliseconds: 1000)))).holds,
          isFalse); // Fails at time 1000ms
      // G_[100ms, 600ms] pNotE
      expect(
          evalM(
                  trace,
                  AlwaysTimed(
                      pNotE, TimeInterval(const Duration(milliseconds: 100), const Duration(milliseconds: 600))))
              .holds,
          isTrue);
      // G_[100ms, 300ms] (s == b || s == c)
      final pBorC = state<String>((s) => s == 'b' || s == 'c', name: 'pBorC');
      expect(
          evalM(
                  trace,
                  AlwaysTimed(
                      pBorC, TimeInterval(const Duration(milliseconds: 100), const Duration(milliseconds: 300))))
              .holds,
          isTrue);
      // G_[100ms, 301ms] (s == b || s == c) // Interval includes 300ms
      expect(
          evalM(
                  trace,
                  AlwaysTimed(
                      pBorC, TimeInterval(const Duration(milliseconds: 100), const Duration(milliseconds: 301))))
              .holds,
          isTrue);
      // G_[0, 99ms] pA
      expect(evalM(trace, AlwaysTimed(pA, TimeInterval.upTo(const Duration(milliseconds: 99)))).holds, isTrue);
    });

    test('UntilTimed (U_I)', () {
      final pNotD = state<String>((s) => s != 'd', name: 'pNotD');
      // pNotD U_[0, 600ms] pD
      expect(evalM(trace, UntilTimed(pNotD, pD, TimeInterval.upTo(const Duration(milliseconds: 600)))).holds, isTrue);
      // pNotD U_[0, 599ms] pD
      expect(evalM(trace, UntilTimed(pNotD, pD, TimeInterval.upTo(const Duration(milliseconds: 599)))).holds, isFalse);
      // pA U_[0, 100ms] pB
      expect(evalM(trace, UntilTimed(pA, pB, TimeInterval.upTo(const Duration(milliseconds: 100)))).holds, isTrue);
      // pA U_[0, 99ms] pB
      expect(evalM(trace, UntilTimed(pA, pB, TimeInterval.upTo(const Duration(milliseconds: 99)))).holds, isFalse);
      // Test where left fails before right
      // pB U_[100ms, 300ms] pC - This should fail because pB is false at index 0 (time 0ms)
      expect(
          evalM(
                  trace,
                  UntilTimed(
                      pB, pC, TimeInterval(const Duration(milliseconds: 100), const Duration(milliseconds: 300))))
              .holds,
          isFalse);
    });

    // Add tests for nested formulas if needed
  });
}
