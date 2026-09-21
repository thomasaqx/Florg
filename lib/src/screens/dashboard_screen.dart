import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/analytics.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/auth_controller.dart';
import '../data/financial_data_controller.dart';
import '../models/financial_models.dart';
import '../models/navigation_item.dart';
import '../shared/charts.dart';
import '../shared/layout.dart';
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.onNavigate,
    required this.hideBalances,
    required this.budgetLimits,
  });

  final ValueChanged<int> onNavigate;
  final bool hideBalances;
  final Map<String, double> budgetLimits;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FinancialDataController>();
    final name = context.watch<AuthController>().user?.name ?? '';
    final firstName = name.split(' ').first;

    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final all = data.transactions;

    final thisMonth = transactionsInMonth(all, now);
    final income = totalFor(thisMonth, TransactionKind.income);
    final expenses = totalFor(thisMonth, TransactionKind.expense);

    final before = transactionsInMonth(all, lastMonth);
    final incomeChange = percentChange(
      totalFor(before, TransactionKind.income),
      income,
    );
    final expenseChange = percentChange(
      totalFor(before, TransactionKind.expense),
      expenses,
    );
    final rate = savingsRate(income, expenses);

    return PageFrame(
      title: firstName.isEmpty ? 'Olá' : 'Olá, $firstName',
      subtitle: all.isEmpty
          ? 'Ainda não há lançamentos. Importe um extrato ou cadastre à mão.'
          : '${monthLabel(now)} · ${thisMonth.length} lançamentos no mês',
      children: [
        ResponsiveWrap(
          minItemWidth: 230,
          maxColumns: 4,
          children: [
            StatCard(
              label: 'Saldo total',
              value: hideBalances
                  ? '••••••'
                  : formatCurrency(totalBalanceOf(data.accounts)),
              icon: Icons.account_balance_wallet_rounded,
              iconBackground: context.colors.primaryMuted,
              iconColor: AppColors.teal600,
              footnote: '${data.accounts.length} conta(s)',
            ),
            StatCard(
              label: 'Entrou em ${monthName(now).toLowerCase()}',
              value: hideBalances ? '••••••' : formatCurrency(income),
              icon: Icons.south_west_rounded,
              iconBackground: AppColors.emerald100,
              iconColor: AppColors.emerald600,
              change: incomeChange,
              higherIsBetter: true,
            ),
            StatCard(
              label: 'Saiu em ${monthName(now).toLowerCase()}',
              value: hideBalances ? '••••••' : formatCurrency(expenses),
              icon: Icons.north_east_rounded,
              iconBackground: AppColors.rose100,
              iconColor: AppColors.rose600,
              change: expenseChange,
              higherIsBetter: false,
            ),
            StatCard(
              label: 'Sobrou do que entrou',
              // Sem receita no mês não há percentual: dividir por zero aqui
              // mostrava "NaN%" para quem acabou de criar a conta.
              value: rate == null ? '—' : '${rate.toStringAsFixed(0)}%',
              icon: Icons.savings_rounded,
              iconBackground: AppColors.emerald100,
              iconColor: AppColors.emerald600,
              footnote: rate == null
                  ? 'sem receitas no mês'
                  : formatCurrency(income - expenses),
            ),
          ],
        ),
        const SectionGap(),
        DashboardMainGrid(
          trend: SpendingTrendCard(transactions: all),
          insights: QuickInsightsCard(
            transactions: all,
            budgetLimits: budgetLimits,
            onNavigate: () => onNavigate(AppPage.insights),
          ),
          transactions: RecentTransactionsCard(
            transactions: all.take(8).toList(),
            onViewAll: () => onNavigate(AppPage.transactions),
          ),
        ),
        const SectionGap(),
        BudgetOverviewCard(budgetLimits: budgetLimits, transactions: all),
      ],
    );
  }
}

class DashboardMainGrid extends StatelessWidget {
  const DashboardMainGrid({
    super.key,
    required this.trend,
    required this.insights,
    required this.transactions,
  });

