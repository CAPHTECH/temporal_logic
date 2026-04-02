import 'package:meta/meta.dart';

import 'formula_stream_checker_base.dart';
import 'stream_evaluation_start.dart';

/// Shared trace accumulation and evaluation pre-processing for stream checkers.
@internal
typedef TraceSnapshotBuilder<TraceEntry, TraceType> = TraceType Function(
    List<TraceEntry> entries);

@internal
abstract class StreamTraceCheckerBase<Input, TraceEntry, TraceType, Result>
    extends FormulaStreamCheckerBase<Input, Result> {
  StreamTraceCheckerBase(
    super.stream, {
    required this.evaluationStart,
    required this.buildTraceSnapshot,
    TraceEntry? initialEntry,
  }) {
    if (initialEntry != null) {
      _trace.add(initialEntry);
    }
  }

  final StreamEvaluationStart evaluationStart;
  final TraceSnapshotBuilder<TraceEntry, TraceType> buildTraceSnapshot;
  final List<TraceEntry> _trace = [];

  @protected
  void appendTraceEntry(TraceEntry entry) {
    _trace.add(entry);
  }

  @protected
  int resolveStartIndex() {
    return evaluationStart.resolveStartIndex(_trace.length);
  }

  @protected
  bool get isTraceEmpty => _trace.isEmpty;

  @protected
  void clearTrace() {
    _trace.clear();
  }

  @protected
  TraceType buildCurrentTrace() {
    return buildTraceSnapshot(_trace);
  }

  @override
  void dispose() {
    clearTrace();
    super.dispose();
  }
}
