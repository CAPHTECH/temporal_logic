import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_core/internal/evaluator_common.dart';

import 'mtl_ast.dart';

/// Evaluates a temporal logic [formula] (potentially including both LTL and MTL
/// operators) against a given timed [trace], starting from [startIndex].
///
/// This function serves as the primary entry point for checking specifications
/// involving time. It handles both standard LTL operators (from `temporal_logic_core`)
/// and MTL operators (like [EventuallyTimed], [AlwaysTimed], [UntilTimed])
/// defined in this library.
///
/// Evaluation starts at the given [startIndex] of the trace (defaults to 0).
/// Temporal operators consider the suffix of the trace starting from this index,
/// taking into account the timestamps of events for MTL operators.
EvaluationResult evaluateMtlTrace<T>(Trace<T> trace, Formula<T> formula,
    {int startIndex = 0}) {
  if (startIndex < 0 || startIndex > trace.length) {
    return EvaluationResult.failure(
        'Start index $startIndex out of bounds for trace length ${trace.length}');
  }

  return _evaluateRecursive(trace, formula, startIndex);
}

EvaluationResult _evaluateRecursive<T>(
    Trace<T> trace, Formula<T> formula, int index) {
  Duration? currentIndexTimestamp;
  if (index < trace.length) {
    currentIndexTimestamp = trace.events[index].timestamp;
  }

  final coreResult = evaluateCoreFormula(
    trace,
    formula,
    index,
    (nestedFormula, nestedIndex) =>
        _evaluateRecursive(trace, nestedFormula, nestedIndex),
  );
  if (coreResult != null) {
    return coreResult;
  }

  switch (formula) {
    case EventuallyTimed<T> f:
      if (currentIndexTimestamp == null) {
        return EvaluationResult.failure(
            'EventuallyTimed evaluated past trace end.',
            relatedIndex: index);
      }
      for (var k = index; k < trace.length; k++) {
        final timeDiff = trace.events[k].timestamp - currentIndexTimestamp;
        if (f.interval.exceedsUpperBound(timeDiff)) {
          break;
        }

        if (f.interval.contains(timeDiff)) {
          final stepResult = _evaluateRecursive(trace, f.operand, k);
          if (stepResult.holds) {
            return const EvaluationResult.success();
          }
        }
      }
      return EvaluationResult.failure(
          'EventuallyTimed failed: Operand never held within interval ${f.interval}.',
          relatedIndex: index,
          relatedTimestamp: currentIndexTimestamp);

    case AlwaysTimed<T> f:
      if (currentIndexTimestamp == null) {
        return const EvaluationResult.success();
      }
      for (var k = index; k < trace.length; k++) {
        final timeDiff = trace.events[k].timestamp - currentIndexTimestamp;
        if (f.interval.exceedsUpperBound(timeDiff)) {
          break;
        }

        if (f.interval.contains(timeDiff)) {
          final stepResult = _evaluateRecursive(trace, f.operand, k);
          if (!stepResult.holds) {
            return EvaluationResult.failure(
                'AlwaysTimed failed: ${stepResult.reason ?? "Operand failed"} within interval ${f.interval}.',
                relatedIndex: k,
                relatedTimestamp: trace.events[k].timestamp);
          }
        }
      }
      return const EvaluationResult.success();

    case UntilTimed<T> f:
      if (currentIndexTimestamp == null) {
        return EvaluationResult.failure('UntilTimed evaluated past trace end.',
            relatedIndex: index);
      }
      for (var k = index; k < trace.length; k++) {
        final timeDiff = trace.events[k].timestamp - currentIndexTimestamp;

        if (f.interval.contains(timeDiff)) {
          final rightResult = _evaluateRecursive(trace, f.right, k);
          if (rightResult.holds) {
            for (var j = index; j < k; j++) {
              final leftResult = _evaluateRecursive(trace, f.left, j);
              if (!leftResult.holds) {
                return EvaluationResult.failure(
                    'UntilTimed failed: Left operand failed before right held within interval ${f.interval} (${leftResult.reason ?? "Left failed"}).',
                    relatedIndex: j,
                    relatedTimestamp: trace.events[j].timestamp);
              }
            }
            return const EvaluationResult.success();
          }
        }

        if (f.interval.exceedsUpperBound(timeDiff)) {
          break;
        }

        final leftResult = _evaluateRecursive(trace, f.left, k);
        if (!leftResult.holds) {
          return EvaluationResult.failure(
              'UntilTimed failed: Left operand failed before right held within interval ${f.interval} (${leftResult.reason ?? "Left failed"}).',
              relatedIndex: k,
              relatedTimestamp: trace.events[k].timestamp);
        }
      }

      return EvaluationResult.failure(
          'UntilTimed failed: Right operand never held within interval ${f.interval}.',
          relatedIndex: index,
          relatedTimestamp: currentIndexTimestamp);

    case ReleaseTimed<T> f:
      final notLeft = Not<T>(f.left);
      final notRight = Not<T>(f.right);
      final untilNotLeftNotRight = UntilTimed<T>(notLeft, notRight, f.interval);
      final evalUntil = _evaluateRecursive(trace, untilNotLeftNotRight, index);
      return EvaluationResult(!evalUntil.holds,
          reason: evalUntil.holds
              ? 'ReleaseTimed failed: Corresponding ¬(${f.left}) U_${f.interval} ¬(${f.right}) held'
              : null,
          relatedIndex: evalUntil.relatedIndex,
          relatedTimestamp: evalUntil.relatedTimestamp);

    case WeakUntilTimed<T> f:
      final alwaysLeft = AlwaysTimed<T>(f.left, f.interval);
      final alwaysResult = _evaluateRecursive(trace, alwaysLeft, index);
      if (alwaysResult.holds) {
        return const EvaluationResult.success();
      }

      final untilLeftRight = UntilTimed<T>(f.left, f.right, f.interval);
      return _evaluateRecursive(trace, untilLeftRight, index);

    default:
      return EvaluationResult.failure(
          'Unsupported formula type encountered: ${formula.runtimeType}');
  }
}
