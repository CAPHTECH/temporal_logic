import 'package:glados/glados.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart';

import 'generators.dart';
import 'reference_evaluator.dart';

void main() {
  final config = ExploreConfig(numRuns: 200, initialSize: 5, speed: 1);

  group('Duality Laws', () {
    // 1. G(p) == !F(!p)
    Glados2(any.traceOfInt, any.d1Formula, config).test(
      'G(p) == !F(!p)',
      (trace, p) {
        for (var si = 0; si <= trace.length; si++) {
          final gp = evaluateTrace(trace, Always(p), startIndex: si).holds;
          final nfnp =
              evaluateTrace(trace, Not(Eventually(Not(p))), startIndex: si)
                  .holds;
          expect(gp, equals(nfnp),
              reason: 'G($p) != !F(!$p) at index $si on $trace');
        }
      },
    );

    // 2. F(p) == !G(!p)
    Glados2(any.traceOfInt, any.d1Formula, config).test(
      'F(p) == !G(!p)',
      (trace, p) {
        for (var si = 0; si <= trace.length; si++) {
          final fp = evaluateTrace(trace, Eventually(p), startIndex: si).holds;
          final ngnp =
              evaluateTrace(trace, Not(Always(Not(p))), startIndex: si).holds;
          expect(fp, equals(ngnp),
              reason: 'F($p) != !G(!$p) at index $si on $trace');
        }
      },
    );

    // 3. R(p,q) == !(!p U !q)
    Glados3(any.traceOfInt, any.atomFormula, any.atomFormula, config).test(
      'R(p,q) == !(!p U !q)',
      (trace, p, q) {
        for (var si = 0; si <= trace.length; si++) {
          final rpq =
              evaluateTrace(trace, Release(p, q), startIndex: si).holds;
          final dual =
              evaluateTrace(trace, Not(Until(Not(p), Not(q))), startIndex: si)
                  .holds;
          expect(rpq, equals(dual),
              reason: 'R($p,$q) != !(!$p U !$q) at index $si on $trace');
        }
      },
    );

    // 4. W(p,q) == G(p) || (p U q)
    Glados3(any.traceOfInt, any.atomFormula, any.atomFormula, config).test(
      'W(p,q) == G(p) || (p U q)',
      (trace, p, q) {
        for (var si = 0; si <= trace.length; si++) {
          final wpq =
              evaluateTrace(trace, WeakUntil(p, q), startIndex: si).holds;
          final dual =
              evaluateTrace(trace, Or(Always(p), Until(p, q)), startIndex: si)
                  .holds;
          expect(wpq, equals(dual),
              reason: 'W($p,$q) != G($p)||($p U $q) at index $si on $trace');
        }
      },
    );

    // 5. Double negation (involution): !!p == p
    Glados2(any.traceOfInt, any.d1Formula, config).test(
      '!!p == p (involution)',
      (trace, p) {
        for (var si = 0; si <= trace.length; si++) {
          final pHolds = evaluateTrace(trace, p, startIndex: si).holds;
          final nnp = evaluateTrace(trace, Not(Not(p)), startIndex: si).holds;
          expect(nnp, equals(pHolds),
              reason: '!!($p) != $p at index $si on $trace');
        }
      },
    );
  });

  group('Reference Model', () {
    // 6. Release: evaluator matches naive implementation
    Glados3(any.traceOfInt, any.atomFormula, any.atomFormula, config).test(
      'Release matches naive reference',
      (trace, p, q) {
        for (var si = 0; si <= trace.length; si++) {
          final evalResult =
              evaluateTrace(trace, Release(p, q), startIndex: si).holds;
          final naiveResult = naiveRelease(trace, p, q, si);
          expect(evalResult, equals(naiveResult),
              reason:
                  'Release($p,$q) evaluator vs naive at index $si on $trace');
        }
      },
    );

    // 7. WeakUntil: evaluator matches naive implementation
    Glados3(any.traceOfInt, any.atomFormula, any.atomFormula, config).test(
      'WeakUntil matches naive reference',
      (trace, p, q) {
        for (var si = 0; si <= trace.length; si++) {
          final evalResult =
              evaluateTrace(trace, WeakUntil(p, q), startIndex: si).holds;
          final naiveResult = naiveWeakUntil(trace, p, q, si);
          expect(evalResult, equals(naiveResult),
              reason:
                  'WeakUntil($p,$q) evaluator vs naive at index $si on $trace');
        }
      },
    );
  });

  group('Metamorphic Properties', () {
    // 8. Suffix normalization: eval(trace, phi, i) == eval(suffix(i), phi, 0)
    Glados2(any.traceOfInt, any.d1Formula, config).test(
      'suffix normalization',
      (trace, phi) {
        for (var si = 0; si <= trace.length; si++) {
          final direct = evaluateTrace(trace, phi, startIndex: si).holds;
          // Create suffix trace starting at index si
          final suffixEvents = trace.events.sublist(si);
          // Adjust timestamps: subtract the base timestamp
          final baseTs =
              suffixEvents.isNotEmpty ? suffixEvents.first.timestamp : Duration.zero;
          final adjustedEvents = suffixEvents
              .map((e) =>
                  TraceEvent(timestamp: e.timestamp - baseTs, value: e.value))
              .toList();
          final suffixTrace = Trace(adjustedEvents);
          final viaSuffix = evaluateTrace(suffixTrace, phi, startIndex: 0).holds;
          expect(direct, equals(viaSuffix),
              reason:
                  'eval($phi, si=$si) != eval(suffix, 0) on $trace');
        }
      },
    );

    // 9. Determinism: same inputs always produce same result
    Glados2(any.traceOfInt, any.d2Formula, config).test(
      'determinism',
      (trace, formula) {
        for (var si = 0; si <= trace.length; si++) {
          final r1 = evaluateTrace(trace, formula, startIndex: si).holds;
          final r2 = evaluateTrace(trace, formula, startIndex: si).holds;
          expect(r1, equals(r2),
              reason: 'Non-deterministic result for $formula at $si on $trace');
        }
      },
    );
  });

  group('Invariants', () {
    // 10. Vacuous truth: G(p) on empty suffix is true, F(p) is false
    Glados(any.d1Formula, config).test(
      'vacuous truth on empty trace',
      (p) {
        final emptyTrace = Trace<int>.empty();
        expect(evaluateTrace(emptyTrace, Always(p)).holds, isTrue,
            reason: 'G($p) should be vacuously true on empty trace');
        expect(evaluateTrace(emptyTrace, Eventually(p)).holds, isFalse,
            reason: 'F($p) should be false on empty trace');
      },
    );

    // 11. No crash on any valid trace/formula/startIndex combination
    Glados2(any.traceOfInt, any.d2Formula, config).test(
      'no crash on valid inputs',
      (trace, formula) {
        for (var si = 0; si <= trace.length; si++) {
          final result = evaluateTrace(trace, formula, startIndex: si);
          expect(result, isA<EvaluationResult>());
        }
      },
    );
  });
}
