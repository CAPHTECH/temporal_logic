/// Flutter specific utilities for Temporal Logic checking,
/// including Stream checkers, Widgets, and test matchers.
library temporal_logic_flutter;

// --- Core / MTL Exports (Re-exported for convenience) ---
// Export necessary types/functions from core and mtl packages
export 'package:temporal_logic_core/temporal_logic_core.dart' 
  show 
    Formula, Trace, TraceEvent, TimedValue, EvaluationResult, 
    AtomicProposition, Not, And, Or, Implies, Next, Always, Eventually, Until,
    WeakUntil, Release,
    state, event, next, always, eventually, until, weakUntil, release,
    LogicalConnectives;

export 'package:temporal_logic_mtl/temporal_logic_mtl.dart'
  show 
    TimeInterval, evaluateMtlTrace, 
    EventuallyTimed, AlwaysTimed, UntilTimed;
    // Also exports EvaluationResult, Trace, etc. implicitly from core export

// --- Flutter Specific Components ---

// Stream Checkers
export 'src/stream_ltl_checker.dart';
export 'src/stream_mtl_checker.dart';
export 'src/stream_sustained_state_checker.dart';
export 'src/check_status.dart'; // Export the new status enum

// Widgets
export 'src/ltl_checker_widget.dart';
export 'src/sustained_state_checker_widget.dart';
export 'src/mtl_checker_widget.dart'; // Export the new MTL widget

// Test Matchers
export 'src/matchers.dart';

// Trace Recorder
export 'src/trace_recorder.dart';

// --- Removed Helpers ---
// export 'src/ltl_helpers.dart'; // Removed, use exports from core
