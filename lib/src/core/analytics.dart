import 'package:flutter/material.dart';

import '../models/financial_models.dart';
import 'theme.dart';

/// Deriva os números das telas a partir das transações reais.
///
/// Tudo aqui é função pura sobre a lista que veio da API. Antes estes valores
/// vinham de constantes escritas à mão em mock_data.dart, o que fazia o gráfico
/// mostrar um mês que não existia na conta do usuário.

/// Paleta fixa por categoria, para a mesma categoria manter a cor entre telas.
///
/// As cores vivem em AppColors.chartSeries: um verde novo entra no tema, não
/// aqui.
const _palette = AppColors.chartSeries;

Color colorForCategory(String name) {
  if (name.isEmpty) return AppColors.gray400;
  // Soma dos code units: estável entre execuções, ao contrário de hashCode.
  final seed = name.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return _palette[seed % _palette.length];
}

const _monthAbbreviations = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

String monthAbbreviation(DateTime date) => _monthAbbreviations[date.month - 1];

const _monthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

String monthName(DateTime date) => _monthNames[date.month - 1];

String monthLabel(DateTime date) => '${monthName(date)} de ${date.year}';

/// Receitas e despesas dos últimos [months] meses, do mais antigo ao mais novo.
///
/// Meses sem lançamento entram zerados, senão o gráfico pularia o buraco e
/// daria a impressão de que o mês não existiu.
List<MonthlySpending> monthlyTrend(
  Iterable<Transaction> source, {
  int months = 7,
  DateTime? until,
}) {
  final end = until ?? DateTime.now();
  final buckets = <String, MonthlySpending>{};
  final order = <String>[];

  for (var offset = months - 1; offset >= 0; offset--) {
    final month = DateTime(end.year, end.month - offset);
    final key = '${month.year}-${month.month}';
    order.add(key);
    buckets[key] = MonthlySpending(
      month: monthAbbreviation(month),
      spending: 0,
      income: 0,
    );
  }

  for (final transaction in source) {
    final key = '${transaction.date.year}-${transaction.date.month}';
    final bucket = buckets[key];
    if (bucket == null) continue;

    buckets[key] = MonthlySpending(
      month: bucket.month,
      spending: bucket.spending +
          (transaction.type == TransactionKind.expense ? transaction.amount : 0),
      income: bucket.income +
          (transaction.type == TransactionKind.income ? transaction.amount : 0),
    );
  }

  return [for (final key in order) buckets[key]!];
}

/// Despesas do mês agrupadas por categoria, da maior para a menor.
List<CategorySlice> categoryBreakdownOf(
  Iterable<Transaction> source, {
  DateTime? month,
}) {
  final reference = month ?? DateTime.now();
  final totals = <String, double>{};

  for (final transaction in source) {
    if (transaction.type != TransactionKind.expense) continue;
    if (transaction.date.year != reference.year ||
        transaction.date.month != reference.month) {
      continue;
    }
    totals[transaction.category] =
        (totals[transaction.category] ?? 0) + transaction.amount;
  }

  final slices = totals.entries
      .map(
        (entry) => CategorySlice(
          name: entry.key,
          value: entry.value,
          color: colorForCategory(entry.key),
        ),
      )
      .toList();
  slices.sort((a, b) => b.value.compareTo(a.value));
  return slices;
}

/// Orçamentos do mês: o limite vem das configurações, o gasto vem do extrato.
///
/// Categorias sem limite definido entram com o próprio gasto como teto, para
/// aparecerem na lista sem serem acusadas de estouro.
List<Budget> budgetsFor(
  Iterable<Transaction> source, {
  required Map<String, double> limits,
  DateTime? month,
}) {
  final spent = {
    for (final slice in categoryBreakdownOf(source, month: month))
      slice.name: slice.value,
  };
  final names = {...limits.keys, ...spent.keys}.toList()..sort();

  return [
    for (final name in names)
      Budget(
        category: name,
        allocated: limits[name] ?? spent[name] ?? 0,
        spent: spent[name] ?? 0,
        color: colorForCategory(name),
      ),
  ];
}

/// Variação percentual de [current] em relação a [previous].
///
/// Devolve null quando não há base de comparação. Um "+100%" saído de uma
/// divisão por zero é pior do que não mostrar variação nenhuma.
double? percentChange(double previous, double current) {
  if (previous == 0) return null;
  return (current - previous) / previous * 100;
}

/// Quanto sobrou do que entrou, em percentual. Null quando não entrou nada.
double? savingsRate(double income, double expenses) {
  if (income <= 0) return null;
  return (income - expenses) / income * 100;
}

