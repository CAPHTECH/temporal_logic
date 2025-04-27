import 'package:clock/clock.dart'; // Import clock
import 'package:fake_async/fake_async.dart'; // Add fake_async
import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_flutter/src/trace_recorder.dart';

/// Simple utility to check if a duration is close to another within a delta.
Matcher closeToDuration(Duration expected, Duration delta) {
  return predicate<Duration>(
    (d) => (d - expected).abs() <= delta,
    'is close to $expected (within $delta)',
  );
}

void main() {
  group('TraceRecorder', () {
    // Remove setUp and recorder instance from here
    // late TraceRecorder<String> recorder;
    // setUp(() {
    //   recorder = TraceRecorder<String>();
    // });

    test('records events with timestamps relative to initialize', () {
      fakeAsync((async) {
        // Create recorder INSIDE fakeAsync, passing the zone's clock
        final recorder = TraceRecorder<String>(clock: clock);
        // final startTime = clock.now(); // Use clock.now() from fakeAsync context

        recorder.initialize(); // Initialize using the fake clock implicitly

        // Simulate time passing before adding events
        async.elapse(const Duration(milliseconds: 10));
        recorder.record('a'); // Should be at 10ms relative to initialize

        async.elapse(const Duration(milliseconds: 20));
        recorder.record('b'); // Should be at 30ms relative to initialize (10 + 20)

        final trace = recorder.trace;

        expect(trace.length, 2);
        expect(trace.events[0].value, 'a');
        expect(trace.events[0].timestamp, equals(const Duration(milliseconds: 10)));

        expect(trace.events[1].value, 'b');
        expect(trace.events[1].timestamp, equals(const Duration(milliseconds: 30)));
      });
    });

    test('trace is empty if not initialized', () {
      // No fakeAsync needed here as no time manipulation occurs
      final recorder = TraceRecorder<String>();
      // No initialize call
      // recorder.record('hello'); // Calling record w/o init throws, test this separately
      expect(recorder.trace.isEmpty, isTrue);
    });

    test('trace is empty if no events added after initialize', () {
      // No fakeAsync needed here
      final recorder = TraceRecorder<bool>();
      recorder.initialize();
      expect(recorder.trace.isEmpty, isTrue);
    });

    test('re-initializing clears previous events', () {
      fakeAsync((async) {
        // Create recorder INSIDE fakeAsync, passing the zone's clock
        final recorder = TraceRecorder<int>(clock: clock);

        // First initialization and event
        recorder.initialize();
        async.elapse(const Duration(milliseconds: 5));
        recorder.record(100);
        expect(recorder.trace.length, 1);
        expect(recorder.trace.events[0].timestamp, equals(const Duration(milliseconds: 5)));

        // Second initialization
        async.elapse(const Duration(milliseconds: 50)); // Ensure time passes
        recorder.initialize(); // Re-initialize
        expect(recorder.trace.isEmpty, isTrue, reason: 'Trace should be empty after re-initialize');

        // Add new event relative to the *second* initialization time
        async.elapse(const Duration(milliseconds: 15));
        recorder.record(200);

        final trace = recorder.trace;
        expect(trace.length, 1);
        expect(trace.events[0].value, 200);
        expect(trace.events[0].timestamp, equals(const Duration(milliseconds: 15)));
      });
    });

    test('uses clock.now() implicitly when initialized', () {
      // Test that initialization captures the current fake time
      fakeAsync((async) {
        // Create recorder INSIDE fakeAsync, passing the zone's clock
        final recorder = TraceRecorder<int>(clock: clock);
        // Elapse time *before* initializing
        async.elapse(const Duration(seconds: 1));
        recorder.initialize(); // Should use time t=1s as start

        async.elapse(const Duration(milliseconds: 10)); // Elapse to t=1s + 10ms
        recorder.record(1); // Event should be at 10ms relative to start

        expect(recorder.trace.length, 1);
        expect(recorder.trace.events[0].timestamp, equals(const Duration(milliseconds: 10)));
      });
    });

    test('handles String events', () {
      fakeAsync((async) {
        // Create recorder INSIDE fakeAsync, passing the zone's clock
        final recorder = TraceRecorder<String>(clock: clock);
        recorder.initialize();
        async.elapse(const Duration(milliseconds: 2));
        recorder.record('test');
        expect(recorder.trace.length, 1);
        expect(recorder.trace.events[0].value, 'test');
        expect(recorder.trace.events[0].timestamp, equals(const Duration(milliseconds: 2)));
      });
    });

    test('returns an immutable trace wrapper', () {
      // No fakeAsync needed
      final recorder = TraceRecorder<String>();
      recorder.initialize();
      recorder.record('a');
      final trace = recorder.trace;

      // Attempt to modify the trace via the wrapper (should fail or not affect recorder)
      try {
        (trace.events).clear();
      } catch (e) {
        // Expected if the list is unmodifiable
      }
      // Check if the recorder's internal state was affected
      expect(recorder.trace.length, 1, reason: 'Original recorder trace should remain unchanged');
    });

    test('record without initialize throws StateError', () {
      // No fakeAsync needed
      final freshRecorder = TraceRecorder<int>();
      expect(() => freshRecorder.record(1), throwsStateError);
    });

    test('record does not add duplicates by default', () {
      // No fakeAsync needed
      final recorder = TraceRecorder<String>();
      recorder.initialize();
      recorder.record('a');
      recorder.record('a');
      recorder.record('b');
      recorder.record('a'); // Change back
      recorder.record('a');

      expect(recorder.trace.length, 3);
      expect(recorder.trace.events.map((e) => e.value).toList(), equals(['a', 'b', 'a']));
    });

    test('record adds duplicates when recordDuplicates is true', () {
      // No fakeAsync needed
      final recorder = TraceRecorder<String>();
      recorder.initialize();
      recorder.record('a', recordDuplicates: true);
      recorder.record('a', recordDuplicates: true);
      recorder.record('b', recordDuplicates: true);

      expect(recorder.trace.length, 3);
      expect(recorder.trace.events.map((e) => e.value).toList(), equals(['a', 'a', 'b']));
    });
  });
}
