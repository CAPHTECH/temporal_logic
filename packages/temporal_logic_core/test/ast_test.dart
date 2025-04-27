import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:test/test.dart';

// Define a simple state type for testing
typedef TestState = ({bool p, bool q});

// Helper to create traces easily
Trace<TestState> createTrace(List<({bool p, bool q})> states) {
  return Trace.fromList(states);
}

void main() {
  group('AtomicProposition Evaluation Tests', () {
    // Predicate for p
    final p = AtomicProposition<TestState>((s) => s.p, name: 'p');
    // Predicate for q
    final q = AtomicProposition<TestState>((s) => s.q, name: 'q');

    test('evaluates correctly on standard trace', () {
      final trace = createTrace([
        (p: true, q: false),
        (p: false, q: true),
      ]);
      // p should be true at index 0
      expect(evaluateTrace(trace, p).holds, isTrue);
      // p should be false at index 1
      expect(evaluateTrace(trace, p, startIndex: 1).holds, isFalse);
      // q should be false at index 0
      expect(evaluateTrace(trace, q).holds, isFalse);
      // q should be true at index 1
      expect(evaluateTrace(trace, q, startIndex: 1).holds, isTrue);
    });

    test('returns failure when evaluating out of bounds', () {
      final trace = createTrace([(p: true, q: false)]);
      // Evaluating p at index 1 (out of bounds)
      expect(evaluateTrace(trace, p, startIndex: 1).holds, isFalse);
      expect(evaluateTrace(trace, p, startIndex: 1).reason,
          contains('evaluated past trace end'));
      // Evaluating p at index -1 (invalid)
      // evaluateTrace handles negative start index before calling _evaluateFormula
      // expect(evaluateTrace(trace, p, startIndex: -1).holds, isFalse);
    });

    test('evaluates correctly on empty trace', () {
      final trace = createTrace([]);
      // Evaluating p at index 0 on empty trace
      expect(evaluateTrace(trace, p).holds, isFalse);
      expect(
          evaluateTrace(trace, p).reason, contains('evaluated past trace end'));
    });
  });

  group('Boolean Connectives Evaluation Tests', () {
    final p = AtomicProposition<TestState>((s) => s.p, name: 'p');
    final q = AtomicProposition<TestState>((s) => s.q, name: 'q');
    final trace = createTrace([
      (p: true, q: false),
      (p: false, q: true),
      (p: true, q: true),
      (p: false, q: false),
    ]);

    test('NOT (!) evaluates correctly', () {
      final formula = Not(p);
      expect(evaluateTrace(trace, formula, startIndex: 0).holds,
          isFalse); // !p at index 0 is !true = false
      expect(evaluateTrace(trace, formula, startIndex: 1).holds,
          isTrue); // !p at index 1 is !false = true
    });

    test('AND (&&) evaluates correctly', () {
      final formula = And(p, q);
      expect(evaluateTrace(trace, formula, startIndex: 0).holds,
          isFalse); // p && q at 0 is true && false = false
      expect(evaluateTrace(trace, formula, startIndex: 1).holds,
          isFalse); // p && q at 1 is false && true = false
      expect(evaluateTrace(trace, formula, startIndex: 2).holds,
          isTrue); // p && q at 2 is true && true = true
      expect(evaluateTrace(trace, formula, startIndex: 3).holds,
          isFalse); // p && q at 3 is false && false = false
    });

    test('OR (||) evaluates correctly', () {
      final formula = Or(p, q);
      expect(evaluateTrace(trace, formula, startIndex: 0).holds,
          isTrue); // p || q at 0 is true || false = true
      expect(evaluateTrace(trace, formula, startIndex: 1).holds,
          isTrue); // p || q at 1 is false || true = true
      expect(evaluateTrace(trace, formula, startIndex: 2).holds,
          isTrue); // p || q at 2 is true || true = true
      expect(evaluateTrace(trace, formula, startIndex: 3).holds,
          isFalse); // p || q at 3 is false || false = false
    });

    test('IMPLIES (->) evaluates correctly', () {
      final formula = Implies(p, q);
      expect(evaluateTrace(trace, formula, startIndex: 0).holds,
          isFalse); // p -> q at 0 is true -> false = false
      expect(evaluateTrace(trace, formula, startIndex: 1).holds,
          isTrue); // p -> q at 1 is false -> true = true
      expect(evaluateTrace(trace, formula, startIndex: 2).holds,
          isTrue); // p -> q at 2 is true -> true = true
      expect(evaluateTrace(trace, formula, startIndex: 3).holds,
          isTrue); // p -> q at 3 is false -> false = true
    });
  });

  group('Temporal Operators Evaluation Tests', () {
    final p = AtomicProposition<TestState>((s) => s.p, name: 'p');
    final q = AtomicProposition<TestState>((s) => s.q, name: 'q');

    test('NEXT (X) evaluates correctly', () {
      final trace = createTrace([(p: false, q: false), (p: true, q: false)]);
      final formula = Next(p);
      expect(evaluateTrace(trace, formula, startIndex: 0).holds,
          isTrue); // X p at 0: p holds at 1
      expect(evaluateTrace(trace, formula, startIndex: 1).holds,
          isFalse); // X p at 1: No state at 2
      expect(evaluateTrace(trace, formula, startIndex: 1).reason,
          contains('Next evaluated past trace end'));
      expect(evaluateTrace(createTrace([]), formula).holds,
          isFalse); // X p on empty trace
      expect(evaluateTrace(createTrace([(p: true, q: false)]), formula).holds,
          isFalse); // X p on single state trace
    });

    test('ALWAYS (G) evaluates correctly', () {
      final formula = Always(p);
      expect(
          evaluateTrace(createTrace([(p: true, q: false), (p: true, q: true)]),
                  formula)
              .holds,
          isTrue);
      expect(
          evaluateTrace(createTrace([(p: true, q: false), (p: false, q: true)]),
                  formula)
              .holds,
          isFalse);
      expect(
          evaluateTrace(
                  createTrace([(p: false, q: false), (p: true, q: false)]),
                  formula)
              .holds,
          isFalse);
      expect(
          evaluateTrace(
                  createTrace([(p: false, q: false), (p: true, q: false)]),
                  formula)
              .reason,
          contains('failed'));
      expect(
          evaluateTrace(
                  createTrace([(p: false, q: false), (p: true, q: false)]),
                  formula)
              .relatedIndex,
          0);
      expect(
          evaluateTrace(createTrace([(p: false, q: false), (p: true, q: true)]),
                  formula)
              .holds,
          isFalse);
      expect(evaluateTrace(createTrace([]), formula).holds, isTrue);
      expect(evaluateTrace(createTrace([(p: true, q: false)]), formula).holds,
          isTrue);
      expect(evaluateTrace(createTrace([(p: false, q: false)]), formula).holds,
          isFalse);
    });

    test('EVENTUALLY (F) evaluates correctly', () {
      final formula = Eventually(p);
      expect(
          evaluateTrace(
                  createTrace([(p: false, q: false), (p: true, q: false)]),
                  formula)
              .holds,
          isTrue);
      expect(
          evaluateTrace(
                  createTrace([(p: true, q: false), (p: false, q: false)]),
                  formula)
              .holds,
          isTrue);
      expect(
          evaluateTrace(
                  createTrace([(p: false, q: false), (p: true, q: false)]),
                  formula,
                  startIndex: 1)
              .holds,
          isTrue);
      expect(
          evaluateTrace(
                  createTrace([(p: false, q: false), (p: false, q: true)]),
                  formula)
              .holds,
          isFalse);
      expect(
          evaluateTrace(
                  createTrace([(p: false, q: false), (p: false, q: true)]),
                  formula)
              .reason,
          contains('Operand never held'));
      expect(evaluateTrace(createTrace([]), formula).holds, isFalse);
      expect(evaluateTrace(createTrace([]), formula).reason,
          contains('Eventually evaluated on empty trace suffix'));
      expect(evaluateTrace(createTrace([(p: true, q: false)]), formula).holds,
          isTrue);
      expect(evaluateTrace(createTrace([(p: false, q: false)]), formula).holds,
          isFalse);
    });

    test('UNTIL (U) evaluates correctly', () {
      final formula = Until(p, q);
      expect(
          evaluateTrace(
                  createTrace([(p: false, q: true), (p: false, q: false)]),
                  formula)
              .holds,
          isTrue);
      expect(
          evaluateTrace(
                  createTrace([
                    (p: true, q: false),
                    (p: true, q: true),
                    (p: false, q: false)
                  ]),
                  formula)
              .holds,
          isTrue);
      expect(
          evaluateTrace(createTrace([(p: true, q: false), (p: true, q: true)]),
                  formula)
              .holds,
          isTrue);
      expect(
          evaluateTrace(createTrace([(p: true, q: false), (p: true, q: false)]),
                  formula)
              .holds,
          isFalse);
      expect(
          evaluateTrace(createTrace([(p: true, q: false), (p: true, q: false)]),
                  formula)
              .reason,
          contains('Right operand never held'));
      expect(
          evaluateTrace(
                  createTrace([
                    (p: true, q: false),
                    (p: false, q: false),
                    (p: true, q: true)
                  ]),
                  formula)
              .holds,
          isFalse);
      expect(
          evaluateTrace(
                  createTrace([
                    (p: true, q: false),
                    (p: false, q: false),
                    (p: true, q: true)
                  ]),
                  formula)
              .reason,
          contains('Left operand failed before right held'));
      expect(
          evaluateTrace(
                  createTrace([
                    (p: true, q: false),
                    (p: false, q: false),
                    (p: true, q: true)
                  ]),
                  formula)
              .relatedIndex,
          1);
      expect(evaluateTrace(createTrace([]), formula).holds, isFalse);
      expect(evaluateTrace(createTrace([(p: false, q: true)]), formula).holds,
          isTrue);
      expect(evaluateTrace(createTrace([(p: true, q: false)]), formula).holds,
          isFalse);
    });

    test('WEAK UNTIL (W) evaluates correctly', () {
      // p W q is equivalent to (p U q) || G p
      final formula = WeakUntil(p, q);
      final g_p = Always(p);
      final p_U_q = Until(p, q);

      final trace1 = createTrace([(p: false, q: true), (p: false, q: false)]);
      expect(evaluateTrace(trace1, formula).holds, isTrue,
          reason: "q holds immediately");
      expect(evaluateTrace(trace1, Or(p_U_q, g_p)).holds, isTrue);

      final trace2 = createTrace(
          [(p: true, q: false), (p: true, q: true), (p: false, q: false)]);
      expect(evaluateTrace(trace2, formula).holds, isTrue,
          reason: "p holds then q holds");
      expect(evaluateTrace(trace2, Or(p_U_q, g_p)).holds, isTrue);

      final trace3 = createTrace([(p: true, q: false), (p: true, q: false)]);
      expect(evaluateTrace(trace3, formula).holds, isTrue, reason: "G p holds");
      expect(evaluateTrace(trace3, Or(p_U_q, g_p)).holds, isTrue);

      final trace4 = createTrace(
          [(p: true, q: false), (p: false, q: false), (p: true, q: true)]);
      expect(evaluateTrace(trace4, formula).holds, isFalse,
          reason: "p fails before q holds");
      expect(evaluateTrace(trace4, Or(p_U_q, g_p)).holds, isFalse);

      final trace5 = createTrace([(p: true, q: false), (p: false, q: false)]);
      expect(evaluateTrace(trace5, formula).holds, isFalse,
          reason: "p fails, q never holds");
      expect(evaluateTrace(trace5, Or(p_U_q, g_p)).holds, isFalse);

      final trace6 = createTrace([]);
      expect(evaluateTrace(trace6, formula).holds, isTrue,
          reason: "Empty trace");
      expect(evaluateTrace(trace6, Or(p_U_q, g_p)).holds, isTrue);

      final trace7 = createTrace([(p: false, q: true)]);
      expect(evaluateTrace(trace7, formula).holds, isTrue,
          reason: "Single state q holds");
      expect(evaluateTrace(trace7, Or(p_U_q, g_p)).holds, isTrue);

      final trace8 = createTrace([(p: true, q: false)]);
      expect(evaluateTrace(trace8, formula).holds, isTrue,
          reason: "Single state p holds");
      expect(evaluateTrace(trace8, Or(p_U_q, g_p)).holds, isTrue);

      final trace9 = createTrace([(p: false, q: false)]);
      expect(evaluateTrace(trace9, formula).holds, isFalse,
          reason: "Single state p fails");
      expect(evaluateTrace(trace9, Or(p_U_q, g_p)).holds, isFalse);
    });

    test('RELEASE (R) evaluates correctly', () {
      // p R q is equivalent to !(!p U !q)
      final formula = Release(p, q);
      final not_p = Not(p);
      final not_q = Not(q);
      final notP_U_notQ = Until(not_p, not_q);

      final trace1 = createTrace([(p: false, q: true), (p: true, q: true)]);
      expect(evaluateTrace(trace1, formula).holds, isTrue, reason: "q until p");
      expect(evaluateTrace(trace1, Not(notP_U_notQ)).holds, isTrue);

      final trace2 = createTrace([(p: false, q: true), (p: false, q: true)]);
      expect(evaluateTrace(trace2, formula).holds, isTrue, reason: "G q holds");
      expect(evaluateTrace(trace2, Not(notP_U_notQ)).holds, isTrue);

      final trace3 = createTrace([(p: true, q: true)]);
      expect(evaluateTrace(trace3, formula).holds, isTrue,
          reason: "p holds immediately, q holds");
      expect(evaluateTrace(trace3, Not(notP_U_notQ)).holds, isTrue);

      final trace4 = createTrace([(p: true, q: false)]);
      expect(evaluateTrace(trace4, formula).holds, isFalse,
          reason: "p holds immediately, q fails");
      expect(evaluateTrace(trace4, Not(notP_U_notQ)).holds, isFalse);

      final trace5 = createTrace(
          [(p: false, q: true), (p: false, q: false), (p: true, q: true)]);
      expect(evaluateTrace(trace5, formula).holds, isFalse,
          reason: "q fails before p holds");
      expect(evaluateTrace(trace5, Not(notP_U_notQ)).holds, isFalse);

      final trace7 = createTrace([]);
      expect(evaluateTrace(trace7, formula).holds, isTrue,
          reason: "Empty trace");
      expect(evaluateTrace(trace7, Not(notP_U_notQ)).holds, isTrue);

      final trace8 = createTrace([(p: true, q: true)]); // Same as trace3
      expect(evaluateTrace(trace8, formula).holds, isTrue,
          reason: "Single p=T, q=T");
      expect(evaluateTrace(trace8, Not(notP_U_notQ)).holds, isTrue);

      final trace9 = createTrace([(p: false, q: true)]);
      expect(evaluateTrace(trace9, formula).holds, isTrue,
          reason: "Single p=F, q=T");
      expect(evaluateTrace(trace9, Not(notP_U_notQ)).holds, isTrue);

      final trace10 = createTrace([(p: false, q: false)]);
      expect(evaluateTrace(trace10, formula).holds, isFalse,
          reason: "Single p=F, q=F");
      expect(evaluateTrace(trace10, Not(notP_U_notQ)).holds, isFalse);

      final trace11 = createTrace([(p: true, q: false)]); // Same as trace4
      expect(evaluateTrace(trace11, formula).holds, isFalse,
          reason: "Single p=T, q=F");
      expect(evaluateTrace(trace11, Not(notP_U_notQ)).holds, isFalse);
    });
  });
}
