import 'package:temporal_logic_core/temporal_logic_core.dart';

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
      final innerResult = _evaluateRecursive(trace, f.operand, index);
      return EvaluationResult(!innerResult.holds,
          reason:
              innerResult.holds ? 'Negated formula held' : innerResult.reason,
          relatedIndex: innerResult.relatedIndex,
          relatedTimestamp: innerResult.relatedTimestamp);

    case And<T> f:
      final leftResult = _evaluateRecursive(trace, f.left, index);
      if (!leftResult.holds) {
        return leftResult;
      }
      return _evaluateRecursive(trace, f.right, index);

    case Or<T> f:
      final leftResult = _evaluateRecursive(trace, f.left, index);
      if (leftResult.holds) {
        return leftResult;
      }
      return _evaluateRecursive(trace, f.right, index);

    case Implies<T> f:
      final leftResult = _evaluateRecursive(trace, f.left, index);
      if (!leftResult.holds) {
        return const EvaluationResult.success();
      }
      return _evaluateRecursive(trace, f.right, index);

    case Next<T> f:
      final nextIndex = index + 1;
      if (nextIndex >= trace.length) {
        return EvaluationResult.failure('Next evaluated past trace end.',
            relatedIndex: index);
      }
      return _evaluateRecursive(trace, f.operand, nextIndex);

    case Always<T> f:
      for (var k = index; k < trace.length; k++) {
        final stepResult = _evaluateRecursive(trace, f.operand, k);
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
        final stepResult = _evaluateRecursive(trace, f.operand, k);
        if (stepResult.holds) {
          return const EvaluationResult.success();
        }
      }
      return EvaluationResult.failure('Eventually failed: Operand never held.',
          relatedIndex: index,
          relatedTimestamp:
              trace.events.isNotEmpty ? trace.events[index].timestamp : null);

    case Until<T> f:
      if (index >= trace.length) {
        return EvaluationResult.failure(
            'Until evaluated on empty trace suffix.',
            relatedIndex: index);
      }
      for (var k = index; k < trace.length; k++) {
        final rightResult = _evaluateRecursive(trace, f.right, k);
        if (rightResult.holds) {
          for (var j = index; j < k; j++) {
            final leftResult = _evaluateRecursive(trace, f.left, j);
            if (!leftResult.holds) {
              return EvaluationResult.failure(
                  'Until failed: Left operand failed before right held (${leftResult.reason ?? "Left failed"})',
                  relatedIndex: j,
                  relatedTimestamp: trace.events[j].timestamp);
            }
          }
          return const EvaluationResult.success();
        }

        final leftResult = _evaluateRecursive(trace, f.left, k);
        if (!leftResult.holds) {
          return EvaluationResult.failure(
              'Until failed: Left operand failed before right held (${leftResult.reason ?? "Left failed"})',
              relatedIndex: k,
              relatedTimestamp: trace.events[k].timestamp);
        }
      }
      return EvaluationResult.failure('Until failed: Right operand never held.',
          relatedIndex: index,
          relatedTimestamp:
              trace.events.isNotEmpty ? trace.events[index].timestamp : null);

    case WeakUntil<T> f:
      final alwaysLeftResult =
          _evaluateRecursive(trace, Always<T>(f.left), index);
      if (alwaysLeftResult.holds) {
        return const EvaluationResult.success();
      }
      return _evaluateRecursive(trace, Until<T>(f.left, f.right), index);

    case Release<T> f:
      final notLeft = Not<T>(f.left);
      final notRight = Not<T>(f.right);
      final untilFormula = Until<T>(notLeft, notRight);
      final untilResult = _evaluateRecursive(trace, untilFormula, index);
      return EvaluationResult(!untilResult.holds,
          reason: untilResult.holds
              ? 'Release failed: !(${untilFormula}) held'
              : 'Release held: !(${untilFormula}) failed (${untilResult.reason ?? "reason unknown"})',
          relatedIndex: untilResult.relatedIndex,
          relatedTimestamp: untilResult.relatedTimestamp);

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
