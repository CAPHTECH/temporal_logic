import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart' as tlCore;
import 'package:temporal_logic_flutter/src/stream_mtl_checker.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart' as tlFlutter;
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart' as tlMtl;

// Simple enum state for testing
enum TestState { initial, target, other }

void main() {
  group('StreamMtlChecker', () {
    late StreamController<tlCore.TimedValue<TestState>> controller;

    setUp(() {
      controller = StreamController<tlCore.TimedValue<TestState>>.broadcast();
    });

    tearDown(() {
      controller.close();
    });

    // Helper to create TimedValue
    tlCore.TimedValue<TestState> tv(TestState state, int millis) =>
        tlCore.TimedValue(state, Duration(milliseconds: millis));

    // Helper to check emitted results (checks only 'holds' status for simplicity)
    Matcher emitsHoldStatus(List<bool> expectedHolds) {
      return emitsInOrder(
          expectedHolds.map((holds) => predicate<tlCore.EvaluationResult>((r) => r.holds == holds)).toList()
            // Add emitsDone check when using fake_async for stricter checks
            ..add(emitsDone));
    }

    test('F_[0, 100] target - holds with initial value', () {
      fakeAsync((async) {
        final formula = tlMtl.EventuallyTimed(
          tlFlutter.state<TestState>((s) => s == TestState.target),
          tlMtl.TimeInterval(Duration.zero, const Duration(milliseconds: 100)),
        );
        final checker = StreamMtlChecker<TestState>(
          controller.stream,
          formula: formula,
          initialValue: tv(TestState.target, 50), // Initial value within interval
        );

        expectLater(checker.resultStream, emitsHoldStatus([true]));

        controller.close();
        async.flushMicrotasks(); // Ensure scheduled tasks run
      });
    });

    test('F_[50, 150] target - holds when event arrives within interval', () {
      fakeAsync((async) {
        final formula = tlMtl.EventuallyTimed(
          tlFlutter.state<TestState>((s) => s == TestState.target),
          tlMtl.TimeInterval(const Duration(milliseconds: 50), const Duration(milliseconds: 150)),
        );
        final checker = StreamMtlChecker<TestState>(
          controller.stream,
          formula: formula,
          initialValue: tv(TestState.initial, 0),
        );

        expectLater(checker.resultStream, emitsHoldStatus([false, false, true]));

        async.elapse(const Duration(milliseconds: 10));
        controller.add(tv(TestState.other, 10)); // Doesn't satisfy yet
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 70)); // t=80ms
        controller.add(tv(TestState.target, 80)); // Satisfies F_[50, 150]
        async.flushMicrotasks();

        controller.close();
        async.flushMicrotasks();
      });
    });

    test('F_[50, 150] target - fails when event arrives after interval', () {
      fakeAsync((async) {
        final formula = tlMtl.EventuallyTimed(
          tlFlutter.state<TestState>((s) => s == TestState.target),
          tlMtl.TimeInterval(const Duration(milliseconds: 50), const Duration(milliseconds: 150)),
        );
        final checker = StreamMtlChecker<TestState>(
          controller.stream,
          formula: formula,
          initialValue: tv(TestState.initial, 0),
        );

        // Expect initial false, then false again after 'other', then false after late 'target'
        expectLater(checker.resultStream, emitsHoldStatus([false, false, false]));

        async.elapse(const Duration(milliseconds: 10));
        controller.add(tv(TestState.other, 10));
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 170)); // t=180ms
        controller.add(tv(TestState.target, 180)); // Event arrives too late
        async.flushMicrotasks();

        controller.close();
        async.flushMicrotasks();
      });
    });

    test('G target - simple always check', () {
      fakeAsync((async) {
        final formula = tlCore.always(
          tlFlutter.state<TestState>((s) => s == TestState.target),
        );
        final checker = StreamMtlChecker<TestState>(
          controller.stream,
          formula: formula,
          initialValue: tv(TestState.target, 0),
        );

        // Initial: true. After target@10: true. After other@20: false.
        expectLater(checker.resultStream, emitsHoldStatus([true, true, false]));

        async.elapse(const Duration(milliseconds: 10));
        controller.add(tv(TestState.target, 10));
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 10)); // t=20ms
        controller.add(tv(TestState.other, 20)); // Violation
        async.flushMicrotasks();

        controller.close();
        async.flushMicrotasks();
      });
    });
  });
}
