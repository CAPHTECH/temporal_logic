library temporal_logic_core;

// Export the AST definitions (Formula, AtomicProposition, Operators)
export 'src/ast.dart';

// Export the Builder DSL functions (state, event, next, always, etc.)
export 'src/builder.dart';

// Export Timed Value and Trace classes
export 'src/timed_value.dart';

// Export Evaluation Logic (evaluateTrace, EvaluationResult)
export 'src/evaluator.dart';

// Later, export other parts like evaluators, etc.
// export 'src/evaluator.dart';
