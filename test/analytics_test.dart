import 'package:flutter_test/flutter_test.dart';

import 'package:florg/src/core/analytics.dart';
import 'package:florg/src/models/financial_models.dart';

Transaction expense(String description, double amount, DateTime date) =>
    Transaction(
      id: '$description-${date.toIso8601String()}-$amount',
      date: date,
      description: description,
      category: description,
      amount: amount,
      type: TransactionKind.expense,
      account: 'Conta',
      accountId: 'account-1',
    );

Transaction income(double amount, DateTime date) => Transaction(
  id: 'in-${date.toIso8601String()}',
  date: date,
  description: 'Salário',
  category: 'Outros',
  amount: amount,
  type: TransactionKind.income,
  account: 'Conta',
  accountId: 'account-1',
);

void main() {
  final now = DateTime(2026, 4, 15);
  final thisMonth = DateTime(2026, 4, 3);
  final lastMonth = DateTime(2026, 3, 3);

  group('savingsRate', () {
    test('devolve null sem receita, em vez de dividir por zero', () {
      expect(savingsRate(0, 500), isNull);
      expect(savingsRate(-10, 500), isNull);
    });

    test('calcula a sobra quando há receita', () {
      expect(savingsRate(1000, 750), 25);
    });
  });

  group('percentChange', () {
    test('devolve null sem base de comparação', () {
      expect(percentChange(0, 300), isNull);
    });

    test('mede alta e queda', () {
      expect(percentChange(200, 300), 50);
      expect(percentChange(200, 100), -50);
    });
  });

  group('monthlyTrend', () {
    test('preenche meses sem lançamento com zero', () {
      final trend = monthlyTrend([
        expense('Mercado', 100, thisMonth),
      ], months: 3, until: now);

      expect(trend.length, 3);
      expect(trend.last.spending, 100);
      expect(trend.first.spending, 0);
      expect(trend.map((point) => point.month).toList(), ['fev', 'mar', 'abr']);
    });

    test('separa receita de despesa', () {
      final trend = monthlyTrend([
        income(5000, thisMonth),
        expense('Mercado', 800, thisMonth),
      ], months: 1, until: now);

      expect(trend.single.income, 5000);
      expect(trend.single.spending, 800);
    });
  });

  group('categoryBreakdownOf', () {
    test('soma despesas do mês, da maior para a menor', () {
      final slices = categoryBreakdownOf([
        expense('Moradia', 1800, thisMonth),
        expense('Alimentação', 400, thisMonth),
        expense('Alimentação', 200, thisMonth),
        expense('Moradia', 1800, lastMonth), // outro mês, fora da conta
        income(5000, thisMonth), // receita não entra
      ], month: now);

      expect(slices.map((slice) => slice.name).toList(), [
        'Moradia',
        'Alimentação',
      ]);
      expect(slices.first.value, 1800);
      expect(slices.last.value, 600);
    });

    test('mesma categoria mantém a mesma cor entre chamadas', () {
      expect(colorForCategory('Alimentação'), colorForCategory('Alimentação'));
    });
  });

  group('budgetsFor', () {
    test('cruza o teto das configurações com o gasto do extrato', () {
      final budgets = budgetsFor(
        [expense('Alimentação', 700, thisMonth)],
        limits: {'Alimentação': 500},
        month: now,
      );

      final food = budgets.firstWhere(
        (budget) => budget.category == 'Alimentação',
      );
      expect(food.allocated, 500);
      expect(food.spent, 700);
    });

    test('categoria sem teto não é acusada de estouro', () {
      final budgets = budgetsFor([
        expense('Lazer', 120, thisMonth),
      ], limits: const {}, month: now);

      final leisure = budgets.single;
      expect(leisure.allocated, 120);
      expect(leisure.spent, 120);
    });
  });

  group('recurringCandidates', () {
    test('acha a cobrança repetida em dois meses', () {
      final recurring = recurringCandidates([
        expense('Netflix', 39.90, thisMonth),
        expense('Netflix', 39.90, lastMonth),
        expense('Padaria', 12, thisMonth),
      ]);

      expect(recurring.length, 1);
      expect(recurring.single.description, 'Netflix');
      // Devolve a ocorrência mais recente.
      expect(recurring.single.date, thisMonth);
    });

    test('mesmo mês duas vezes não conta como recorrente', () {
      final recurring = recurringCandidates([
        expense('Padaria', 12, DateTime(2026, 4, 1)),
        expense('Padaria', 12, DateTime(2026, 4, 20)),
      ]);

      expect(recurring, isEmpty);
    });
  });

  group('observationsFor', () {
    test('aponta estouro de limite', () {
      final result = observationsFor(
        [expense('Alimentação', 700, thisMonth)],
        limits: {'Alimentação': 500},
        month: now,
      );

      final over = result.firstWhere((item) => item.id.startsWith('limite-'));
      expect(over.type, InsightKind.warning);
      expect(over.potentialSavings, 200);
    });

    test('aponta alta relevante em relação ao mês anterior', () {
      final result = observationsFor(
        [
          expense('Alimentação', 400, lastMonth),
          expense('Alimentação', 800, thisMonth),
        ],
        limits: const {},
        month: now,
      );

      expect(
        result.any((item) => item.title.contains('Alimentação subiu 100%')),
        isTrue,
      );
    });

    test('não inventa observação quando não há o que comparar', () {
      final result = observationsFor(
        [expense('Alimentação', 100, thisMonth)],
        limits: const {},
        month: now,
      );

      expect(result, isEmpty);
    });

    test('avisa quando o mês fecha no vermelho', () {
      final result = observationsFor(
        [income(1000, thisMonth), expense('Moradia', 1500, thisMonth)],
        limits: const {},
        month: now,
      );

      final red = result.firstWhere((item) => item.id == 'negativo');
      expect(red.potentialSavings, 500);
    });
  });
}
