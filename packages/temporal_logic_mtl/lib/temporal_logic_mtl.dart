/// Support for Metric Temporal Logic (MTL) evaluation on timed traces.
///
/// Stable public entry point for `temporal_logic_mtl`.
/// Application code should import this library instead of files under `src/`.
/// Files in `src/` are implementation details and may change during refactoring.
library temporal_logic_mtl;

// This library extends temporal_logic_core with Metric Temporal Logic (MTL)
// features, specifically timed operators and evaluation over TimedTrace.

// Re-export core concepts for convenience
export 'package:temporal_logic_core/temporal_logic_core.dart'
    show
        // Core Types
        Formula,
        Trace,
        TraceEvent,
        TimedValue,
        EvaluationResult,
        // AST Nodes
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
        // Builder Functions
        state,
        event,
        next,
        always,
        eventually,
        until,
        weakUntil,
        release;

// Core data structures
// REMOVED export 'src/timed_value.dart'; // TimedValue comes from core package

// Note: We might need a timed version of TraceRecorder from temporal_logic_flutter,
// or users will need to construct TimedTrace manually or use fake_async.
// For now, we don't export a recorder from here.

export 'src/mtl_evaluator.dart'
    show
        evaluateMtlTrace; // New primary evaluator
export 'src/mtl_ast.dart'
    show
        EventuallyTimed, // Timed AST node
        AlwaysTimed, // Timed AST node
        UntilTimed, // Timed AST node
        ReleaseTimed, // Timed AST node
        WeakUntilTimed; // Timed AST node

// Do not export the test matcher from the library
// export 'src/mtl_matchers.dart';

// Extensions - Extensions are implicitly available

// Export MTL specific components.
export 'src/time_interval.dart';
