import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../core/analytics.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/financial_data_controller.dart';
import '../models/financial_models.dart';
import '../shared/charts.dart';
import '../shared/layout.dart';
import './transactions_screen.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key, this.budgetLimits = const {}});

  final Map<String, double> budgetLimits;

  @override
  Widget build(BuildContext context) {
    final all = context.watch<FinancialDataController>().transactions;
    final now = DateTime.now();
    final previous = DateTime(now.year, now.month - 1);

    final currentMonth = transactionsInMonth(all, now);
    final currentExpenses = totalFor(currentMonth, TransactionKind.expense);
    final previousExpenses = totalFor(
      transactionsInMonth(all, previous),
      TransactionKind.expense,
    );
    // Null no primeiro mês de uso: sem mês anterior, não há variação a mostrar.
    final expenseChange = percentChange(previousExpenses, currentExpenses);

    final dayOfMonth = math.max(1, now.day);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dailyAverage = currentExpenses / dayOfMonth;
    final slices = categoryBreakdownOf(all, month: now);
    final tracked = budgetsFor(all, limits: budgetLimits, month: now);

    if (all.isEmpty) {
      return const PageFrame(
        title: 'Análises',
        subtitle: 'Os gráficos aparecem assim que houver lançamentos.',
        children: [],
      );
    }

    return PageFrame(
      title: 'Análises',
      subtitle: 'Como o dinheiro se distribuiu em ${monthLabel(now)}.',
      children: [
        ResponsiveWrap(
          minItemWidth: 260,
          maxColumns: 3,
          children: [
            AnalyticsMetricCard(
              label: 'Gasto no mês',
              value: formatCurrency(currentExpenses),
              detail: expenseChange == null
                  ? 'primeiro mês com lançamentos'
                  : '${expenseChange.abs().toStringAsFixed(0)}% em relação ao mês passado',
              detailColor: (expenseChange ?? 0) > 0
                  ? AppColors.rose600
                  : AppColors.emerald600,
              detailIcon: (expenseChange ?? 0) > 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
            ),
            AnalyticsMetricCard(
              label: 'Média por dia',
              value: formatCurrency(dailyAverage),
              detail: 'nos $dayOfMonth dias já corridos',
              detailColor: AppColors.teal600,
              detailIcon: Icons.calendar_today_rounded,
            ),
            AnalyticsMetricCard(
              label: 'No ritmo atual, fecha em',
              // Usa os dias reais do mês, não 30 fixos.
              value: formatCurrency(dailyAverage * daysInMonth),
              detail: 'projeção para os $daysInMonth dias',
              detailColor: AppColors.teal600,
              detailIcon: Icons.timeline_rounded,
            ),
          ],
        ),
        const SectionGap(),
        TwoColumnSection(
          breakpoint: 1000,
          left: CategoryPieCard(slices: slices),
          right: IncomeExpenseTrendCard(transactions: all),
          leftFlex: 1,
          rightFlex: 1,
        ),
        if (tracked.isNotEmpty) ...[
          const SectionGap(),
          BudgetActualCard(
            labels: tracked.map((budget) => budget.category).toList(),
            budgetValues: tracked.map((budget) => budget.allocated).toList(),
            spentValues: tracked.map((budget) => budget.spent).toList(),
          ),
        ],
        const SectionGap(),
        DailySpendingCard(data: buildDailySpendingData(currentMonth)),
        if (tracked.isNotEmpty) ...[
          const SectionGap(),
          CategoryPerformanceTable(budgets: tracked),
        ],
      ],
    );
  }
}

List<MapEntry<String, double>> buildDailySpendingData(
  Iterable<Transaction> source,
) {
  final byDay = <int, double>{};
  DateTime? anyDate;
  for (final transaction in source.where(
    (transaction) => transaction.type == TransactionKind.expense,
  )) {
    anyDate ??= transaction.date;
    byDay.update(
      transaction.date.day,
      (value) => value + transaction.amount,
      ifAbsent: () => transaction.amount,
    );
  }

  final month = anyDate == null ? '' : ' ${monthAbbreviation(anyDate)}';
  final entries = byDay.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries
      .map((entry) => MapEntry('${entry.key}$month', entry.value))
      .toList();
}

