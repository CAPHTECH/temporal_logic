import 'package:temporal_logic_core/temporal_logic_core.dart';

import 'time_interval.dart';

/// Legacy compatibility helpers for the historical MTL API.
///
/// Prefer [evaluateMtlTrace] with timed formulas from [mtl_operators.dart].
/// These helpers remain only so older call sites continue to work without a
/// breaking change.
///
/// They intentionally keep the original interval-scanning semantics and are
/// not the primary path for new code.

Duration? _traceStartTime<S>(Trace<S> trace) {
  if (trace.isEmpty) {
    return null;
  }
  return trace.events.first.timestamp;
}

/// [DEPRECATED: Use evaluateMtlTrace with EventuallyTimed formula]
/// Checks if [operand] holds eventually within [interval] for the given
/// timed [trace].
@Deprecated('Use evaluateMtlTrace with EventuallyTimed formula')
bool checkEventuallyWithin<S>(
    Trace<S> trace, TimeInterval interval, AtomicProposition<S> operand) {
  final startTime = _traceStartTime(trace);
  if (startTime == null) {
    return false;
  }

  for (var i = 0; i < trace.length; i++) {
    final currentTime = trace.events[i].timestamp;
    final timeOffset = currentTime - startTime;

    if (interval.contains(timeOffset) &&
        operand.predicate(trace.events[i].value)) {
      return true;
    }
    if (interval.exceedsUpperBound(timeOffset)) {
      break;
    }
  }
  return false;
}

/// [DEPRECATED: Use evaluateMtlTrace with AlwaysTimed formula]
/// Checks if [operand] holds at all points within [interval] for the given
/// timed [trace].
@Deprecated('Use evaluateMtlTrace with AlwaysTimed formula')
bool checkAlwaysWithin<S>(
    Trace<S> trace, TimeInterval interval, AtomicProposition<S> operand) {
  final startTime = _traceStartTime(trace);
  if (startTime == null) {
    return true;
  }

  for (var i = 0; i < trace.length; i++) {
    final currentEvent = trace.events[i];
    final timeOffset = currentEvent.timestamp - startTime;

    if (interval.contains(timeOffset) &&
        !operand.predicate(currentEvent.value)) {
      return false;
    }
    if (interval.exceedsUpperBound(timeOffset)) {
      break;
    }
  }
  return true;
}

/// [DEPRECATED: Use evaluateMtlTrace with UntilTimed formula]
/// Checks if [left] holds until [right] becomes true within [interval].
@Deprecated('Use evaluateMtlTrace with UntilTimed formula')
bool checkUntilWithin<S>(Trace<S> trace, TimeInterval interval,
    AtomicProposition<S> left, AtomicProposition<S> right) {
  final startTime = _traceStartTime(trace);
  if (startTime == null) {
    return false;
  }

  for (var k = 0; k < trace.length; k++) {
    final timeOffsetK = trace.events[k].timestamp - startTime;
    final stateK = trace.events[k].value;

    if (interval.contains(timeOffsetK) && right.predicate(stateK)) {
      var leftHeldPreviously = true;
      for (var j = 0; j < k; j++) {
        final stateJ = trace.events[j].value;
        if (!left.predicate(stateJ)) {
          leftHeldPreviously = false;
          break;
        }
      }

      if (leftHeldPreviously) {
        return true;
      }
    }

    if (interval.exceedsUpperBound(timeOffsetK)) {
      break;
    }
  }

  return false;
}