/// Descrições que se repetem mês a mês, pelo mesmo valor.
///
/// Serve para achar assinatura e mensalidade sem o usuário marcar nada.
List<Transaction> recurringCandidates(Iterable<Transaction> source) {
  final byKey = <String, List<Transaction>>{};
  for (final transaction in source) {
    if (transaction.type != TransactionKind.expense) continue;
    final key =
        '${transaction.description.toLowerCase().trim()}|${transaction.amount.toStringAsFixed(2)}';
    byKey.putIfAbsent(key, () => []).add(transaction);
  }

  final recurring = <Transaction>[];
  for (final group in byKey.values) {
    final months = group.map((item) => '${item.date.year}-${item.date.month}').toSet();
    if (months.length >= 2) {
      group.sort((a, b) => b.date.compareTo(a.date));
      recurring.add(group.first);
    }
  }

  recurring.sort((a, b) => b.amount.compareTo(a.amount));
  return recurring;
}

/// Observações sobre o mês, calculadas a partir do extrato.
///
/// Não inventa economia projetada: cada item aponta um número que está no
/// extrato do usuário. A camada de IA da Fase 3 entra aqui.
List<Insight> observationsFor(
  Iterable<Transaction> source, {
  required Map<String, double> limits,
  DateTime? month,
}) {
  final reference = month ?? DateTime.now();
  final previous = DateTime(reference.year, reference.month - 1);

  final thisMonth = categoryBreakdownOf(source, month: reference);
  final lastMonth = {
    for (final slice in categoryBreakdownOf(source, month: previous))
      slice.name: slice.value,
  };

  final result = <Insight>[];

  for (final slice in thisMonth) {
    final limit = limits[slice.name];
    if (limit != null && limit > 0 && slice.value > limit) {
      result.add(
        Insight(
          id: 'limite-${slice.name}',
          type: InsightKind.warning,
          title: '${slice.name} passou do limite',
          description:
              'Você definiu um teto de R\$ ${limit.toStringAsFixed(2).replaceAll('.', ',')} '
              'para ${slice.name} e já gastou R\$ '
              '${slice.value.toStringAsFixed(2).replaceAll('.', ',')} neste mês.',
          category: slice.name,
          potentialSavings: slice.value - limit,
        ),
      );
    }
  }

  for (final slice in thisMonth.take(5)) {
    final before = lastMonth[slice.name];
    final change = before == null ? null : percentChange(before, slice.value);
    if (change != null && change >= 30) {
      result.add(
        Insight(
          id: 'alta-${slice.name}',
          type: InsightKind.warning,
          title: '${slice.name} subiu ${change.round()}%',
          description:
              'No mês passado foram R\$ ${before!.toStringAsFixed(2).replaceAll('.', ',')}. '
              'Neste mês, R\$ ${slice.value.toStringAsFixed(2).replaceAll('.', ',')}.',
          category: slice.name,
          potentialSavings: slice.value - before,
        ),
      );
    } else if (change != null && change <= -20) {
      result.add(
        Insight(
          id: 'queda-${slice.name}',
          type: InsightKind.success,
          title: '${slice.name} caiu ${change.abs().round()}%',
          description:
              'Saiu de R\$ ${before!.toStringAsFixed(2).replaceAll('.', ',')} para R\$ '
              '${slice.value.toStringAsFixed(2).replaceAll('.', ',')} em relação ao mês passado.',
          category: slice.name,
        ),
      );
    }
  }

  final recurring = recurringCandidates(source);
  if (recurring.length >= 3) {
    final total = recurring.fold<double>(0, (sum, item) => sum + item.amount);
    result.add(
      Insight(
        id: 'recorrentes',
        type: InsightKind.info,
        title: '${recurring.length} cobranças se repetem todo mês',
        description:
            'Somam R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')} por mês. '
            'Vale abrir a lista e ver se ainda usa todas.',
        category: 'Recorrentes',
        potentialSavings: total,
      ),
    );
  }

  final income = source
      .where(
        (item) =>
            item.type == TransactionKind.income &&
            item.date.year == reference.year &&
            item.date.month == reference.month,
      )
      .fold<double>(0, (sum, item) => sum + item.amount);
  final expenses = thisMonth.fold<double>(0, (sum, item) => sum + item.value);
  final rate = savingsRate(income, expenses);

  if (rate != null && rate >= 20) {
    result.add(
      Insight(
        id: 'sobra',
        type: InsightKind.success,
        title: 'Sobrou ${rate.round()}% do que entrou',
        description:
            'Entraram R\$ ${income.toStringAsFixed(2).replaceAll('.', ',')} e saíram R\$ '
            '${expenses.toStringAsFixed(2).replaceAll('.', ',')} neste mês.',
        category: 'Resumo do mês',
      ),
    );
  } else if (rate != null && rate < 0) {
    result.add(
      Insight(
        id: 'negativo',
        type: InsightKind.warning,
        title: 'O mês fechou no vermelho',
        description:
            'Saíram R\$ ${expenses.toStringAsFixed(2).replaceAll('.', ',')} contra R\$ '
            '${income.toStringAsFixed(2).replaceAll('.', ',')} de entrada.',
        category: 'Resumo do mês',
        potentialSavings: expenses - income,
      ),
    );
  }

  return result;
}
