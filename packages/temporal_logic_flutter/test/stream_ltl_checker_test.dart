import 'dart:async';
import 'package:flutter/foundation.dart'; // Required for ValueNotifier
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart'; // Import fake_async
import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart';

// Define a simple state type for testing
class TestState {
  final bool p;
  TestState(this.p);
  @override
  String toString() => 'State(p=$p)';
}

void main() {
  group('LTL Stream Checker Tests', () {
    late StreamController<TestState> controller;
    late Formula<TestState> formula;

    // Helper to create an AtomicProposition for checking state.p
    Formula<TestState> pIs(bool value) => AtomicProposition<TestState>((s) => s.p == value, name: 'p==$value');

    setUp(() {
      controller = StreamController<TestState>();
    });

    tearDown(() {
      // Ensure controller is closed even if test fails
      if (!controller.isClosed) {
        controller.close();
      }
    });

    test('emits initial state evaluation after first interval if stream empty', () {
      fakeAsync((async) {
        formula = pIs(true);
        final checker = StreamLtlChecker<TestState>(
          stream: controller.stream,
          formula: formula,
          checkInterval: const Duration(milliseconds: 10), // Short interval
        );
        final results = <bool>[];
        final sub = checker.resultStream.listen(results.add);

        // Elapse time slightly longer than the check interval
        async.elapse(const Duration(milliseconds: 11));

        expect(results, [false]); // Should have emitted false due to timer

        sub.cancel();
        checker.dispose();
      });
    });

    test('emits correct result after first event using F p', () {
      fakeAsync((async) {
        // Use F p = Eventually(p is true)
        formula = Eventually(pIs(true)); 
        final checker = StreamLtlChecker<TestState>(
          stream: controller.stream,
          formula: formula,
          checkInterval: const Duration(days: 1), // Long interval
        );
        final results = <bool>[];
        final sub = checker.resultStream.listen(results.add);

        final state1 = TestState(false);
        final state2 = TestState(true);

        // Add first state (F)
        controller.add(state1);
        async.flushMicrotasks(); // Process the stream event
        // F p on [F] is false. Initial check should emit false.
        expect(results, [false]); 

        // Add second state (T)
        controller.add(state2);
        async.flushMicrotasks(); // Process the stream event
        // F p on [F, T] is true. Should emit true.
        expect(results, [false, true]); 

        sub.cancel();
        checker.dispose();
      });
    });

    test('emits only when result changes using F p', () {
      fakeAsync((async) {
        // Use F p = Eventually(p is true)
        formula = Eventually(pIs(true)); 
        final checker = StreamLtlChecker<TestState>(
          stream: controller.stream,
          formula: formula,
          checkInterval: const Duration(days: 1), // Long interval
        );

        final results = <bool>[];
        final sub = checker.resultStream.listen(results.add);

        // Add F -> F p is false
        controller.add(TestState(false));
        async.flushMicrotasks();
        expect(results, [false]);

        // Add F -> F p is still false
        controller.add(TestState(false));
        async.flushMicrotasks();
        expect(results, [false]); // No change

        // Add T -> F p becomes true
        controller.add(TestState(true));
        async.flushMicrotasks();
        expect(results, [false, true]);

        // Add T -> F p stays true
        controller.add(TestState(true));
        async.flushMicrotasks();
        expect(results, [false, true]); // No change

        sub.cancel();
        checker.dispose();
      });
    });

    test('evaluates G p correctly', () {
      fakeAsync((async) {
        final checkInterval = const Duration(days: 1); // Define for clarity
        formula = Always(pIs(true)); // G(p=T)
        final checker = StreamLtlChecker<TestState>(
          stream: controller.stream,
          formula: formula,
          checkInterval: checkInterval,
        );
        final results = <bool>[];
        final sub = checker.resultStream.listen(results.add);

        // Elapse enough time for the FIRST timer check to guarantee execution
        async.elapse(checkInterval);
        expect(results, [false], reason: "Initial check on empty trace (via timer) should be false");

        // Add first true state
        controller.add(TestState(true));
        async.flushMicrotasks(); // Process stream event
        // G(p=T) on [T] is true. Change from false -> true.
        expect(results, [false, true], reason: "After T, G(T) becomes true");

        // Add second true state
        controller.add(TestState(true));
        async.flushMicrotasks(); // Process stream event
        // G(p=T) on [T, T] is true. No change.
        expect(results, [false, true], reason: "After T, T, G(T) stays true");

        // Add false state
        controller.add(TestState(false));
        async.flushMicrotasks(); // Process stream event
        // G(p=T) on [T, T, F] is false. Change from true -> false.
        expect(results, [false, true, false], reason: "After T, T, F, G(T) becomes false");

        sub.cancel();
        checker.dispose();
      });
    });

    test('dispose stops notifications', () {
      fakeAsync((async) {
        formula = pIs(true);
        final checker = StreamLtlChecker<TestState>(
          stream: controller.stream,
          formula: formula,
          checkInterval: const Duration(milliseconds: 10), // Use interval
        );
        final results = <bool>[];
        final sub = checker.resultStream.listen(results.add);

        // Initial emit due to timer
        async.elapse(const Duration(milliseconds: 11));
        expect(results, [false]);

        // Add event
        controller.add(TestState(true));
        async.flushMicrotasks();
        expect(results, [false, true]);

        // Dispose
        checker.dispose();
        async.flushMicrotasks(); // Allow dispose cleanup

        // Add event after dispose
        controller.add(TestState(false));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1)); // Elapse time

        // Results should not have changed after dispose
        expect(results, [false, true]);

        sub.cancel(); // Technically sub is already cancelled by dispose
      });
    });
  });
} 
