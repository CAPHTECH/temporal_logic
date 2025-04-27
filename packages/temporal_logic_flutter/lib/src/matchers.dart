import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart'; // Assuming evaluateTrace and EvaluationResult exist

/// A matcher that checks if a [Trace] satisfies a given [Formula].
///
/// This matcher uses the underlying evaluation logic from the core
/// or MTL packages to determine if the temporal property holds true
/// for the sequence of events in the trace.
///
/// Example:
/// ```dart
/// final trace = recorder.trace;
/// final formula = state<MyState>((s) => s.isReady).always();
/// expect(trace, satisfiesLtl(formula));
/// ```
Matcher satisfiesLtl<T>(Formula<T> formula) {
  return _SatisfiesLtlMatcher<T>(formula);
}

class _SatisfiesLtlMatcher<T> extends Matcher {
  final Formula<T> formula;

  _SatisfiesLtlMatcher(this.formula);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is Trace<T>) {
      try {
        // Use the MTL evaluation function, which should handle both
        // timed (MTL) and untimed (LTL) traces/formulas appropriately.
        final result = evaluateTrace<T>(item, formula);
        matchState['evaluationResult'] = result;
        matchState['traceLength'] = item.events.length;
        return result.holds;
      } catch (e, stackTrace) {
        matchState['exception'] = e;
        matchState['stackTrace'] = stackTrace;
        return false;
      }
    } else if (item is List<T>) {
      // Support plain lists as simple traces (index = time)
      try {
        final trace = Trace.fromList(item);
        final result = evaluateTrace<T>(trace, formula);
        matchState['evaluationResult'] = result;
        matchState['traceLength'] = item.length;
        return result.holds;
      } catch (e, stackTrace) {
        matchState['exception'] = e;
        matchState['stackTrace'] = stackTrace;
        return false;
      }
    }
    // Add support for Stream<T> if needed, potentially requiring async matching

    matchState['itemType'] = item.runtimeType.toString();
    return false; // Does not match if item is not a Trace<T> or List<T>
  }

  @override
  Description describe(Description description) {
    return description
        .add('satisfies temporal logic formula\n  Formula: ')
        .addDescriptionOf(formula);
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('exception')) {
      mismatchDescription
          .add('threw an exception during evaluation:\n')
          .addDescriptionOf(matchState['exception'])
          .add('\nStack trace:\n')
          .addDescriptionOf(matchState['stackTrace']);
    } else if (matchState.containsKey('evaluationResult')) {
      final result = matchState['evaluationResult'] as EvaluationResult;
      mismatchDescription
          .add('evaluation resulted in ${result.holds ? 'true' : 'false'}\n');
      if (!result.holds && result.reason != null) {
        mismatchDescription.add('Reason: ${result.reason}\n');
      }
      if (verbose && matchState.containsKey('traceLength')) {
        mismatchDescription.add(
            'Evaluated on trace of length ${matchState['traceLength']}.\n');
        // Potentially add more trace details if EvaluationResult provides them
      }
    } else if (matchState.containsKey('itemType')) {
      mismatchDescription
          .add('was type ')
          .add(matchState['itemType'])
          .add(' but expected a Trace<$T> or List<$T>.');
    } else {
      mismatchDescription.add('did not match for an unknown reason.');
    }
    return mismatchDescription;
  }
}
