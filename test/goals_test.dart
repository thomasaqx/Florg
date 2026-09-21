import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:florg/src/data/budget_controller.dart';
import 'package:florg/src/data/goals_controller.dart';
import 'package:florg/src/models/financial_models.dart';
import 'package:florg/src/models/goal_models.dart';

import 'support/fakes.dart';
import 'support/pump.dart';

const _alimentacao = FinancialCategory(id: 'category-1', name: 'Alimentação');
const _transporte = FinancialCategory(id: 'category-2', name: 'Transporte');

void main() {
  group('Goal', () {
    test('meta vinculada a uma conta segue o saldo da conta', () {
      const goal = Goal(
        id: 'g1',
        title: 'Reserva',
        targetAmount: 10000,
        savedAmount: 500,
        linkedAccountId: 'account-1',
      );

      expect(goal.savedWith(6800), 6800);
      expect(goal.progressWith(6800), closeTo(0.68, 0.001));
      expect(goal.remainingWith(6800), 3200);
    });

    test('sem conta vinculada usa o valor guardado à mão', () {
      const goal = Goal(
        id: 'g1',
        title: 'Viagem',
        targetAmount: 6000,
        savedAmount: 1500,
      );

      expect(goal.savedWith(99999), 1500);
      expect(goal.isCompletedWith(null), isFalse);
    });

    test('progresso não passa de 100% nem fica negativo', () {
      const goal = Goal(
        id: 'g1',
        title: 'Notebook',
        targetAmount: 4000,
        savedAmount: 9000,
      );

      expect(goal.progressWith(null), 1.0);
      expect(goal.remainingWith(null), 0);
      expect(goal.isCompletedWith(null), isTrue);
    });

    test('meta sem valor alvo não divide por zero', () {
      const goal = Goal(id: 'g1', title: 'Vazia', targetAmount: 0, savedAmount: 10);

      expect(goal.progressWith(null), 0);
      expect(goal.isCompletedWith(null), isFalse);
    });
  });

  group('GoalsController', () {
    test('carrega as metas do servidor', () async {
      final repository = FakeGoalsRepository();
      await repository.create(title: 'Viagem', targetAmount: 6000);
      final controller = GoalsController(repository: repository);

      await controller.load();

      expect(controller.goals, hasLength(1));
      expect(controller.goals.single.title, 'Viagem');
      expect(controller.hasLoaded, isTrue);
    });

    test('criar recarrega a lista a partir do servidor', () async {
      final repository = FakeGoalsRepository();
      final controller = GoalsController(repository: repository);
      await controller.load();

      await controller.create(title: 'Carro novo', targetAmount: 45000);

      expect(controller.goals.single.title, 'Carro novo');
    });

    test('aporte soma ao que já estava guardado', () async {
      final repository = FakeGoalsRepository();
      final created = await repository.create(
        title: 'Viagem',
        targetAmount: 6000,
        savedAmount: 1500,
      );
      final controller = GoalsController(repository: repository);
      await controller.load();

      await controller.contribute(created.id, 500);

      expect(repository.contributions.single.amount, 500);
      expect(controller.goals.single.savedAmount, 2000);
    });

    test('remover tira a meta da lista', () async {
      final repository = FakeGoalsRepository();
      final created = await repository.create(title: 'Viagem', targetAmount: 100);
      final controller = GoalsController(repository: repository);
      await controller.load();

      await controller.delete(created.id);

      expect(controller.goals, isEmpty);
      expect(repository.deleted, [created.id]);
    });

    test('limpar apaga as metas do usuário anterior', () async {
      final repository = FakeGoalsRepository();
      await repository.create(title: 'Viagem', targetAmount: 100);
      final controller = GoalsController(repository: repository);
      await controller.load();

      controller.clear();

      expect(controller.goals, isEmpty);
      expect(controller.hasLoaded, isFalse);
    });
  });

  group('BudgetController', () {
    test('traduz id de categoria em nome para as telas', () async {
      final repository = FakeBudgetRepository();
      await repository.set(
        categoryId: _alimentacao.id,
        month: DateTime(2026, 4, 1),
        limitAmount: 1500,
      );
      final controller = BudgetController(repository: repository);
      await controller.load();

      final limits = controller.limitsFor(
        const [_alimentacao, _transporte],
        month: DateTime(2026, 4, 20),
      );

      expect(limits, {'Alimentação': 1500.0});
    });

    test('ignora o teto de outro mês', () async {
      final repository = FakeBudgetRepository();
      await repository.set(
        categoryId: _alimentacao.id,
        month: DateTime(2026, 3, 1),
        limitAmount: 1200,
      );
      final controller = BudgetController(repository: repository);
      await controller.load();

      final limits = controller.limitsFor(
        const [_alimentacao],
        month: DateTime(2026, 4, 1),
      );

      expect(limits, isEmpty);
    });

    test('definir teto grava por id e qualquer dia vira o dia 1', () async {
      final repository = FakeBudgetRepository();
      final controller = BudgetController(repository: repository);
      await controller.load();

      await controller.setLimit(
        categories: const [_alimentacao],
        categoryName: 'Alimentação',
        month: DateTime(2026, 4, 23),
        limitAmount: 1500,
      );

      expect(repository.saved.single.categoryId, _alimentacao.id);
      expect(controller.budgets.single.month, DateTime(2026, 4, 1));
    });

    test('teto zerado apaga o orçamento em vez de gravar zero', () async {
      final repository = FakeBudgetRepository();
      final created = await repository.set(
        categoryId: _alimentacao.id,
        month: DateTime(2026, 4, 1),
        limitAmount: 1500,
      );
      final controller = BudgetController(repository: repository);
      await controller.load();

      await controller.setLimit(
        categories: const [_alimentacao],
        categoryName: 'Alimentação',
        month: DateTime(2026, 4, 1),
        limitAmount: 0,
      );

      expect(repository.deleted, [created.id]);
      expect(controller.budgets, isEmpty);
    });

    test('categoria desconhecida vira erro em vez de requisição', () async {
      final repository = FakeBudgetRepository();
      final controller = BudgetController(repository: repository);

      await controller.setLimit(
        categories: const [_alimentacao],
        categoryName: 'Categoria que não existe',
        month: DateTime(2026, 4, 1),
        limitAmount: 100,
      );

      expect(repository.saved, isEmpty);
      expect(controller.errorMessage, contains('não existe'));
    });
  });

  group('tela de Metas', () {
    testWidgets('mostra as metas vindas do servidor', (tester) async {
      useDesktopSize(tester);
      final goals = FakeGoalsRepository();
      await goals.create(
        title: 'Viagem em dezembro',
        targetAmount: 6000,
        savedAmount: 2040,
      );
      await pumpApp(tester, goals: goals);
      await openGoals(tester);

      expect(find.text('Viagem em dezembro'), findsOneWidget);
      expect(find.text('R\$ 2.040,00 de R\$ 6.000,00'), findsOneWidget);
      expect(find.text('34%'), findsOneWidget);
    });

    testWidgets('sem metas, explica o que fazer', (tester) async {
      useDesktopSize(tester);
      await pumpApp(tester);
      await openGoals(tester);

      expect(
        find.textContaining('Você ainda não tem metas'),
        findsOneWidget,
      );
    });

    testWidgets('criar uma meta grava no repositório', (tester) async {
      useDesktopSize(tester);
      final goals = FakeGoalsRepository();
      await pumpApp(tester, goals: goals);
      await openGoals(tester);

      await tester.tap(find.text('Nova meta'));
      await tester.pumpAndSettle();

      // Restrito ao diálogo: a busca da tela por trás também é um TextField.
      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'Notebook novo');
      await tester.enterText(fields.at(2), '4500');
      await tester.tap(find.text('Criar meta'));
      await tester.pumpAndSettle();

      expect(goals.goals.single.title, 'Notebook novo');
      expect(goals.goals.single.targetAmount, 4500);
      expect(find.text('Notebook novo'), findsOneWidget);
    });

    testWidgets('meta sem título não é criada', (tester) async {
      useDesktopSize(tester);
      final goals = FakeGoalsRepository();
      await pumpApp(tester, goals: goals);
      await openGoals(tester);

      await tester.tap(find.text('Nova meta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Criar meta'));
      await tester.pumpAndSettle();

      expect(goals.goals, isEmpty);
      expect(find.text('Dê um nome para a meta.'), findsOneWidget);
    });
  });
}
