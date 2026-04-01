import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_core/temporal_logic_core.dart' show TimedValue;
import 'package:temporal_logic_flutter/src/check_status.dart';
import 'package:temporal_logic_flutter/src/stream_sustained_state_checker.dart';

// Simple enum state for testing
enum TestState { initial, target, other }

void main() {
  group('StreamSustainedStateChecker', () {
    late StreamController<TimedValue<TestState>> controller;
    const targetState = TestState.target;
    const sustainDuration = Duration(milliseconds: 100);
    late StreamSustainedStateChecker<TestState> checker;
    late List<CheckStatus> recordedStatuses;
    late VoidCallback listener;

    // Helper to wait for microtasks to complete, ensuring listeners fire
    Future<void> pumpEventQueue() => Future.delayed(Duration.zero);

    setUp(() {
      controller = StreamController<TimedValue<TestState>>.broadcast();
      recordedStatuses = [];
      listener = () {
        recordedStatuses.add(checker.resultListenable.value);
      };
    });

    tearDown(() async {
      checker.resultListenable.removeListener(listener);
      checker.dispose();
      if (!controller.isClosed) {
        await controller.close();
      }
    });

    TimedValue<TestState> tv(TestState state, int millis) =>
        TimedValue(state, Duration(milliseconds: millis));

    // Helper function to initialize checker and listener
    void initializeChecker({TimedValue<TestState>? initialValue}) {
      checker = StreamSustainedStateChecker(
        controller.stream,
        targetState: targetState,
        sustainDuration: sustainDuration,
        initialValue: initialValue,
      );
      recordedStatuses.add(checker.resultListenable.value);
      checker.resultListenable.addListener(listener);
    }

    test('Initial state is target and sustained -> Success', () async {
      initializeChecker(initialValue: tv(TestState.target, 0));
      controller.add(tv(TestState.target, 150));
      await pumpEventQueue();

      expect(
          recordedStatuses,
          equals([
            CheckStatus.pending, // Initial status after construction
            CheckStatus.success, // After timestamp-based duration is met
          ]));
    });

    test('Initial state is not target -> Failure', () async {
      initializeChecker(initialValue: tv(TestState.initial, 0));
      await pumpEventQueue();

      expect(
          recordedStatuses,
          equals([
            CheckStatus.failure, // Initial status when not target
          ]));
    });

    test('Enter target, stay -> Success', () async {
      initializeChecker(initialValue: tv(TestState.initial, 0));

      controller.add(tv(TestState.target, 10)); // Enter target
      await pumpEventQueue();
      controller.add(tv(TestState.target, 160)); // Stay target long enough
      await pumpEventQueue();

      expect(
          recordedStatuses,
          equals([
            CheckStatus.failure, // Initial
            CheckStatus.pending, // Enters target
            CheckStatus.success, // Stays target long enough
          ]));
    });

    test('Enter target, leave early -> Failure', () async {
      initializeChecker(initialValue: tv(TestState.initial, 0));

      controller.add(tv(TestState.target, 10)); // Enter target
      await pumpEventQueue();
      controller.add(tv(TestState.other, 60)); // Leave target
      await pumpEventQueue();

      expect(
          recordedStatuses,
          equals([
            CheckStatus.failure, // Initial
            CheckStatus.pending, // Enters target
            CheckStatus.failure, // Leaves target too early
          ]));
    });

    test('Enter target, leave early, re-enter, stay -> Success', () async {
      initializeChecker(initialValue: tv(TestState.initial, 0));

      controller.add(tv(TestState.target, 10)); // Enter target (-> Pending)
      await pumpEventQueue();
      controller.add(tv(TestState.other, 60)); // Leave target (-> Failure)
      await pumpEventQueue();
      controller.add(tv(TestState.target, 70)); // Re-enter target (-> Pending)
      await pumpEventQueue();
      controller.add(tv(TestState.target, 220)); // Stay target (-> Success)
      await pumpEventQueue();

      expect(
          recordedStatuses,
          equals([
            CheckStatus.failure, // Initial
            CheckStatus.pending, // Enters target
            CheckStatus.failure, // Leaves target too early
            CheckStatus.pending, // Re-enters target
            CheckStatus.success, // Stays target long enough
          ]));
    });

    test('Stream ends while pending -> Failure', () async {
      initializeChecker(initialValue: tv(TestState.initial, 0));

      controller.add(tv(TestState.target, 10)); // Enter target (-> Pending)
      await pumpEventQueue();
      // Don't add anything else, just close the stream
      await controller.close(); // Triggers onDone which sets failure if pending
      await pumpEventQueue(); // Allow listener to fire

      expect(
          recordedStatuses,
          equals([
            CheckStatus.failure, // Initial
            CheckStatus.pending, // Enters target
            CheckStatus.failure, // Stream ends while pending
          ]));
    });
  });
}
