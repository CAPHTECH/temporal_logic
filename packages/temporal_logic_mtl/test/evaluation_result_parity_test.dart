import 'package:temporal_logic_core/temporal_logic_core.dart' as core;
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart';
import 'package:test/test.dart';

void main() {
  final pEven = core.state<int>((s) => s % 2 == 0, name: 'pEven');
  final pPos = core.state<int>((s) => s > 0, name: 'pPos');
  final pTrue = core.state<int>((_) => true, name: 'pTrue');

  void expectParity(
    core.Trace<int> trace,
    core.Formula<int> formula, {
    int startIndex = 0,
  }) {
    final coreResult =
        core.evaluateTrace(trace, formula, startIndex: startIndex);
    final mtlResult = evaluateMtlTrace(trace, formula, startIndex: startIndex);

    expect(mtlResult.holds, coreResult.holds, reason: 'holds mismatch');
    expect(mtlResult.reason, coreResult.reason, reason: 'reason mismatch');
    expect(mtlResult.relatedIndex, coreResult.relatedIndex,
        reason: 'relatedIndex mismatch');
    expect(mtlResult.relatedTimestamp, coreResult.relatedTimestamp,
        reason: 'relatedTimestamp mismatch');
  }

  group('Pure LTL evaluation details stay aligned', () {
    test('Or failure keeps the combined failure reason', () {
      final trace = core.Trace.fromList([1, 3, 5]);
      expectParity(trace, core.Or<int>(pEven, core.Not<int>(pPos)));
    });

    test('Implies failure keeps the consequent metadata', () {
      final trace = core.Trace.fromList([1, 3, 5]);
      expectParity(trace, core.Implies<int>(pPos, pEven));
    });

    test('Eventually on an empty suffix keeps empty-suffix metadata', () {
      final trace = core.Trace.fromList([1, 2, 3]);
      expectParity(trace, core.Eventually<int>(pTrue),
          startIndex: trace.length);
    });

    test('Until on an empty suffix keeps empty-suffix metadata', () {
      final trace = core.Trace.fromList([1, 2, 3]);
      expectParity(
        trace,
        core.Until<int>(pTrue, pEven),
        startIndex: trace.length,
      );
    });

    test(
        'Nested implication failure inside Always keeps first failing location',
        () {
      final trace = core.Trace.fromList([1, 2, 3, 4]);
      final formula = core.Always<int>(
        core.Implies<int>(pPos, core.Next<int>(pEven)),
      );
      expectParity(trace, formula);
    });
  });
}
