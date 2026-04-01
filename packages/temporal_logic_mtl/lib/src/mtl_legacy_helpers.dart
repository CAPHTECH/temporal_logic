import 'package:temporal_logic_core/temporal_logic_core.dart';

import 'time_interval.dart';

/// [DEPRECATED: Use evaluateMtlTrace] Checks if the formula [operand] holds eventually within the [interval]
/// for the given timed [trace].
///
/// Checks if operand [phi] becomes true at some point within the [interval]
/// relative to the start of the [trace]. (F_I phi)
@Deprecated('Use evaluateMtlTrace with EventuallyTimed formula')
bool checkEventuallyWithin<S>(
    Trace<S> trace, TimeInterval interval, AtomicProposition<S> operand) {
  if (trace.isEmpty) {
    return false;
  }
  final startTime = trace.events.first.timestamp;

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

/// [DEPRECATED: Use evaluateMtlTrace] Checks if operand [phi] holds true at all points within the [interval]
/// relative to the start of the [trace]. (G_I phi)
@Deprecated('Use evaluateMtlTrace with AlwaysTimed formula')
bool checkAlwaysWithin<S>(
    Trace<S> trace, TimeInterval interval, AtomicProposition<S> operand) {
  if (trace.isEmpty) {
    return true;
  }
  final startTime = trace.events.first.timestamp;

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

/// [DEPRECATED: Use evaluateMtlTrace] Checks if [left] holds true until [right] becomes true within the [interval]
/// relative to the start of the [trace]. (phi U_I psi)
///
/// Semantics: Exists time `t` in `interval` such that `right` holds at `t`,
/// AND for all times `t'` from start (0) up to `t`, `left` holds at `t'`.
/// Note: The interval applies ONLY to the point where `right` must hold.
/// The `left` condition applies from the beginning of the trace up to that point.
@Deprecated('Use evaluateMtlTrace with UntilTimed formula')
bool checkUntilWithin<S>(Trace<S> trace, TimeInterval interval,
    AtomicProposition<S> left, AtomicProposition<S> right) {
  if (trace.isEmpty) {
    return false;
  }
  final startTime = trace.events.first.timestamp;

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
