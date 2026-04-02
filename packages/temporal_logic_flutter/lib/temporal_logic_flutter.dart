/// Flutter specific utilities for Temporal Logic checking,
/// including Stream checkers, Widgets, and test matchers.
///
/// Stable public entry point for `temporal_logic_flutter`.
/// Flutter applications should import this library instead of files under `src/`.
/// The exported surface is intentionally curated and guarded by export tests.
library temporal_logic_flutter;

export 'package:temporal_logic_core/temporal_logic_core.dart'
    show
        Formula,
        Trace,
        TraceEvent,
        TimedValue,
        EvaluationResult,
        AtomicProposition,
        Not,
        And,
        Or,
        Implies,
        Next,
        Always,
        Eventually,
        Until,
        WeakUntil,
        Release,
        state,
        event,
        next,
        always,
        eventually,
        until,
        weakUntil,
        release;
export 'package:temporal_logic_mtl/temporal_logic_mtl.dart'
    show
        TimeInterval,
        evaluateMtlTrace,
        EventuallyTimed,
        AlwaysTimed,
        UntilTimed,
        ReleaseTimed,
        WeakUntilTimed;

export 'src/check_status.dart';
export 'src/stream_evaluation_start.dart';
export 'src/ltl_checker_widget.dart';
export 'src/mtl_checker_widget.dart';
export 'src/stream_ltl_checker.dart';
export 'src/stream_mtl_checker.dart';
export 'src/stream_sustained_state_checker.dart';
export 'src/sustained_state_checker_widget.dart';
export 'src/trace_recorder.dart';
