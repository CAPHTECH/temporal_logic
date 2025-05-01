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
      expect(trace.isEmpty, isFalse);
      expect(trace.length, 4);
      expect(trace.events.first, v0);
      expect(trace.events.last, v3);
      expect(Trace.empty().isEmpty, isTrue);
    });

    test('Indexer access via events list', () {
      expect(trace.events[0], v0);
      expect(trace.events[1], v1);
      expect(() => trace.events[4], throwsRangeError);
    });

    test('Trace constructor allows monotonic timestamps', () {
      expect(() => Trace([v1, v0]), throwsA(isA<ArgumentError>())); // Check for ArgumentError from core
      expect(() => Trace([v0, v1]), returnsNormally);
    });
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

    test('LTL Temporal Operators (Next, Eventually, Always)', () {
      final p1_at_1 = state<int>((s) => s == 1);
      // final p2_at_2 = state<int>((s) => s == 2);
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
  });

  group('MTL Timed Release (R_I) (using evaluateMtlTrace)', () {
    // Trace: (a @ 0ms) -> (b @ 100ms) -> (c @ 300ms) -> (d @ 600ms) -> (e @ 1000ms)
    final va = TraceEvent(value: ('a', true), timestamp: Duration.zero); // p=true
    final vb = TraceEvent(value: ('b', true), timestamp: const Duration(milliseconds: 100)); // p=true
    final vc = TraceEvent(value: ('c', false), timestamp: const Duration(milliseconds: 300)); // p=false
    final vd = TraceEvent(value: ('d', true), timestamp: const Duration(milliseconds: 600)); // p=true
    final ve = TraceEvent(value: ('e', true), timestamp: const Duration(milliseconds: 1000)); // p=true
    final trace = Trace([va, vb, vc, vd, ve]);

    // p is true if second element of tuple is true
    final p = state<(String, bool)>((s) => s.$2, name: 'p');
    // q is true if first char is 'c' or 'd' or 'e'
    final q = state<(String, bool)>((s) => ['c', 'd', 'e'].contains(s.$1), name: 'q');

    // Definition: q R_I p === G_I p OR (p U_I (p and q)) --- Simplified: p must hold throughout I *unless* q holds at some point t in I, after which p must hold from t until the end of I relative to t.
    // Alternate simpler intuition: For all t' in I relative to t0, if p fails at t', then q must have held at some t'' between t0 and t' (inclusive of t0, exclusive of t'). And p must hold at the end bound of I.

    test('holds when G_I p holds and q does not within I', () {
      // G_[0, 100] p holds. q does not hold in [0, 100]. trace[0..1] values are ('a', T), ('b', T)
      expect(evalM(trace, ReleaseTimed(q, p, TimeInterval.upTo(const Duration(milliseconds: 100)))).holds, isTrue);
    });

    test('fails when p fails and q holds at the same time within I', () {
      // Check G_[0, 300] p. p fails at 300ms ('c', F). q ('c') holds at 300ms.
      // Based on ¬(¬q U_I ¬p):
      // !q: T@a, T@b, F@c
      // !p: F@a, F@b, T@c
      // !q U_[0, 300] !p holds (at t=300ms). So Release should be false.
      expect(evalM(trace, ReleaseTimed(q, p, TimeInterval.upTo(const Duration(milliseconds: 300)))).holds, isFalse);
    });

    test('fails when p fails and q holds relative to interval start', () {
      // q R_[100, 600] p
      // Interval timestamps relative to 100ms: 0ms, 200ms, 500ms. Values: ('b', T), ('c', F), ('d', T)
      // Check G_[0, 500] p relative to 100ms. Fails at 200ms rel (300ms abs).
      // Check ¬(¬q U_[0, 500] ¬p) relative to 100ms
      // !q: T@b, F@c, F@d
      // !p: F@b, T@c, F@d
      // Need !q U_[0, 500] !p. !p holds at 200ms rel. !q holds at 0ms rel. !q fails at 200ms rel.
      // Until holds. Release fails.
      expect(
          evalM(
                  trace,
                  ReleaseTimed(
                      q, p, TimeInterval(const Duration(milliseconds: 100), const Duration(milliseconds: 600))))
              .holds,
          isFalse);
    });

    test('holds when G_I p holds over the interval', () {
      // G_[600, 1000] p holds. values ('d', T), ('e', T)
      expect(
          evalM(
                  trace,
                  ReleaseTimed(
                      q, p, TimeInterval(const Duration(milliseconds: 600), const Duration(milliseconds: 1000))))
              .holds,
          isTrue);
    });

    test('fails when p fails within a larger interval', () {
      // G_[0, 1000] p fails because p is false at 300ms.
      // Check ¬(¬q U_[0, 1000] ¬p)
      // !q: T@a, T@b, F@c, F@d, F@e
      // !p: F@a, F@b, T@c, F@d, F@e
      // Need !q U_[0, 1000] !p. !p holds at 300ms. !q holds at 0, 100. Fails at 300. Until holds. Release fails.
      expect(evalM(trace, ReleaseTimed(q, p, TimeInterval.upTo(const Duration(milliseconds: 1000)))).holds, isFalse);
    });
  });

  group('MTL Timed Weak Until (W_I) (using evaluateMtlTrace)', () {
    // Trace: (a @ 0ms) -> (b @ 100ms) -> (c @ 300ms) -> (d @ 600ms) -> (e @ 1000ms)
    final va = TraceEvent(value: ('a', true), timestamp: Duration.zero); // p=true
    final vb = TraceEvent(value: ('b', false), timestamp: const Duration(milliseconds: 100)); // p=false
    final vc = TraceEvent(value: ('c', true), timestamp: const Duration(milliseconds: 300)); // p=true
    final vd = TraceEvent(value: ('d', true), timestamp: const Duration(milliseconds: 600)); // p=true
    final ve = TraceEvent(value: ('e', false), timestamp: const Duration(milliseconds: 1000)); // p=false
    final trace = Trace([va, vb, vc, vd, ve]);

    final p = state<(String, bool)>((s) => s.$2, name: 'p');
    final q = state<(String, bool)>((s) => ['d', 'e'].contains(s.$1), name: 'q'); // q holds at d, e

    // Definition: p W_I q === G_I p OR (p U_I q)

    test('fails when G_I p fails and p U_I q fails (p fails early)', () {
      // p W_[0, 600] q.
      // G_[0, 600] p fails at 100ms.
      // p U_[0, 600] q. q holds at 600ms ('d'). p must hold up to 600ms. Fails at 100ms.
      expect(evalM(trace, WeakUntilTimed(p, q, TimeInterval.upTo(const Duration(milliseconds: 600)))).holds, isFalse);
    });

    test('holds when G_I p holds', () {
      // p W_[300, 600] q.
      // G_[300, 600] p. Values ('c', T), ('d', T). Holds.
      expect(
          evalM(
                  trace,
                  WeakUntilTimed(
                      p, q, TimeInterval(const Duration(milliseconds: 300), const Duration(milliseconds: 600))))
              .holds,
          isTrue);
    });

    test('fails when G_I p fails and p U_I q fails (p fails later)', () {
      // p W_[0, 1000] q.
      // G_[0, 1000] p fails (at 100ms and 1000ms).
      // p U_[0, 1000] q. q holds at 600ms ('d'). p must hold up to 600ms. Fails at 100ms.
      expect(evalM(trace, WeakUntilTimed(p, q, TimeInterval.upTo(const Duration(milliseconds: 1000)))).holds, isFalse);
    });

    test('holds when p U_I q holds (q holds within interval)', () {
      // p W_[600, 1000] q. Interval [600, 1000]. Values ('d', T), ('e', F).
      // G_[600, 1000] p fails at 1000ms.
      // p U_[600, 1000] q. q holds at 600ms. Interval is [600,1000]. timeDiff=0. OK.
      // Need p to hold for j=0 up to k=3 (d@600). Fails at j=1 (b@100).
      // So Until should be false. Weak Until should be false.
      expect(
          evalM(
                  trace,
                  WeakUntilTimed(
                      p, q, TimeInterval(const Duration(milliseconds: 600), const Duration(milliseconds: 1000))))
              .holds,
          isFalse);
    });

    test('holds on empty trace', () {
      // G_I p holds vacuously on empty trace.
      final emptyTrace = Trace<(String, bool)>([]);
      expect(evalM(emptyTrace, WeakUntilTimed(p, q, TimeInterval.upTo(const Duration(seconds: 1)))).holds, isTrue);
    });
  });

  group('MTL Nested/Complex Formulas (using evaluateMtlTrace)', () {
    // Trace 1 for G(p->Fq) and F(p && Gq)
    final trace1_v0 = TraceEvent(value: {'p': true, 'q': false}, timestamp: Duration.zero);
    final trace1_v1 = TraceEvent(value: {'p': true, 'q': false}, timestamp: const Duration(milliseconds: 100));
    final trace1_v2 = TraceEvent(value: {'p': false, 'q': true}, timestamp: const Duration(milliseconds: 300));
    final trace1_v3 = TraceEvent(value: {'p': true, 'q': true}, timestamp: const Duration(milliseconds: 500));
    final trace1_v4 = TraceEvent(value: {'p': false, 'q': false}, timestamp: const Duration(milliseconds: 800));
    final trace1 = Trace([trace1_v0, trace1_v1, trace1_v2, trace1_v3, trace1_v4]);

    final p1 = state<Map<String, bool>>((s) => s['p']!, name: 'p');
    final q1 = state<Map<String, bool>>((s) => s['q']!, name: 'q');

    // --- Tests using trace1 ---

    test('G_[0, 500ms] (p -> F_[0, 400ms] q)', () {
      final intervalG = TimeInterval.upTo(const Duration(milliseconds: 500));
      final intervalF = TimeInterval.upTo(const Duration(milliseconds: 400));
      final formula = AlwaysTimed(Implies(p1, EventuallyTimed(q1, intervalF)), intervalG);
      expect(evalM(trace1, formula).holds, isTrue);
    });

    test('G_[0, 500ms] (p -> F_[0, 150ms] q)', () {
      final intervalG = TimeInterval.upTo(const Duration(milliseconds: 500));
      final intervalF = TimeInterval.upTo(const Duration(milliseconds: 150));
      final formula = AlwaysTimed(Implies(p1, EventuallyTimed(q1, intervalF)), intervalG);
      final result = evalM(trace1, formula);
      expect(result.holds, isFalse);
      expect(result.relatedIndex, 0);
      expect(result.reason, contains('AlwaysTimed failed'));
      expect(result.reason, contains('EventuallyTimed failed'));
    });

    test('F_[0, 300ms] (p && G_[0, 200ms] q)', () {
      final intervalF = TimeInterval.upTo(const Duration(milliseconds: 300));
      final intervalG = TimeInterval.upTo(const Duration(milliseconds: 200));
      final formula = EventuallyTimed(And(p1, AlwaysTimed(q1, intervalG)), intervalF);
      expect(evalM(trace1, formula).holds, isFalse);
    });

    test('F_[0, 800ms] (p && G_[0, 300ms] q)', () {
      final intervalF = TimeInterval.upTo(const Duration(milliseconds: 800));
      final intervalG = TimeInterval.upTo(const Duration(milliseconds: 300));
      final formula = EventuallyTimed(And(p1, AlwaysTimed(q1, intervalG)), intervalF);
      expect(evalM(trace1, formula).holds, isFalse);
    });

    // --- Trace 2 and definitions for p U (q R r) ---
    // Trace: (p:T,q:F,r:T @ 0) -> (p:T,q:T,r:T @ 100) -> (p:F,q:T,r:F @ 300) -> (p:T,q:F,r:T @ 500)
    final trace2_v0 = TraceEvent(value: {'p': true, 'q': false, 'r': true}, timestamp: Duration.zero);
    final trace2_v1 =
        TraceEvent(value: {'p': true, 'q': true, 'r': true}, timestamp: const Duration(milliseconds: 100));
    final trace2_v2 =
        TraceEvent(value: {'p': false, 'q': true, 'r': false}, timestamp: const Duration(milliseconds: 300));
    final trace2_v3 =
        TraceEvent(value: {'p': true, 'q': false, 'r': true}, timestamp: const Duration(milliseconds: 500));
    final trace2 = Trace([trace2_v0, trace2_v1, trace2_v2, trace2_v3]);

    final p2 = state<Map<String, bool>>((s) => s['p']!, name: 'p');
    final q2 = state<Map<String, bool>>((s) => s['q']!, name: 'q');
    final r2 = state<Map<String, bool>>((s) => s['r']!, name: 'r');

    test('p U_[0, 300ms] (q R_[0, 150ms] r)', () {
      final intervalU = TimeInterval.upTo(const Duration(milliseconds: 300)); // For U
      final intervalR = TimeInterval.upTo(const Duration(milliseconds: 150)); // For R
      final innerRelease = ReleaseTimed(q2, r2, intervalR);
      final formula = UntilTimed(p2, innerRelease, intervalU);

      // Evaluate at index 0 (t=0):
      // Need innerRelease to hold at k in [0, 300] (k=0,1,2), and p2 to hold for j < k.
      // Check innerRelease = q R_[0, 150] r at k=0 (t=0):
      //   Interval for R: [0, 150]. Points rel to t=0: k=0,1.
      //   Check R: Need r to hold unless q holds. Check ¬(¬q U_[0,150] ¬r).
      //   ¬q: T@k=0, F@k=1
      //   ¬r: F@k=0, F@k=1
      //   ¬q U_[0,150] ¬r: Need ¬r at k' in [0,150] (k'=0,1), and ¬q for j'<k'.
      //   ¬r holds at k'=0. Need ¬q for j'<0 (none). Holds.
      //   ¬q U ¬r holds. So, !(...) is false. Release fails at k=0.
      // Check innerRelease = q R_[0, 150] r at k=1 (t=100):
      //   Interval for R: [0, 150]. Points rel to t=100: k=1 (t=100), k=2 (t=300 is outside 100+150).
      //   Check R: Need r unless q holds. Check ¬(¬q U_[0,150] ¬r) from t=100.
      //   ¬q: F@k=1 (rel t=0), T@k=2 (rel t=200)
      //   ¬r: F@k=1 (rel t=0), T@k=2 (rel t=200)
      //   ¬q U_[0,150] ¬r: Need ¬r at k' in [100, 250]. None.
      //   ¬q U ¬r fails. So, !(...) is true. Release holds at k=1.
      // Now, check U condition: innerRelease holds at k=1 (in U interval [0, 300]).
      // Need p2 to hold for j < 1 (i.e., j=0).
      // p2 @ j=0 is true.
      // Therefore, Until holds.
      expect(evalM(trace2, formula).holds, isTrue);
    });

    // --- Boundary Condition and Empty Trace Tests ---
    final emptyTrace = Trace<Map<String, bool>>([]);
    final singleEventTrace = Trace([
      TraceEvent(value: {'p': true, 'q': false}, timestamp: Duration.zero)
    ]);
    final p = state<Map<String, bool>>((s) => s['p']!, name: 'p'); // Re-use p/q defs
    final q = state<Map<String, bool>>((s) => s['q']!, name: 'q');

    test('EventuallyTimed on empty trace', () {
      final formula = EventuallyTimed(p, TimeInterval.upTo(const Duration(seconds: 1)));
      expect(evalM(emptyTrace, formula).holds, isFalse);
      expect(evalM(emptyTrace, formula).reason, contains('EventuallyTimed evaluated past trace end'));
    });

    test('AlwaysTimed on empty trace', () {
      final formula = AlwaysTimed(p, TimeInterval.upTo(const Duration(seconds: 1)));
      expect(evalM(emptyTrace, formula).holds, isTrue); // Vacuously true
    });

    test('UntilTimed on empty trace', () {
      final formula = UntilTimed(p, q, TimeInterval.upTo(const Duration(seconds: 1)));
      expect(evalM(emptyTrace, formula).holds, isFalse);
      expect(evalM(emptyTrace, formula).reason, contains('UntilTimed evaluated past trace end'));
    });

    test('ReleaseTimed on empty trace', () {
      final formula = ReleaseTimed(p, q, TimeInterval.upTo(const Duration(seconds: 1)));
      expect(evalM(emptyTrace, formula).holds, isTrue); // Vacuously true
    });

    test('WeakUntilTimed on empty trace', () {
      final formula = WeakUntilTimed(p, q, TimeInterval.upTo(const Duration(seconds: 1)));
      expect(evalM(emptyTrace, formula).holds, isTrue); // Vacuously true (G_I p holds)
    });

    test('EventuallyTimed with zero interval', () {
      // F_[0,0] p on single event trace where p is true
      final formula = EventuallyTimed(p, TimeInterval.exactly(Duration.zero));
      expect(evalM(singleEventTrace, formula).holds, isTrue);
      // F_[0,0] q on single event trace where q is false
      final formulaQ = EventuallyTimed(q, TimeInterval.exactly(Duration.zero));
      expect(evalM(singleEventTrace, formulaQ).holds, isFalse);
    });

    test('AlwaysTimed with zero interval', () {
      // G_[0,0] p on single event trace where p is true
      final formula = AlwaysTimed(p, TimeInterval.exactly(Duration.zero));
      expect(evalM(singleEventTrace, formula).holds, isTrue);
      // G_[0,0] q on single event trace where q is false
      final formulaQ = AlwaysTimed(q, TimeInterval.exactly(Duration.zero));
      expect(evalM(singleEventTrace, formulaQ).holds, isFalse);
    });

    test('UntilTimed with zero interval', () {
      // p U_[0,0] q on single event trace where p=T, q=F
      final formula = UntilTimed(p, q, TimeInterval.exactly(Duration.zero));
      // Need q at k=0 (in interval [0,0]). q is false. Fails.
      expect(evalM(singleEventTrace, formula).holds, isFalse);
      // p U_[0,0] p on single event trace where p=T
      final formulaP = UntilTimed(p, p, TimeInterval.exactly(Duration.zero));
      // Need p at k=0 (in interval [0,0]). p is true. Need p for j<0 (none). Holds.
      expect(evalM(singleEventTrace, formulaP).holds, isTrue);
    });

    test('ReleaseTimed with zero interval', () {
      // p R_[0,0] q on single event trace where p=T, q=F
      // Check !(!p U_[0,0] !q)
      // !p = F, !q = T
      // Need !q at k=0 (in interval). !q holds. Need !p for j<0 (none). Until holds.
      // Release = !Until = false.
      final formula = ReleaseTimed(p, q, TimeInterval.exactly(Duration.zero));
      expect(evalM(singleEventTrace, formula).holds, isFalse);

      // q R_[0,0] p on single event trace where q=F, p=T
      // Check !(!q U_[0,0] !p)
      // !q = T, !p = F
      // Need !p at k=0 (in interval). !p fails.
      // Until fails. Release = !Until = true.
      final formulaQP = ReleaseTimed(q, p, TimeInterval.exactly(Duration.zero));
      expect(evalM(singleEventTrace, formulaQP).holds, isTrue);
    });

    test('WeakUntilTimed with zero interval', () {
      // p W_[0,0] q on single event trace where p=T, q=F
      // Check G_[0,0] p. Holds.
      final formula = WeakUntilTimed(p, q, TimeInterval.exactly(Duration.zero));
      expect(evalM(singleEventTrace, formula).holds, isTrue);
      // q W_[0,0] p on single event trace where q=F, p=T
      // Check G_[0,0] q. Fails.
      // Check q U_[0,0] p. Need p at k=0 (in interval). p holds. Need q for j<0 (none).
      // Until holds. Weak Until holds.
      final formulaQP = WeakUntilTimed(q, p, TimeInterval.exactly(Duration.zero));
      expect(evalM(singleEventTrace, formulaQP).holds, isTrue);
    });

    test('EventuallyTimed interval past trace end', () {
      // F_[100ms, 200ms] p on single event trace at 0ms (p=T)
      final formula =
          EventuallyTimed(p, TimeInterval(const Duration(milliseconds: 100), const Duration(milliseconds: 200)));
      expect(evalM(singleEventTrace, formula).holds, isFalse); // No events in interval
    });

    test('AlwaysTimed interval past trace end', () {
      // G_[100ms, 200ms] p on single event trace at 0ms (p=T)
      final formula =
          AlwaysTimed(p, TimeInterval(const Duration(milliseconds: 100), const Duration(milliseconds: 200)));
      expect(evalM(singleEventTrace, formula).holds, isTrue); // Vacuously true
    });

    // Add more boundary condition tests...
  });
}
