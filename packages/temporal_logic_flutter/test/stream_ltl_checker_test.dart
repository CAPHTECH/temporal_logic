import 'dart:async';

import 'package:fake_async/fake_async.dart'; // Import fake_async
import 'package:flutter_test/flutter_test.dart';
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
    late StreamLtlChecker<TestState> checker;

    // Helper to create an AtomicProposition for checking state.p
    Formula<TestState> pIs(bool value) => AtomicProposition<TestState>((s) => s.p == value, name: 'p==$value');

    setUp(() {
      controller = StreamController<TestState>();
    });

    tearDown(() {
      // Dispose the checker after each test
      checker.dispose();
      // Ensure controller is closed even if test fails
      if (!controller.isClosed) {
        controller.close();
      }
    });

    test('emits initial false evaluation immediately if stream empty and no initialValue', () {
      fakeAsync((async) {
        formula = pIs(true); // Check if p is true
        checker = StreamLtlChecker<TestState>(
          stream: controller.stream,
          formula: formula,
        );
        final results = <bool>[];
        final sub = checker.resultStream.listen(results.add);

        // Process microtasks to allow initial emission
        async.flushMicrotasks();

        expect(results, [false], reason: "Initial check on empty trace should be false");

        sub.cancel();
      });
    });

    test('emits initial evaluation based on initialValue', () {
      fakeAsync((async) {
        formula = pIs(true); // Check if p is true
        checker = StreamLtlChecker<TestState>(
          stream: controller.stream,
          formula: formula,
          initialValue: TestState(true), // Initial state where p is true
        );
        final results = <bool>[];
        final sub = checker.resultStream.listen(results.add);

        // Process microtasks to allow initial emission
        async.flushMicrotasks();

        expect(results, [true], reason: "Initial check with initialValue(p=true) should be true");

        // Add a new state where p is false
        controller.add(TestState(false));
        async.flushMicrotasks();

        // Formula pIs(true) on trace [T, F] is false
        expect(results, [true, false], reason: "After adding F, pIs(true) becomes false");

        sub.cancel();
      });
    });

    test('emits result on every event using F p', () {
      fakeAsync((async) {
        // Use F p = Eventually(p is true)
        formula = Eventually(pIs(true));
        checker = StreamLtlChecker<TestState>(
          stream: controller.stream,
          formula: formula,
        );
        final results = <bool>[];
        final sub = checker.resultStream.listen(results.add);

        // Initial check (empty trace)
        async.flushMicrotasks();
        expect(results, [false], reason: "Initial F p on empty trace is false");

        final state1 = TestState(false);
        final state2 = TestState(true);

        // Add first state (F)
        controller.add(state1);
        async.flushMicrotasks(); // Process the stream event
        // F p on [F] is false.
        expect(results, [false, false], reason: "After F, F p is false");

        // Add second state (T)
        controller.add(state2);
        async.flushMicrotasks(); // Process the stream event
        // F p on [F, T] is true. Should emit true.
        expect(results, [false, false, true], reason: "After T, F p becomes true");

        sub.cancel();
      });
    });

    test('emits on every event even if result does not change (using F p)', () {
      fakeAsync((async) {
        // Use F p = Eventually(p is true)
        formula = Eventually(pIs(true));
        checker = StreamLtlChecker<TestState>(
          stream: controller.stream,
          formula: formula,
        );

        final results = <bool>[];
        final sub = checker.resultStream.listen(results.add);

        // Initial
        async.flushMicrotasks();
        expect(results, [false]);

        // Add F -> F p is false
        controller.add(TestState(false));
        async.flushMicrotasks();
        expect(results, [false, false]);

        // Add F -> F p is still false
        controller.add(TestState(false));
        async.flushMicrotasks();
        expect(results, [false, false, false]); // Emits again

        // Add T -> F p becomes true
        controller.add(TestState(true));
        async.flushMicrotasks();
        expect(results, [false, false, false, true]);

        // Add T -> F p stays true
        controller.add(TestState(true));
        async.flushMicrotasks();
        expect(results, [false, false, false, true, true]); // Emits again

        sub.cancel();
      });
    });

    test('evaluates G p correctly', () {
      fakeAsync((async) {
        formula = Always(pIs(true)); // G(p=T)
        checker = StreamLtlChecker<TestState>(
          stream: controller.stream,
          formula: formula,
        );
        final results = <bool>[];
        final sub = checker.resultStream.listen(results.add);

        // Initial check
        async.flushMicrotasks();
        expect(results, [true], reason: "Initial check G(p) on empty trace should be vacuously true");

        // Add first true state
        controller.add(TestState(true));
        async.flushMicrotasks(); // Process stream event
        // G(p=T) starting at index 0 on trace [T] is true.
        expect(results, [true, true], reason: "After T, G(T) stays true");

        // Add second true state
        controller.add(TestState(true));
        async.flushMicrotasks(); // Process stream event
        // G(p=T) starting at index 1 on trace [T, T] is true.
        expect(results, [true, true, true], reason: "After T, T, G(T) stays true");

        // Add false state
        controller.add(TestState(false));
        async.flushMicrotasks(); // Process stream event
        // G(p=T) starting at index 2 on trace [T, T, F] is false.
        expect(results, [true, true, true, false], reason: "After T, T, F, G(T) becomes false");

        sub.cancel();
      });
    });

    test('dispose stops notifications', () {
      fakeAsync((async) {
        formula = pIs(true);
        checker = StreamLtlChecker<TestState>(
          stream: controller.stream,
          formula: formula,
        );
        final results = <bool>[];
        final sub = checker.resultStream.listen(results.add);

        // Initial emit
        async.flushMicrotasks();
        expect(results, [false]);

        // Add event
        controller.add(TestState(true));
        async.flushMicrotasks();
        expect(results, [false, true]); // F -> T

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
