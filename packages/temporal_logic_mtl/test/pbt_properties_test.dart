import 'package:glados/glados.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart' as core;
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';

import 'generators.dart';

void main() {
  final config = ExploreConfig(numRuns: 200, initialSize: 5, speed: 1);

  group('Timed Duality Laws', () {
    // 1. G_I(p) == !F_I(!p)
    Glados3(any.traceOfInt, any.atomFormula, any.timeInterval, config).test(
      'G_I(p) == !F_I(!p)',
      (trace, p, interval) {
        for (var si = 0; si <= trace.length; si++) {
          final gip =
              evaluateMtlTrace(trace, AlwaysTimed(p, interval), startIndex: si)
                  .holds;
          final nfinp = evaluateMtlTrace(
                  trace, Not(EventuallyTimed(Not(p), interval)),
                  startIndex: si)
              .holds;
          expect(gip, equals(nfinp),
              reason:
                  'G_$interval($p) != !F_$interval(!$p) at si=$si on $trace');
        }
      },
    );

    // 2. R_I(p,q) == !(!p U_I !q)
    Glados(
      any.combine4(
        any.traceOfInt,
        any.atomFormula,
        any.atomFormula,
        any.timeInterval,
        (Trace<int> t, Formula<int> p, Formula<int> q, TimeInterval iv) =>
            (t, p, q, iv),
      ),
      config,
    ).test(
      'R_I(p,q) == !(!p U_I !q)',
      (input) {
        final (trace, p, q, interval) = input;
        for (var si = 0; si <= trace.length; si++) {
          final rip = evaluateMtlTrace(
                  trace, ReleaseTimed(p, q, interval),
                  startIndex: si)
              .holds;
          final dual = evaluateMtlTrace(
                  trace, Not(UntilTimed(Not(p), Not(q), interval)),
                  startIndex: si)
              .holds;
          expect(rip, equals(dual),
              reason:
                  'R_$interval($p,$q) != !(!$p U_$interval !$q) at si=$si on $trace');
        }
      },
    );

    // 3. W_I(p,q) == G_I(p) || (p U_I q)
    Glados(
      any.combine4(
        any.traceOfInt,
        any.atomFormula,
        any.atomFormula,
        any.timeInterval,
        (Trace<int> t, Formula<int> p, Formula<int> q, TimeInterval iv) =>
            (t, p, q, iv),
      ),
      config,
    ).test(
      'W_I(p,q) == G_I(p) || (p U_I q)',
      (input) {
        final (trace, p, q, interval) = input;
        for (var si = 0; si <= trace.length; si++) {
          final wip = evaluateMtlTrace(
                  trace, WeakUntilTimed(p, q, interval),
                  startIndex: si)
              .holds;
          final dual = evaluateMtlTrace(
                  trace,
                  Or(AlwaysTimed(p, interval), UntilTimed(p, q, interval)),
                  startIndex: si)
              .holds;
          expect(wip, equals(dual),
              reason:
                  'W_$interval($p,$q) != G_$interval($p)||($p U_$interval $q) at si=$si on $trace');
        }
      },
    );
  });

  group('Timed Duality Laws (trace-relative intervals)', () {
    // G_I(p) == !F_I(!p) with intervals derived from actual trace span
    Glados2(any.traceWithRelativeInterval, any.atomFormula, config).test(
      'G_I(p) == !F_I(!p) (trace-relative)',
      (pair, p) {
        final (trace, interval) = pair;
        for (var si = 0; si <= trace.length; si++) {
          final gip =
              evaluateMtlTrace(trace, AlwaysTimed(p, interval), startIndex: si)
                  .holds;
          final nfinp = evaluateMtlTrace(
                  trace, Not(EventuallyTimed(Not(p), interval)),
                  startIndex: si)
              .holds;
          expect(gip, equals(nfinp),
              reason:
                  'G_$interval($p) != !F_$interval(!$p) at si=$si on $trace');
        }
      },
    );
  });

  group('Core/MTL Parity', () {
    // 4. Pure LTL formulas: core evaluator == MTL evaluator
    Glados2(any.traceOfInt, any.pureLtlD2, config).test(
      'evaluateTrace == evaluateMtlTrace for pure LTL',
      (trace, formula) {
        for (var si = 0; si <= trace.length; si++) {
          final coreResult =
              core.evaluateTrace(trace, formula, startIndex: si).holds;
          final mtlResult =
              evaluateMtlTrace(trace, formula, startIndex: si).holds;
          expect(coreResult, equals(mtlResult),
              reason:
                  'Core vs MTL mismatch for $formula at si=$si on $trace');
        }
      },
    );
  });

  group('Metamorphic Properties', () {
    // 5. Time-translation invariance: shifting all timestamps by constant c
    //    doesn't change .holds for timed formulas (intervals are relative).
    Glados2(any.traceOfInt, any.timedD2Formula, config).test(
      'time-translation invariance (timed formulas)',
      (trace, formula) {
        const shift = Duration(milliseconds: 100);
        final shiftedEvents = trace.events
            .map((e) =>
                TraceEvent(timestamp: e.timestamp + shift, value: e.value))
            .toList();
        final shiftedTrace = Trace(shiftedEvents);
        for (var si = 0; si <= trace.length; si++) {
          final original =
              evaluateMtlTrace(trace, formula, startIndex: si).holds;
          final shifted =
              evaluateMtlTrace(shiftedTrace, formula, startIndex: si).holds;
          expect(original, equals(shifted),
              reason:
                  'Time-translation changed result for $formula at si=$si');
        }
      },
    );

    // 6. Suffix normalization for timed formulas:
    //    eval(trace, phi, i) == eval(suffix(i), phi, 0)
    Glados2(any.traceOfInt, any.timedD2Formula, config).test(
      'suffix normalization (timed formulas)',
      (trace, phi) {
        for (var si = 0; si <= trace.length; si++) {
          final direct =
              evaluateMtlTrace(trace, phi, startIndex: si).holds;
          final suffixEvents = trace.events.sublist(si);
          final baseTs = suffixEvents.isNotEmpty
              ? suffixEvents.first.timestamp
              : Duration.zero;
          final adjustedEvents = suffixEvents
              .map((e) =>
                  TraceEvent(timestamp: e.timestamp - baseTs, value: e.value))
              .toList();
          final suffixTrace = Trace(adjustedEvents);
          final viaSuffix =
              evaluateMtlTrace(suffixTrace, phi, startIndex: 0).holds;
          expect(direct, equals(viaSuffix),
              reason:
                  'eval($phi, si=$si) != eval(suffix, 0) on $trace');
        }
      },
    );

    // 7. Interval monotonicity:
    //    I ⊆ J → F_I(p).holds → F_J(p).holds
    //    I ⊆ J → G_J(p).holds → G_I(p).holds
    Glados(
      any.combine4(
        any.traceOfInt,
        any.atomFormula,
        any.timeInterval,
        any.choose([0, 1, 2, 5, 10, 50]),
        (Trace<int> t, Formula<int> p, TimeInterval inner, int expansion) =>
            (t, p, inner, expansion),
      ),
      config,
    ).test(
      'interval monotonicity',
      (input) {
        final (trace, p, inner, expansion) = input;
        // Build outer interval: expand inner by `expansion` ms on each side
        final outerLb = inner.lowerBound - Duration(milliseconds: expansion);
        final effectiveLb =
            outerLb.isNegative ? Duration.zero : outerLb;
        final outer = TimeInterval(
          effectiveLb,
          inner.upperBound + Duration(milliseconds: expansion),
        );

        for (var si = 0; si <= trace.length; si++) {
          // F_I(p) → F_J(p) (inner ⊆ outer)
          final fInner = evaluateMtlTrace(
                  trace, EventuallyTimed(p, inner),
                  startIndex: si)
              .holds;
          final fOuter = evaluateMtlTrace(
                  trace, EventuallyTimed(p, outer),
                  startIndex: si)
              .holds;
          if (fInner) {
            expect(fOuter, isTrue,
                reason:
                    'F_$inner($p) true but F_$outer($p) false at si=$si');
          }

          // G_J(p) → G_I(p) (inner ⊆ outer)
          final gOuter = evaluateMtlTrace(
                  trace, AlwaysTimed(p, outer),
                  startIndex: si)
              .holds;
          final gInner = evaluateMtlTrace(
                  trace, AlwaysTimed(p, inner),
                  startIndex: si)
              .holds;
          if (gOuter) {
            expect(gInner, isTrue,
                reason:
                    'G_$outer($p) true but G_$inner($p) false at si=$si');
          }
        }
      },
    );
  });

  group('Robustness', () {
    // No crash on any valid trace/timedD2Formula/startIndex combination
    Glados2(any.traceOfInt, any.timedD2Formula, config).test(
      'no crash on timed formula inputs',
      (trace, formula) {
        for (var si = 0; si <= trace.length; si++) {
          final result = evaluateMtlTrace(trace, formula, startIndex: si);
          expect(result, isA<EvaluationResult>());
        }
      },
    );

    // No crash on nested timed formulas (timed-over-timed)
    Glados2(any.traceOfInt, any.nestedTimedFormula, config).test(
      'no crash on nested timed formula inputs',
      (trace, formula) {
        for (var si = 0; si <= trace.length; si++) {
          final result = evaluateMtlTrace(trace, formula, startIndex: si);
          expect(result, isA<EvaluationResult>());
        }
      },
    );
  });
}
