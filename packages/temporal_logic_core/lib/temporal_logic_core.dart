/// Stable public entry point for `temporal_logic_core`.
///
/// Application code should import this library instead of files under `src/`.
/// Files in `src/` are implementation details and may change during refactoring.
library temporal_logic_core;

// Export the AST definitions (Formula, AtomicProposition, Operators).
export 'src/ast.dart';

// Export the Builder DSL functions (state, event, next, always, etc.).
export 'src/builder.dart';

// Export trace-related value types.
export 'src/timed_value.dart';

// Export EvaluationResult as a stable public type.
export 'src/evaluation_result.dart';

// Export evaluation entry points.
export 'src/evaluator.dart';