  final Widget trend;
  final Widget insights;
  final Widget transactions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1050) {
          return Column(
            children: [
              trend,
              const SizedBox(height: 24),
              insights,
              const SizedBox(height: 24),
              transactions,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [trend, const SizedBox(height: 24), insights],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(flex: 2, child: transactions),
          ],
        );
      },
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    this.change,
    this.higherIsBetter = true,
    this.footnote,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;

  /// Variação em relação ao mês anterior. Null quando não há mês anterior para
  /// comparar, e nesse caso o rodapé some em vez de mostrar um número inventado.
  final double? change;

  /// Se subir é bom (receita) ou ruim (despesa), para escolher a cor.
  final bool higherIsBetter;

  /// Texto alternativo quando não existe variação para mostrar.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                icon: icon,
                background: iconBackground,
                color: iconColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.secondaryText(context),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          color: AppColors.primaryText(context),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (change != null)
            Builder(
              builder: (context) {
                final rose = change! > 0;
                final good = rose == higherIsBetter;
                final color = good
                    ? AppColors.emerald600
                    : AppColors.rose600;
                return Row(
                  children: [
                    Icon(
                      rose
                          ? Icons.north_east_rounded
                          : Icons.south_east_rounded,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${change!.abs().toStringAsFixed(0)}%',
                      style: TextStyle(color: color, fontSize: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'vs mês anterior',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.accentText(context),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                );
              },
            )
          else
            Text(
              footnote ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.accentText(context),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.background,
    required this.color,
    this.size = 48,
    this.iconSize = 24,
  });

  final IconData icon;
  final Color background;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class SpendingTrendCard extends StatelessWidget {
  const SpendingTrendCard({super.key, required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final trend = monthlyTrend(transactions);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tendência de gastos',
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.subtleFill(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Text(
                  'últimos 7 meses',
                  style: TextStyle(
                    color: AppColors.secondaryText(context),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ChartLegend(
            items: [
              LegendItem('Receitas', AppColors.teal500),
              LegendItem('Despesas', AppColors.rose500),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 270,
            child: LineAreaChart(
              labels: trend.map((point) => point.month).toList(),
              series: [
                ChartSeries(
                  name: 'Receitas',
                  color: AppColors.teal500,
                  values: trend.map((point) => point.income).toList(),
                  fill: true,
                ),
                ChartSeries(
                  name: 'Despesas',
                  color: AppColors.rose500,
                  values: trend.map((point) => point.spending).toList(),
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

class QuickInsightsCard extends StatelessWidget {
  const QuickInsightsCard({
    super.key,
    required this.transactions,
    required this.budgetLimits,
    required this.onNavigate,
  });

  final List<Transaction> transactions;
  final Map<String, double> budgetLimits;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final observations = observationsFor(transactions, limits: budgetLimits);
    final biggest = categoryBreakdownOf(transactions);

    return AppCard(
      gradient: tealCyanGradient,
      borderColor: null,
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                // Flexible: no celular o título não cabe ao lado do ícone e a
                // Row estourava 126px para fora da tela.
                Flexible(
                  child: Text(
                    'O mês em poucas linhas',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final savings = _InsightSavings(slices: biggest);
                final opportunities = _InsightOpportunities(
                  observations: observations,
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      savings,
                      const Divider(height: 28, color: FlorgPalette.onAccentLine),
                      opportunities,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: savings),
                    const SizedBox(
                      height: 82,
                      child: VerticalDivider(color: FlorgPalette.onAccentLine),
                    ),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: opportunities),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onNavigate,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.teal600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Abrir insights'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightSavings extends StatelessWidget {
  const _InsightSavings({required this.slices});

  final List<CategorySlice> slices;

  @override
  Widget build(BuildContext context) {
    final top = slices.isEmpty ? null : slices.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          top == null ? 'Maior gasto do mês' : 'Mais gasto: ${top.name}',
          style: const TextStyle(fontSize: 13, color: FlorgPalette.onAccentMuted),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            top == null ? '—' : formatCurrency(top.value),
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _InsightOpportunities extends StatelessWidget {
  const _InsightOpportunities({required this.observations});

  final List<Insight> observations;

  @override
  Widget build(BuildContext context) {
    if (observations.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nada fora do padrão',
            style: TextStyle(fontSize: 13, color: FlorgPalette.onAccentMuted),
          ),
          SizedBox(height: 8),
          OpportunityLine(
            'Com mais alguns meses de extrato dá para comparar gastos.',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'O que chamou atenção',
          style: TextStyle(fontSize: 13, color: FlorgPalette.onAccentMuted),
        ),
        const SizedBox(height: 8),
        for (final item in observations.take(3)) OpportunityLine(item.title),
      ],
    );
  }
}

class OpportunityLine extends StatelessWidget {
  const OpportunityLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 8, right: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class RecentTransactionsCard extends StatelessWidget {
  const RecentTransactionsCard({
    super.key,
    required this.transactions,
    required this.onViewAll,
  });

  final List<Transaction> transactions;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Transações recentes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onViewAll, child: Text('Ver tudo')),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < transactions.length; i++) ...[
            TransactionListTile(transaction: transactions[i]),
            if (i != transactions.length - 1)
              Divider(height: 1, color: AppColors.border(context)),
          ],
        ],
      ),
    );
  }
}

class TransactionListTile extends StatelessWidget {
  const TransactionListTile({
    super.key,
    required this.transaction,
    this.showDate = false,
    this.hideAmount = false,
  });

  final Transaction transaction;
  final bool showDate;
  final bool hideAmount;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionKind.income;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconTile(
            icon: isIncome
                ? Icons.south_east_rounded
                : Icons.north_east_rounded,
            background: isIncome ? AppColors.emerald100 : AppColors.rose100,
            color: isIncome ? AppColors.emerald600 : AppColors.rose600,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  showDate
                      ? '${transaction.category} - ${formatDate(transaction.date)}'
                      : transaction.category,
                  style: TextStyle(
                    color: AppColors.accentText(context),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            hideAmount ? '****' : formatTransactionAmount(transaction),
            style: TextStyle(
              color: isIncome ? AppColors.emerald600 : AppColors.rose600,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetOverviewCard extends StatelessWidget {
  const BudgetOverviewCard({
    super.key,
    required this.budgetLimits,
    required this.transactions,
  });

  final Map<String, double> budgetLimits;
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    // O teto vem das configurações; o gasto vem do extrato do mês corrente.
    final tracked = budgetsFor(transactions, limits: budgetLimits);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Visão geral do orçamento',
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.subtleFill(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Text(
                  monthLabel(DateTime.now()),
                  style: TextStyle(
                    color: AppColors.secondaryText(context),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (tracked.isEmpty)
            Text(
              'Sem despesas neste mês para acompanhar.',
              style: TextStyle(color: AppColors.secondaryText(context)),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1100
                    ? 6
                    : constraints.maxWidth >= 680
                    ? 3
                    : 1;
                const spacing = 20.0;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: 20,
                  children: [
                    for (final budget in tracked.take(6))
                      SizedBox(
                        width: width,
                        child: BudgetProgressRow(budget: budget),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class BudgetProgressRow extends StatelessWidget {
  const BudgetProgressRow({super.key, required this.budget});

  final Budget budget;

  @override
  Widget build(BuildContext context) {
    // allocated pode ser zero numa categoria sem teto: a divisão devolveria
    // Infinity e a barra de progresso quebrava.
    final percentage =
        budget.allocated <= 0 ? 0.0 : budget.spent / budget.allocated * 100;
    final isOverBudget = percentage > 100;
    final icon = switch (budget.category) {
      'Moradia' => Icons.home_rounded,
      'Mercado' => Icons.shopping_cart_rounded,
      'Transporte' => Icons.directions_car_rounded,
      'Alimentação' => Icons.restaurant_rounded,
      'Entretenimento' => Icons.sports_esports_rounded,
      'Compras' => Icons.shopping_bag_rounded,
      _ => Icons.pie_chart_rounded,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.subtleFill(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: budget.color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    budget.category,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.primaryText(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${formatCurrency(budget.spent, decimals: 0)} / ${formatCurrency(budget.allocated, decimals: 0)}',
                      style: TextStyle(
                        color: isOverBudget
                            ? AppColors.rose600
                            : AppColors.secondaryText(context),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: math.min(percentage, 100) / 100,
                  minHeight: 7,
                  backgroundColor: AppColors.subtleFill(context),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverBudget ? AppColors.rose500 : AppColors.teal500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percentage.round()}%',
              style: TextStyle(
                color: isOverBudget
                    ? AppColors.rose600
                    : AppColors.secondaryText(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
