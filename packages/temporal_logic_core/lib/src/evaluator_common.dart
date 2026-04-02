import 'ast.dart';
import 'evaluation_result.dart';
import 'timed_value.dart';

typedef RecursiveFormulaEvaluator<T> = EvaluationResult Function(
    Formula<T> formula, int index);

EvaluationResult? evaluateCoreFormula<T>(
  Trace<T> trace,
  Formula<T> formula,
  int index,
  RecursiveFormulaEvaluator<T> evaluate,
) {
  switch (formula) {
    case AtomicProposition<T> p:
      if (index >= trace.length) {
        return EvaluationResult.failure(
            'Atomic proposition evaluated past trace end.',
            relatedIndex: index);
      }
      final currentEvent = trace.events[index];
      final holds = p.predicate(currentEvent.value);
      return EvaluationResult(holds,
          reason: !holds ? '${p.name ?? "Atomic"} failed' : null,
          relatedIndex: index,
          relatedTimestamp: currentEvent.timestamp);

    case Not<T> f:
      final innerResult = evaluate(f.operand, index);
      return EvaluationResult(!innerResult.holds,
          reason:
              innerResult.holds ? 'Negated formula held' : innerResult.reason,
          relatedIndex: innerResult.relatedIndex,
          relatedTimestamp: innerResult.relatedTimestamp);

    case And<T> f:
      final leftResult = evaluate(f.left, index);
      if (!leftResult.holds) {
        return leftResult;
      }
      return evaluate(f.right, index);

    case Or<T> f:
      final leftResult = evaluate(f.left, index);
      if (leftResult.holds) {
        return const EvaluationResult.success();
      }
      final rightResult = evaluate(f.right, index);
      if (rightResult.holds) {
        return const EvaluationResult.success();
      }
      return EvaluationResult.failure(
          'Both sides of OR failed (${leftResult.reason ?? 'Left'}, ${rightResult.reason ?? 'Right'})',
          relatedIndex: index);

    case Implies<T> f:
      final leftResult = evaluate(f.left, index);
      if (!leftResult.holds) {
        return const EvaluationResult.success();
      }
      final rightResult = evaluate(f.right, index);
      if (!rightResult.holds) {
        return EvaluationResult.failure(
            'Antecedent held but consequent failed: ${rightResult.reason ?? "Consequent eval failed"}',
            relatedIndex: rightResult.relatedIndex,
            relatedTimestamp: rightResult.relatedTimestamp);
      }
      return const EvaluationResult.success();

    case Next<T> f:
      final nextIndex = index + 1;
      if (nextIndex >= trace.length) {
        return EvaluationResult.failure('Next evaluated past trace end.',
            relatedIndex: index);
      }
      return evaluate(f.operand, nextIndex);

    case Always<T> f:
      for (var k = index; k < trace.length; k++) {
        final stepResult = evaluate(f.operand, k);
        if (!stepResult.holds) {
          return EvaluationResult.failure(
              'Always failed: ${stepResult.reason ?? "Operand failed"}',
              relatedIndex: k,
              relatedTimestamp: trace.events[k].timestamp);
        }
      }
      return const EvaluationResult.success();

    case Eventually<T> f:
      if (index >= trace.length) {
        return EvaluationResult.failure(
            'Eventually evaluated on empty trace suffix.',
            relatedIndex: index);
      }
      for (var k = index; k < trace.length; k++) {
        final stepResult = evaluate(f.operand, k);
        if (stepResult.holds) {
          return const EvaluationResult.success();
        }
      }
      return EvaluationResult.failure('Eventually failed: Operand never held.',
          relatedIndex: index);

    case Until<T> f:
      if (index >= trace.length) {
        return EvaluationResult.failure(
            'Until evaluated on empty trace suffix.',
            relatedIndex: index);
      }
      for (var k = index; k < trace.length; k++) {
        final rightResult = evaluate(f.right, k);
        if (rightResult.holds) {
          for (var j = index; j < k; j++) {
            final leftResult = evaluate(f.left, j);
            if (!leftResult.holds) {
              return EvaluationResult.failure(
                  'Until failed: Left operand failed before right held (${leftResult.reason ?? "Left failed"})',
                  relatedIndex: j,
                  relatedTimestamp: trace.events[j].timestamp);
            }
          }
          return const EvaluationResult.success();
        }
        final leftResult = evaluate(f.left, k);
        if (!leftResult.holds) {
          return EvaluationResult.failure(
              'Until failed: Left operand failed before right held (${leftResult.reason ?? "Left failed"})',
              relatedIndex: k,
              relatedTimestamp: trace.events[k].timestamp);
        }
      }
      return EvaluationResult.failure('Until failed: Right operand never held.',
          relatedIndex: index);

    case WeakUntil<T> f:
      return evaluate(
          Or<T>(Always<T>(f.left), Until<T>(f.left, f.right)), index);

    case Release<T> f:
      return evaluate(Not<T>(Until<T>(Not<T>(f.left), Not<T>(f.right))), index);

    default:
      return null;
  }
}
