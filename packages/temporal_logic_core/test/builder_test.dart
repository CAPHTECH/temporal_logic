import 'package:temporal_logic_core/temporal_logic_core.dart';
import 'package:test/test.dart';

void main() {
  // Dummy state predicate for testing
  bool isEven(int state) => state % 2 == 0;
  bool isPositive(int state) => state > 0;
  bool isZero(int state) => state == 0;

  group('Atomic Proposition Builders', () {
    test('state() creates AtomicProposition', () {
      final formula = state<int>(isEven, name: 'isEven');
      expect(formula, isA<AtomicProposition<int>>());
      expect(formula.predicate, equals(isEven));
      expect(formula.name, equals('isEven'));
      expect(formula.toString(), equals('isEven'));

      final formulaUnnamed = state<int>(isPositive);
      expect(formulaUnnamed.name, isNull);
      expect(formulaUnnamed.toString(), equals('Atomic'));
    });

    test('event() creates AtomicProposition', () {
      final formula = event<int>(isZero, name: 'isZeroEvent');
      expect(formula, isA<AtomicProposition<int>>());
      expect(formula.predicate, equals(isZero));
      expect(formula.name, equals('isZeroEvent'));
      expect(formula.toString(), equals('isZeroEvent'));

      // Functionally the same as state(), but provides semantic clarity
      final formulaUnnamed = event<int>(isPositive);
      expect(formulaUnnamed.name, isNull);
      expect(formulaUnnamed.toString(), equals('Atomic'));
    });
  });

  group('Temporal Operator Builders (Unary)', () {
    final operand = state<int>(isEven);

    test('next() creates Next', () {
      final formula = next(operand);
      expect(formula, isA<Next<int>>());
      expect(formula.operand, equals(operand));
      expect(formula.toString(), equals('X(Atomic)')); // Assumes operand has no name
    });

    test('always() creates Always', () {
      final formula = always(operand);
      expect(formula, isA<Always<int>>());
      expect(formula.operand, equals(operand));
      expect(formula.toString(), equals('G(Atomic)'));
    });

    test('eventually() creates Eventually', () {
      final formula = eventually(operand);
      expect(formula, isA<Eventually<int>>());
      expect(formula.operand, equals(operand));
      expect(formula.toString(), equals('F(Atomic)'));
    });
  });

  group('Temporal Operator Builders (Binary)', () {
    final leftOperand = state<int>(isPositive, name: 'isPos');
    final rightOperand = state<int>(isEven, name: 'isEven');

    test('until() creates Until', () {
      final formula = until(leftOperand, rightOperand);
      expect(formula, isA<Until<int>>());
      expect(formula.left, equals(leftOperand));
      expect(formula.right, equals(rightOperand));
      expect(formula.toString(), equals('(isPos U isEven)'));
    });

    test('weakUntil() creates WeakUntil', () {
      final formula = weakUntil(leftOperand, rightOperand);
      expect(formula, isA<WeakUntil<int>>());
      expect(formula.left, equals(leftOperand));
      expect(formula.right, equals(rightOperand));
      expect(formula.toString(), equals('(isPos W isEven)'));
    });

    test('release() creates Release', () {
      final formula = release(leftOperand, rightOperand);
      expect(formula, isA<Release<int>>());
      expect(formula.left, equals(leftOperand));
      expect(formula.right, equals(rightOperand));
      expect(formula.toString(), equals('(isPos R isEven)'));
    });
  });

  // Note: Boolean connectives (And, Or, Not, Implies) are usually created
  // using extension methods, not direct builder functions in builder.dart.
  // Tests for those would typically reside with the extension method definitions.
}