class AnalyticsMetricCard extends StatelessWidget {
  const AnalyticsMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    required this.detailColor,
    required this.detailIcon,
  });

  final String label;
  final String value;
  final String detail;
  final Color detailColor;
  final IconData detailIcon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.accentText(context),
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.teal400,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.primaryText(context),
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(detailIcon, size: 16, color: detailColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  detail,
                  style: TextStyle(color: detailColor, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CategoryPieCard extends StatelessWidget {
  const CategoryPieCard({super.key, required this.slices});

  final List<CategorySlice> slices;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return AppCard(
        child: Text(
          'Sem despesas neste mês.',
          style: TextStyle(color: AppColors.secondaryText(context)),
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gastos por categoria',
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 520;
                final pie = Expanded(
                  child: CategoryPieChart(slices: slices),
                );
                final legend = Expanded(
                  child: ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final slice in slices)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: slice.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  slice.name,
                                  style: TextStyle(
                                    color: AppColors.secondaryText(context),
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                formatCurrency(slice.value, decimals: 0),
                                style: TextStyle(
                                  color: AppColors.primaryText(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );

                return isNarrow
                    ? Column(
                        children: [pie, const SizedBox(height: 12), legend],
                      )
                    : Row(children: [pie, const SizedBox(width: 16), legend]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class IncomeExpenseTrendCard extends StatelessWidget {
  const IncomeExpenseTrendCard({super.key, required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final trend = monthlyTrend(transactions);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tendência de receitas x despesas',
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          const ChartLegend(
            items: [
              LegendItem('Receitas', AppColors.emerald500),
              LegendItem('Gastos', AppColors.rose500),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 300,
            child: LineAreaChart(
              labels: trend.map((point) => point.month).toList(),
              series: [
                ChartSeries(
                  name: 'Receitas',
                  color: AppColors.emerald500,
                  values: trend.map((point) => point.income).toList(),
                ),
                ChartSeries(
                  name: 'Gastos',
                  color: AppColors.rose500,
                  values: trend.map((point) => point.spending).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetActualCard extends StatelessWidget {
  const BudgetActualCard({
    super.key,
    required this.labels,
    required this.budgetValues,
    required this.spentValues,
  });

  final List<String> labels;
  final List<double> budgetValues;
  final List<double> spentValues;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Orçamento x gasto real',
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          const ChartLegend(
            items: [
              LegendItem('Orçamento', FlorgPalette.greenSoft),
              LegendItem('Spent', AppColors.teal500),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 400,
            child: GroupedBarChart(
              labels: labels,
              series: [
                ChartSeries(
                  name: 'Orçamento',
                  color: FlorgPalette.greenSoft,
                  values: budgetValues,
                ),
                ChartSeries(
                  name: 'Spent',
                  color: AppColors.teal500,
                  values: spentValues,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DailySpendingCard extends StatelessWidget {
  const DailySpendingCard({super.key, required this.data});

  final List<MapEntry<String, double>> data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Padrão diário de gastos (abril de 2026)',
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LineAreaChart(
              labels: data.map((entry) => entry.key).toList(),
              series: [
                ChartSeries(
                  name: 'Gasto diário',
                  color: AppColors.teal500,
                  values: data.map((entry) => entry.value).toList(),
                  fill: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryPerformanceTable extends StatelessWidget {
  const CategoryPerformanceTable({super.key, required this.budgets});

  final List<Budget> budgets;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Desempenho por categoria',
              style: TextStyle(
                color: AppColors.primaryText(context),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppColors.tableHeader(context),
              ),
              columnSpacing: 32,
              dataTextStyle: TextStyle(color: AppColors.primaryText(context)),
              headingTextStyle: TextStyle(
                color: AppColors.primaryText(context),
                fontWeight: FontWeight.w700,
              ),
              columns: const [
                DataColumn(label: Text('Categoria')),
                DataColumn(label: Text('Orçamento'), numeric: true),
                DataColumn(label: Text('Gasto'), numeric: true),
                DataColumn(label: Text('Restante'), numeric: true),
                DataColumn(label: Text('% usado'), numeric: true),
                DataColumn(label: Text('Status')),
              ],
              rows: budgets.map((budget) {
                // Categoria sem teto definido tem allocated zero, e a divisao
                // devolvia Infinity na coluna "% usado".
                final percentage = budget.allocated <= 0
                    ? 0.0
                    : budget.spent / budget.allocated * 100;
                final remaining = budget.allocated - budget.spent;
                final isOverBudget = percentage > 100;
                final isWarning = percentage > 80;
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: budget.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            budget.category,
                            style: TextStyle(
                              color: AppColors.primaryText(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(formatCurrency(budget.allocated))),
                    DataCell(Text(formatCurrency(budget.spent))),
                    DataCell(
                      Text(
                        formatCurrency(remaining),
                        style: TextStyle(
                          color: remaining < 0
                              ? context.colors.error
                              : context.colors.textPrimary,
                        ),
                      ),
                    ),
                    DataCell(Text('${percentage.toStringAsFixed(1)}%')),
                    DataCell(
                      BadgePill(
                        label: isOverBudget
                            ? 'Acima do orçamento'
                            : (isWarning ? 'Atenção' : 'No caminho'),
                        background: isOverBudget
                            ? AppColors.rose100
                            : isWarning
                            ? AppColors.amber100
                            : AppColors.emerald100,
                        color: isOverBudget
                            ? AppColors.rose700
                            : isWarning
                            ? AppColors.amber700
                            : AppColors.emerald700,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
