import 'package:meta/meta.dart';

/// Represents the outcome of evaluating a [Formula] against a [Trace].
///
/// This class encapsulates the result of checking if a temporal logic formula
/// holds true for a given sequence of timed events.
///
/// It contains not only whether the formula [holds] but also optional diagnostic
/// information like a failure [reason] and the specific time ([relatedTimestamp])
/// or index ([relatedIndex]) within the trace that is most pertinent to the result,
/// especially in case of failure.
///
/// This class is immutable.
@immutable
class EvaluationResult {
  /// `true` if the formula holds for the trace (or sub-trace beginning at the
  /// evaluated start index), `false` otherwise.
  final bool holds;

  /// An optional human-readable explanation for the evaluation outcome.
  ///
  /// This is particularly useful when [holds] is `false`, providing details about
  /// why the formula failed (e.g., which sub-formula failed at what point,
  /// or a boundary condition was met).
  ///
  /// Example: "Atomic proposition 'is_loading' failed", "Eventually failed: Operand never held."
  final String? reason;

  /// The timestamp within the trace that is most relevant to this result.
  ///
  /// For failures, this often indicates the timestamp of the [TraceEvent]
  /// where the violation occurred.
  /// For successes, its meaning might vary depending on the operator.
  final Duration? relatedTimestamp;

  /// The index within the trace's event list that is most relevant to this result.
  ///
  /// Similar to [relatedTimestamp], this often indicates the index of the
  /// [TraceEvent] where a failure occurred.
  final int? relatedIndex;

  /// Creates a detailed evaluation result.
  ///
  /// - [holds]: Whether the formula was satisfied.
  /// - [reason]: Optional explanation, especially for failures.
  /// - [relatedTimestamp]: Optional timestamp related to the outcome.
  /// - [relatedIndex]: Optional index related to the outcome.
  const EvaluationResult(this.holds,
      {this.reason, this.relatedTimestamp, this.relatedIndex});

  /// Creates a successful evaluation result (`holds` is `true`).
  /// Provides minimal information, suitable when only success/failure matters.
  const EvaluationResult.success() : this(true);

  /// Creates a failure evaluation result (`holds` is `false`).
  /// Requires a [reason] explaining the failure.
  /// Optionally includes [relatedTimestamp] and [relatedIndex] for context.
  const EvaluationResult.failure(String this.reason,
      {this.relatedTimestamp, this.relatedIndex})
      : holds = false;

  /// Provides a concise string representation of the result.
  /// Includes the reason and location (time/index) if available.
  /// Example: `EvaluationResult(holds: false: Always failed: Operand failed at 150ms)`
  @override
  String toString() {
    final details = reason != null ? ': $reason' : '';
    final timeInfo = relatedTimestamp != null
        ? ' at ${relatedTimestamp!.inMilliseconds}ms'
        : (relatedIndex != null ? ' at index $relatedIndex' : '');
    return 'EvaluationResult(holds: $holds$details$timeInfo)';
  }
}
