import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';
import 'package:test/test.dart';

/// Parameterized parity verification: evaluateTrace (core) vs evaluateMtlTrace (mtl)
/// for pure-LTL formulas. Both evaluators should agree on `.holds` when given the
/// same trace, formula, and startIndex.
void main() {
  // --- Predicates ---
  final pEven = state<int>((s) => s % 2 == 0, name: 'pEven');
  final pPos = state<int>((s) => s > 0, name: 'pPos');
  final pZero = state<int>((s) => s == 0, name: 'pZero');
  final pTrue = state<int>((_) => true, name: 'pTrue');
  final pFalse = state<int>((_) => false, name: 'pFalse');
  final pOdd = Not(pEven);

  // --- Traces ---
  final traces = <String, Trace<int>>{
    'empty': Trace<int>.empty(),
    '[0,1,2,3]': Trace.fromList([0, 1, 2, 3]),
    '[2,4,6,8]': Trace.fromList([2, 4, 6, 8]),
    '[1,2,3,4]': Trace.fromList([1, 2, 3, 4]),
    '[1,0,1,0]': Trace.fromList([1, 0, 1, 0]),
    '[0,0,0,0]': Trace.fromList([0, 0, 0, 0]),
  };

  // --- Formulas ---
  final formulas = <String, Formula<int>>{
    'pEven': pEven,
    'pPos': pPos,
    'pZero': pZero,
    'pTrue': pTrue,
    'pFalse': pFalse,
    'Not(pEven)': pOdd,
    'And(pEven,pPos)': And(pEven, pPos),
    'Or(pEven,pPos)': Or(pEven, pPos),
    'Implies(pPos,pEven)': Implies(pPos, pEven),
    'Next(pEven)': Next(pEven),
    'Always(pEven)': Always(pEven),
    'Eventually(pZero)': Eventually(pZero),
    'Until(pPos,pEven)': Until(pPos, pEven),
    'WeakUntil(pEven,pZero)': WeakUntil(pEven, pZero),
    'Release(pFalse,pTrue)': Release(pFalse, pTrue),
  };

  group('Parity: evaluateTrace vs evaluateMtlTrace at startIndex=0', () {
    for (final traceEntry in traces.entries) {
      for (final formulaEntry in formulas.entries) {
        test('${formulaEntry.key} on ${traceEntry.key}', () {
          final trace = traceEntry.value;
          final formula = formulaEntry.value;

          final coreResult = evaluateTrace(trace, formula, startIndex: 0);
          final mtlResult =
              evaluateMtlTrace(trace, formula, startIndex: 0);

          expect(mtlResult.holds, equals(coreResult.holds),
              reason:
                  'Parity mismatch for ${formulaEntry.key} on ${traceEntry.key}: '
                  'core=${coreResult.holds}, mtl=${mtlResult.holds}');
        });
      }
    }
  });

  group('Parity: evaluateTrace vs evaluateMtlTrace at startIndex > 0', () {
    // Test with startIndex 1 and 2 on non-empty traces
    final nonEmptyTraces = Map.fromEntries(
        traces.entries.where((e) => e.key != 'empty'));

    for (final traceEntry in nonEmptyTraces.entries) {
      for (final startIndex in [1, 2]) {
        // Skip if startIndex would be out of trace range for MTL
        // (MTL rejects startIndex > trace.length)
        if (startIndex > traceEntry.value.length) continue;

        for (final formulaEntry in formulas.entries) {
          test('${formulaEntry.key} on ${traceEntry.key} at startIndex=$startIndex',
              () {
            final trace = traceEntry.value;
            final formula = formulaEntry.value;

            final coreResult =
                evaluateTrace(trace, formula, startIndex: startIndex);
            final mtlResult =
                evaluateMtlTrace(trace, formula, startIndex: startIndex);

            expect(mtlResult.holds, equals(coreResult.holds),
                reason:
                    'Parity mismatch for ${formulaEntry.key} on ${traceEntry.key} '
                    'at startIndex=$startIndex: '
                    'core=${coreResult.holds}, mtl=${mtlResult.holds}');
          });
        }
      }
    }
  });

  group('Parity: nested temporal formulas', () {
    final nestedFormulas = <String, Formula<int>>{
      'G(F(pZero))': Always(Eventually(pZero)),
      'F(G(pEven))': Eventually(Always(pEven)),
      'G(pPos => X(pEven))': Always(Implies(pPos, Next(pEven))),
      'F(pEven && G(pPos))': Eventually(And(pEven, Always(pPos))),
      'pPos U (pEven W pZero)': Until(pPos, WeakUntil(pEven, pZero)),
      'G(F(G(pZero)))': Always(Eventually(Always(pZero))),
    };

    for (final traceEntry in traces.entries) {
      for (final formulaEntry in nestedFormulas.entries) {
        test('${formulaEntry.key} on ${traceEntry.key}', () {
          final trace = traceEntry.value;
          final formula = formulaEntry.value;

          final coreResult = evaluateTrace(trace, formula, startIndex: 0);
          final mtlResult =
              evaluateMtlTrace(trace, formula, startIndex: 0);

          expect(mtlResult.holds, equals(coreResult.holds),
              reason:
                  'Parity mismatch for ${formulaEntry.key} on ${traceEntry.key}: '
                  'core=${coreResult.holds}, mtl=${mtlResult.holds}');
        });
      }
    }
  });

  group('Parity: Release and WeakUntil variants', () {
    final releaseFormulas = <String, Formula<int>>{
      'pTrue R pFalse': Release(pTrue, pFalse),
      'pFalse R pFalse': Release(pFalse, pFalse),
      'pTrue R pTrue': Release(pTrue, pTrue),
      'pPos R pEven': Release(pPos, pEven),
      'pFalse W pTrue': WeakUntil(pFalse, pTrue),
      'pTrue W pFalse': WeakUntil(pTrue, pFalse),
      'pEven W pZero': WeakUntil(pEven, pZero),
      'pOdd W pPos': WeakUntil(pOdd, pPos),
    };

    for (final traceEntry in traces.entries) {
      for (final formulaEntry in releaseFormulas.entries) {
        test('${formulaEntry.key} on ${traceEntry.key}', () {
          final trace = traceEntry.value;
          final formula = formulaEntry.value;

          final coreResult = evaluateTrace(trace, formula, startIndex: 0);
          final mtlResult =
              evaluateMtlTrace(trace, formula, startIndex: 0);

          expect(mtlResult.holds, equals(coreResult.holds),
              reason:
                  'Parity mismatch for ${formulaEntry.key} on ${traceEntry.key}: '
                  'core=${coreResult.holds}, mtl=${mtlResult.holds}');
        });
      }
    }
  });
}
