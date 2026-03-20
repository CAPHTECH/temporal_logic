import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart';

/// Documents and verifies the semantic difference between:
/// - StreamLtlChecker: evaluates formula at the LAST index of the accumulated trace
/// - StreamMtlChecker: evaluates formula at index 0 of the accumulated trace
///
/// This means they can disagree on formulas that are position-sensitive
/// (e.g., Eventually, Always, Next).
void main() {
  // Simple state type
  final pTrue_f = AtomicProposition<bool>((s) => s, name: 'p');
  final pFalse_f = AtomicProposition<bool>((s) => !s, name: 'not_p');

  group('Cases where both checkers agree', () {
    test('G(p) on uniform true trace', () {
      fakeAsync((async) {
        final ltlController = StreamController<bool>();
        final mtlController = StreamController<TimedValue<bool>>();
        final formula = Always(pTrue_f);

        final ltlChecker = StreamLtlChecker<bool>(
          stream: ltlController.stream,
          formula: formula,
        );
        final mtlChecker = StreamMtlChecker<bool>(
          mtlController.stream,
          formula: formula,
        );

        final ltlResults = <bool>[];
        final mtlResults = <bool>[];
        final ltlSub = ltlChecker.resultStream.listen(ltlResults.add);
        final mtlSub =
            mtlChecker.resultStream.listen((r) => mtlResults.add(r.holds));

        async.flushMicrotasks();

        // Add uniform true states
        ltlController.add(true);
        mtlController.add(TimedValue(
            true, const Duration(milliseconds: 100)));
        async.flushMicrotasks();

        ltlController.add(true);
        mtlController.add(TimedValue(
            true, const Duration(milliseconds: 200)));
        async.flushMicrotasks();

        // Both should agree: G(p) is true on [T, T] regardless of eval index
        // LTL: evaluates at last index -> G(p) at idx 1 = true (only T remaining)
        // MTL: evaluates at index 0 -> G(p) at idx 0 = true (all T)
        expect(ltlResults.last, isTrue);
        expect(mtlResults.last, isTrue);

        ltlSub.cancel();
        mtlSub.cancel();
        ltlChecker.dispose();
        mtlChecker.dispose();
      });
    });

    test('atomic proposition on single event', () {
      fakeAsync((async) {
        final ltlController = StreamController<bool>();
        final mtlController = StreamController<TimedValue<bool>>();
        final formula = pTrue_f;

        final ltlChecker = StreamLtlChecker<bool>(
          stream: ltlController.stream,
          formula: formula,
        );
        final mtlChecker = StreamMtlChecker<bool>(
          mtlController.stream,
          formula: formula,
        );

        final ltlResults = <bool>[];
        final mtlResults = <bool>[];
        final ltlSub = ltlChecker.resultStream.listen(ltlResults.add);
        final mtlSub =
            mtlChecker.resultStream.listen((r) => mtlResults.add(r.holds));

        async.flushMicrotasks();

        // Add single true state
        ltlController.add(true);
        mtlController.add(
            TimedValue(true, const Duration(milliseconds: 100)));
        async.flushMicrotasks();

        // Both evaluate atomic at their respective index -> both true
        expect(ltlResults.last, isTrue);
        expect(mtlResults.last, isTrue);

        ltlSub.cancel();
        mtlSub.cancel();
        ltlChecker.dispose();
        mtlChecker.dispose();
      });
    });
  });

  group('Cases where checkers diverge', () {
    test('F(p) found early - MTL sees it, LTL may not', () {
      fakeAsync((async) {
        final ltlController = StreamController<bool>();
        final mtlController = StreamController<TimedValue<bool>>();
        // F(p) = Eventually p is true
        final formula = Eventually(pTrue_f);

        final ltlChecker = StreamLtlChecker<bool>(
          stream: ltlController.stream,
          formula: formula,
        );
        final mtlChecker = StreamMtlChecker<bool>(
          mtlController.stream,
          formula: formula,
        );

        final ltlResults = <bool>[];
        final mtlResults = <bool>[];
        final ltlSub = ltlChecker.resultStream.listen(ltlResults.add);
        final mtlSub =
            mtlChecker.resultStream.listen((r) => mtlResults.add(r.holds));

        async.flushMicrotasks();

        // Trace: [T, F]
        ltlController.add(true);
        mtlController.add(TimedValue(
            true, const Duration(milliseconds: 100)));
        async.flushMicrotasks();

        ltlController.add(false);
        mtlController.add(TimedValue(
            false, const Duration(milliseconds: 200)));
        async.flushMicrotasks();

        // LTL: evaluates F(p) at last index (idx 1, value=false)
        //   -> from idx 1, F(p=true) checks only idx 1 (false) -> false
        // MTL: evaluates F(p) at index 0 (value=true)
        //   -> from idx 0, F(p=true) finds it at idx 0 -> true
        expect(ltlResults.last, isFalse,
            reason: 'LTL checker evaluates at last index, F(p) fails');
        expect(mtlResults.last, isTrue,
            reason: 'MTL checker evaluates at index 0, F(p) finds early hit');

        ltlSub.cancel();
        mtlSub.cancel();
        ltlChecker.dispose();
        mtlChecker.dispose();
      });
    });

    test('G(p) on [F, T] - LTL sees only last, MTL sees all', () {
      fakeAsync((async) {
        final ltlController = StreamController<bool>();
        final mtlController = StreamController<TimedValue<bool>>();
        final formula = Always(pTrue_f);

        final ltlChecker = StreamLtlChecker<bool>(
          stream: ltlController.stream,
          formula: formula,
        );
        final mtlChecker = StreamMtlChecker<bool>(
          mtlController.stream,
          formula: formula,
        );

        final ltlResults = <bool>[];
        final mtlResults = <bool>[];
        final ltlSub = ltlChecker.resultStream.listen(ltlResults.add);
        final mtlSub =
            mtlChecker.resultStream.listen((r) => mtlResults.add(r.holds));

        async.flushMicrotasks();

        // Trace: [F, T]
        ltlController.add(false);
        mtlController.add(TimedValue(
            false, const Duration(milliseconds: 100)));
        async.flushMicrotasks();

        ltlController.add(true);
        mtlController.add(TimedValue(
            true, const Duration(milliseconds: 200)));
        async.flushMicrotasks();

        // LTL: G(p) at last index (idx 1, value=true) -> only checks idx 1 -> true
        // MTL: G(p) at index 0 (value=false) -> fails at idx 0 -> false
        expect(ltlResults.last, isTrue,
            reason: 'LTL checker evaluates at last index, G(p) on [T] suffix');
        expect(mtlResults.last, isFalse,
            reason: 'MTL checker evaluates from index 0, G(p) fails at first F');

        ltlSub.cancel();
        mtlSub.cancel();
        ltlChecker.dispose();
        mtlChecker.dispose();
      });
    });

    test('X(p) on two-event trace', () {
      fakeAsync((async) {
        final ltlController = StreamController<bool>();
        final mtlController = StreamController<TimedValue<bool>>();
        // X(p) = Next(p is true)
        final formula = Next(pTrue_f);

        final ltlChecker = StreamLtlChecker<bool>(
          stream: ltlController.stream,
          formula: formula,
        );
        final mtlChecker = StreamMtlChecker<bool>(
          mtlController.stream,
          formula: formula,
        );

        final ltlResults = <bool>[];
        final mtlResults = <bool>[];
        final ltlSub = ltlChecker.resultStream.listen(ltlResults.add);
        final mtlSub =
            mtlChecker.resultStream.listen((r) => mtlResults.add(r.holds));

        async.flushMicrotasks();

        // Trace: [F, T]
        ltlController.add(false);
        mtlController.add(TimedValue(
            false, const Duration(milliseconds: 100)));
        async.flushMicrotasks();

        ltlController.add(true);
        mtlController.add(TimedValue(
            true, const Duration(milliseconds: 200)));
        async.flushMicrotasks();

        // LTL: X(p) at last index (idx 1) -> needs idx 2 (out of bounds) -> false
        // MTL: X(p) at index 0 -> checks idx 1 (value=true) -> true
        expect(ltlResults.last, isFalse,
            reason: 'LTL checker: X(p) at last index hits trace end');
        expect(mtlResults.last, isTrue,
            reason: 'MTL checker: X(p) at index 0 finds next event');

        ltlSub.cancel();
        mtlSub.cancel();
        ltlChecker.dispose();
        mtlChecker.dispose();
      });
    });
  });

  group('StreamMtlChecker with pure-LTL formulas', () {
    test('Eventually with multiple events', () {
      fakeAsync((async) {
        final controller = StreamController<TimedValue<bool>>();
        final formula = Eventually(pTrue_f);

        final checker = StreamMtlChecker<bool>(
          controller.stream,
          formula: formula,
        );

        final results = <bool>[];
        final sub = checker.resultStream.listen((r) => results.add(r.holds));
        async.flushMicrotasks();

        // Initial: empty trace -> false
        expect(results, [false]);

        // Add F
        controller.add(TimedValue(
            false, const Duration(milliseconds: 100)));
        async.flushMicrotasks();
        expect(results.last, isFalse);

        // Add T -> F(p) from idx 0 finds T at idx 1
        controller.add(TimedValue(
            true, const Duration(milliseconds: 200)));
        async.flushMicrotasks();
        expect(results.last, isTrue);

        // Add F -> F(p) from idx 0 still finds T at idx 1
        controller.add(TimedValue(
            false, const Duration(milliseconds: 300)));
        async.flushMicrotasks();
        expect(results.last, isTrue);

        sub.cancel();
        checker.dispose();
      });
    });

    test('Always with accumulating trace', () {
      fakeAsync((async) {
        final controller = StreamController<TimedValue<bool>>();
        final formula = Always(pTrue_f);

        final checker = StreamMtlChecker<bool>(
          controller.stream,
          formula: formula,
        );

        final results = <bool>[];
        final sub = checker.resultStream.listen((r) => results.add(r.holds));
        async.flushMicrotasks();

        // Initial: empty trace -> G(p) vacuously true
        expect(results, [true]);

        // Add T -> G(p) on [T] from idx 0 -> true
        controller.add(TimedValue(
            true, const Duration(milliseconds: 100)));
        async.flushMicrotasks();
        expect(results.last, isTrue);

        // Add T -> G(p) on [T,T] from idx 0 -> true
        controller.add(TimedValue(
            true, const Duration(milliseconds: 200)));
        async.flushMicrotasks();
        expect(results.last, isTrue);

        // Add F -> G(p) on [T,T,F] from idx 0 -> false (fails at idx 2)
        controller.add(TimedValue(
            false, const Duration(milliseconds: 300)));
        async.flushMicrotasks();
        expect(results.last, isFalse);

        sub.cancel();
        checker.dispose();
      });
    });

    test('Until with pure-LTL semantics', () {
      fakeAsync((async) {
        final controller = StreamController<TimedValue<bool>>();
        // not_p U p -> false until true
        final formula = Until(pFalse_f, pTrue_f);

        final checker = StreamMtlChecker<bool>(
          controller.stream,
          formula: formula,
        );

        final results = <bool>[];
        final sub = checker.resultStream.listen((r) => results.add(r.holds));
        async.flushMicrotasks();

        // Initial: empty trace -> Until fails
        expect(results, [false]);

        // Add F -> not_p(T) U p(F): p never holds -> false
        controller.add(TimedValue(
            false, const Duration(milliseconds: 100)));
        async.flushMicrotasks();
        expect(results.last, isFalse);

        // Add T -> not_p U p: p holds at idx 1, not_p holds at idx 0 -> true
        controller.add(TimedValue(
            true, const Duration(milliseconds: 200)));
        async.flushMicrotasks();
        expect(results.last, isTrue);

        sub.cancel();
        checker.dispose();
      });
    });
  });
}
