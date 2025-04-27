import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_flutter/src/matchers.dart';
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart'; // Ensure evaluateTrace is available

// Simple state class for testing
class TestState {
  final bool value;
  TestState(this.value);

  @override
  String toString() => 'TestState($value)';
}

void main() {
  group('satisfiesLtl Matcher', () {
    test('matches when formula holds for Trace', () {
      final trace = Trace<TestState>([
        TraceEvent(value: TestState(true), timestamp: const Duration(seconds: 1)),
        TraceEvent(value: TestState(true), timestamp: const Duration(seconds: 2)),
      ]);
      final formula = always(state<TestState>((s) => s.value));

      expect(trace, satisfiesLtl(formula));
    });

    test('does not match when formula fails for Trace', () {
      final trace = Trace<TestState>([
        TraceEvent(value: TestState(true), timestamp: const Duration(seconds: 1)),
        TraceEvent(value: TestState(false), timestamp: const Duration(seconds: 2)), // Fails here
      ]);
      final formula = always(state<TestState>((s) => s.value));

      expect(trace, isNot(satisfiesLtl(formula)));
    });

    test('matches when formula holds for List', () {
      final list = [TestState(true), TestState(true)];
      final formula = always(state<TestState>((s) => s.value));

      expect(list, satisfiesLtl(formula));
    });

    test('does not match when formula fails for List', () {
      final list = [TestState(true), TestState(false)]; // Fails here
      final formula = always(state<TestState>((s) => s.value));

      expect(list, isNot(satisfiesLtl(formula)));
    });

    test('does not match for incorrect item type', () {
      const item = 123;
      final formula = always(state<TestState>((s) => s.value));

      expect(item, isNot(satisfiesLtl<TestState>(formula)));
    });

    test('provides informative description', () {
      final formula = eventually(state<TestState>((s) => s.value));
      final matcher = satisfiesLtl(formula);
      final description = StringDescription();
      matcher.describe(description);
      expect(description.toString(), contains('satisfies temporal logic formula'));
      expect(description.toString(), contains('Eventually<TestState>'));
    });

    test('provides mismatch description on failure', () {
      final trace = Trace<TestState>([
        TraceEvent(value: TestState(false), timestamp: const Duration(seconds: 1)),
        TraceEvent(value: TestState(false), timestamp: const Duration(seconds: 2)),
      ]);
      final formula = always(state<TestState>((s) => s.value)); // Expects true always
      final matcher = satisfiesLtl(formula);
      final mismatchDescription = StringDescription();
      final matchState = <dynamic, dynamic>{};

      final result = matcher.matches(trace, matchState);
      expect(result, isFalse); // Evaluation should fail

      matcher.describeMismatch(trace, mismatchDescription, matchState, false);
      expect(mismatchDescription.toString(), contains('evaluation resulted in false'));
      expect(mismatchDescription.toString(), contains('Always failed'));
    });

    test('provides mismatch description for wrong type', () {
      const item = 'not a trace';
      final formula = always(state<TestState>((s) => s.value));
      final matcher = satisfiesLtl<TestState>(formula);
      final mismatchDescription = StringDescription();
      final matchState = <dynamic, dynamic>{};

      matcher.matches(item, matchState);
      matcher.describeMismatch(item, mismatchDescription, matchState, false);

      expect(
        mismatchDescription.toString(),
        contains('was type String but expected a Trace<TestState> or List<TestState>.'),
      );
    });

    test('provides mismatch description on evaluation exception', () {
      final trace = Trace<TestState>([]); // Empty trace might cause issues depending on formula/evaluator
      final formula = next(state<TestState>((s) => s.value)); // `next` might fail on empty/short trace
      final matcher = satisfiesLtl(formula);
      final mismatchDescription = StringDescription();
      final matchState = <dynamic, dynamic>{};

      // We rely on the matcher catching the exception from evaluateTrace
      final result = matcher.matches(trace, matchState);
      expect(result, isFalse); // Evaluation should fail

      // Check the mismatch description for the failure reason
      matcher.describeMismatch(trace, mismatchDescription, matchState, false);
      expect(mismatchDescription.toString(), contains('evaluation resulted in false'));
      expect(mismatchDescription.toString(), contains('Next evaluated past trace end.'));
    });
  });
}
