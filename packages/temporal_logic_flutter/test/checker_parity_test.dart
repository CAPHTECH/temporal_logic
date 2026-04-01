import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart';

/// Verifies that StreamLtlChecker and StreamMtlChecker use the same
/// evaluation-start semantics for pure LTL formulas.
void main() {
  final pTrue = AtomicProposition<bool>((s) => s, name: 'p');
  final pFalse = AtomicProposition<bool>((s) => !s, name: 'not_p');

  void emit(
    FakeAsync async,
    StreamController<bool> ltlController,
    StreamController<TimedValue<bool>> mtlController,
    bool value,
    int millis,
  ) {
    ltlController.add(value);
    mtlController.add(TimedValue(value, Duration(milliseconds: millis)));
    async.flushMicrotasks();
  }

  group('Default semantics evaluate from the beginning', () {
    test('Eventually stays true after an early match', () {
      fakeAsync((async) {
        final ltlController = StreamController<bool>();
        final mtlController = StreamController<TimedValue<bool>>();
        final formula = Eventually(pTrue);

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
        final mtlSub = mtlChecker.resultStream
            .listen((result) => mtlResults.add(result.holds));

        async.flushMicrotasks();
        expect(ltlResults, [false]);
        expect(mtlResults, [false]);

        emit(async, ltlController, mtlController, true, 100);
        emit(async, ltlController, mtlController, false, 200);

        expect(ltlResults.last, isTrue);
        expect(mtlResults.last, isTrue);

        ltlSub.cancel();
        mtlSub.cancel();
        ltlChecker.dispose();
        mtlChecker.dispose();
        ltlController.close();
        mtlController.close();
      });
    });

    test('Always sees the full accumulated trace', () {
      fakeAsync((async) {
        final ltlController = StreamController<bool>();
        final mtlController = StreamController<TimedValue<bool>>();
        final formula = Always(pTrue);

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
        final mtlSub = mtlChecker.resultStream
            .listen((result) => mtlResults.add(result.holds));

        async.flushMicrotasks();

        emit(async, ltlController, mtlController, false, 100);
        emit(async, ltlController, mtlController, true, 200);

        expect(ltlResults.last, isFalse);
        expect(mtlResults.last, isFalse);

        ltlSub.cancel();
        mtlSub.cancel();
        ltlChecker.dispose();
        mtlChecker.dispose();
        ltlController.close();
        mtlController.close();
      });
    });

    test('Next agrees with MTL on the default start position', () {
      fakeAsync((async) {
        final ltlController = StreamController<bool>();
        final mtlController = StreamController<TimedValue<bool>>();
        final formula = Next(pTrue);

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
        final mtlSub = mtlChecker.resultStream
            .listen((result) => mtlResults.add(result.holds));

        async.flushMicrotasks();

        emit(async, ltlController, mtlController, false, 100);
        emit(async, ltlController, mtlController, true, 200);

        expect(ltlResults.last, isTrue);
        expect(mtlResults.last, isTrue);

        ltlSub.cancel();
        mtlSub.cancel();
        ltlChecker.dispose();
        mtlChecker.dispose();
        ltlController.close();
        mtlController.close();
      });
    });
  });

  group('Current-state semantics are available explicitly', () {
    test('Eventually can evaluate from the most recent state', () {
      fakeAsync((async) {
        final ltlController = StreamController<bool>();
        final mtlController = StreamController<TimedValue<bool>>();
        final formula = Eventually(pTrue);

        final ltlChecker = StreamLtlChecker<bool>(
          stream: ltlController.stream,
          formula: formula,
          evaluationStart: StreamEvaluationStart.current,
        );
        final mtlChecker = StreamMtlChecker<bool>(
          mtlController.stream,
          formula: formula,
          evaluationStart: StreamEvaluationStart.current,
        );

        final ltlResults = <bool>[];
        final mtlResults = <bool>[];
        final ltlSub = ltlChecker.resultStream.listen(ltlResults.add);
        final mtlSub = mtlChecker.resultStream
            .listen((result) => mtlResults.add(result.holds));

        async.flushMicrotasks();

        emit(async, ltlController, mtlController, true, 100);
        emit(async, ltlController, mtlController, false, 200);

        expect(ltlResults.last, isFalse);
        expect(mtlResults.last, isFalse);

        ltlSub.cancel();
        mtlSub.cancel();
        ltlChecker.dispose();
        mtlChecker.dispose();
        ltlController.close();
        mtlController.close();
      });
    });

    test('Always can also align on the most recent state', () {
      fakeAsync((async) {
        final ltlController = StreamController<bool>();
        final mtlController = StreamController<TimedValue<bool>>();
        final formula = Always(pFalse);

        final ltlChecker = StreamLtlChecker<bool>(
          stream: ltlController.stream,
          formula: formula,
          evaluationStart: StreamEvaluationStart.current,
        );
        final mtlChecker = StreamMtlChecker<bool>(
          mtlController.stream,
          formula: formula,
          evaluationStart: StreamEvaluationStart.current,
        );

        final ltlResults = <bool>[];
        final mtlResults = <bool>[];
        final ltlSub = ltlChecker.resultStream.listen(ltlResults.add);
        final mtlSub = mtlChecker.resultStream
            .listen((result) => mtlResults.add(result.holds));

        async.flushMicrotasks();

        emit(async, ltlController, mtlController, true, 100);
        emit(async, ltlController, mtlController, false, 200);

        expect(ltlResults.last, isTrue);
        expect(mtlResults.last, isTrue);

        ltlSub.cancel();
        mtlSub.cancel();
        ltlChecker.dispose();
        mtlChecker.dispose();
        ltlController.close();
        mtlController.close();
      });
    });
  });
}
