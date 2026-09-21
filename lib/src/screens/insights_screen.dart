import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/analytics.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/financial_data_controller.dart';
import '../models/financial_models.dart';
import '../shared/layout.dart';
import './dashboard_screen.dart';
import './transactions_screen.dart';

/// Observações sobre o mês, calculadas a partir do extrato do usuário.
///
/// Cada item aponta um número que está nos lançamentos dele. Recomendação
/// gerada por modelo entra na Fase 3, e até lá nada aqui é estimado.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key, this.budgetLimits = const {}});

  final Map<String, double> budgetLimits;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FinancialDataController>();
    final all = data.transactions;
    final now = DateTime.now();

    final observations = observationsFor(all, limits: budgetLimits);
    final warnings = observations
        .where((item) => item.type == InsightKind.warning)
        .toList();
    final wins = observations
        .where((item) => item.type == InsightKind.success)
        .toList();
    final notes = observations
        .where((item) => item.type == InsightKind.info)
        .toList();

    final categories = categoryBreakdownOf(all, month: now);
    final monthExpenses = categories.fold<double>(
      0,
      (sum, slice) => sum + slice.value,
    );
    final recurring = recurringCandidates(all);
    final recurringTotal = recurring.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    if (all.isEmpty) {
      return const PageFrame(
        title: 'Insights',
        subtitle: 'Precisa de extrato para ter o que analisar.',
        children: [_EmptyInsights()],
      );
    }

    return PageFrame(
      title: 'Insights',
      subtitle: '${monthLabel(now)}, a partir dos seus lançamentos.',
      children: [
        ResponsiveWrap(
          minItemWidth: 260,
          maxColumns: 3,
          children: [
            GradientMetricCard(
              title: 'Gasto no mês',
              value: formatCurrency(monthExpenses),
              detail: '${categories.length} categoria(s)',
              icon: Icons.pie_chart_rounded,
              gradient: tealEmeraldGradient,
            ),
            GradientMetricCard(
              title: 'Maior categoria',
              value: categories.isEmpty
                  ? '—'
                  : formatCurrency(categories.first.value),
              detail: categories.isEmpty ? 'sem despesas' : categories.first.name,
              icon: Icons.leaderboard_rounded,
              gradient: const LinearGradient(
                colors: [AppColors.amber500, AppColors.amber700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            GradientMetricCard(
              title: 'Cobranças que se repetem',
              value: formatCurrency(recurringTotal),
              detail: '${recurring.length} por mês',
              icon: Icons.autorenew_rounded,
              gradient: const LinearGradient(
                colors: [FlorgPalette.greenSoft, FlorgPalette.green],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ],
        ),
        const SectionGap(),
        if (observations.isEmpty) const _NothingUnusual(),
        InsightSection(
          title: 'Pontos de atenção',
          countText: '${warnings.length}',
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.amber600,
          badgeBackground: AppColors.amber100,
          badgeColor: AppColors.amber700,
          insights: warnings,
        ),
        if (wins.isNotEmpty) ...[
          const SectionGap(),
          InsightSection(
            title: 'Melhorou em relação ao mês passado',
            countText: '${wins.length}',
            icon: Icons.trending_up_rounded,
            iconColor: AppColors.emerald600,
            badgeBackground: AppColors.emerald100,
            badgeColor: AppColors.emerald700,
            insights: wins,
          ),
        ],
        if (notes.isNotEmpty) ...[
          const SectionGap(),
          InsightSection(
            title: 'Vale olhar',
            countText: '${notes.length}',
            icon: Icons.lightbulb_outline_rounded,
            iconColor: AppColors.emerald600,
            badgeBackground: AppColors.emerald100,
            badgeColor: AppColors.emerald600,
            insights: notes,
          ),
        ],
        if (recurring.isNotEmpty) ...[
          const SectionGap(),
          RecurringExpensesCard(expenses: recurring),
        ],
      ],
    );
  }
}

class _EmptyInsights extends StatelessWidget {
  const _EmptyInsights();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: Icons.insights_rounded,
            background: context.colors.primaryMuted,
            color: context.colors.secondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Nada para analisar ainda',
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Importe o extrato do banco ou lance algumas despesas à mão. '
            'Com dois meses de histórico dá para comparar um mês com o outro.',
            style: TextStyle(
              color: AppColors.secondaryText(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NothingUnusual extends StatelessWidget {
  const _NothingUnusual();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const IconTile(
            icon: Icons.check_circle_outline_rounded,
            background: AppColors.emerald100,
            color: AppColors.emerald600,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nenhuma categoria estourou o limite nem subiu muito em relação '
              'ao mês passado.',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GradientMetricCard extends StatelessWidget {
  const GradientMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.gradient,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gradient: gradient,
      borderColor: null,
      child: DefaultTextStyle(
        style: TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: FlorgPalette.onAccentMuted),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: TextStyle(fontSize: 14, color: FlorgPalette.onAccentMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class InsightSection extends StatelessWidget {
  const InsightSection({
    super.key,
    required this.title,
    required this.countText,
    required this.icon,
    required this.iconColor,
    required this.badgeBackground,
    required this.badgeColor,
    required this.insights,
  });

  final String title;
  final String countText;
  final IconData icon;
  final Color iconColor;
  final Color badgeBackground;
  final Color badgeColor;
  final List<Insight> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 22),
            Text(
              title,
              style: TextStyle(
                color: AppColors.primaryText(context),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            BadgePill(
              label: countText,
              background: badgeBackground,
              color: badgeColor,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveWrap(
          minItemWidth: 360,
          maxColumns: 2,
          spacing: 16,
          children: insights
              .map(
                (insight) => InsightCard(
                  insight: insight,
                  accentColor: iconColor,
                  icon: insightIcon(insight.type),
                  iconBackground: badgeBackground,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

IconData insightIcon(InsightKind kind) {
  switch (kind) {
    case InsightKind.warning:
      return Icons.warning_amber_rounded;
    case InsightKind.success:
      return Icons.trending_up_rounded;
    case InsightKind.info:
      return Icons.info_outline_rounded;
  }
}

class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.insight,
    required this.accentColor,
    required this.icon,
    required this.iconBackground,
  });

  final Insight insight;
  final Color accentColor;
  final IconData icon;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: accentColor.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                icon: icon,
                background: iconBackground,
                color: accentColor,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      style: TextStyle(
                        color: AppColors.primaryText(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    BadgePill(label: insight.category),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            insight.description,
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (insight.potentialSavings != null) ...[
            Divider(height: 32, color: context.colors.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Diferença',
                    style: TextStyle(
                      color: AppColors.accentText(context),
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  formatCurrency(insight.potentialSavings!),
                  style: TextStyle(
                    color: AppColors.emerald600,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Cobranças com mesma descrição e mesmo valor em pelo menos dois meses.
///
/// Substituiu um card de "gastos desnecessários" que dependia de uma flag
/// preenchida à mão no mock: o app não tem como saber o que é supérfluo, mas
/// sabe o que se repete.
class RecurringExpensesCard extends StatelessWidget {
  const RecurringExpensesCard({super.key, required this.expenses});

  final List<Transaction> expenses;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cobranças que se repetem todo mês',
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final transaction in expenses.take(10))
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.colors.border),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    const IconTile(
                      icon: Icons.autorenew_rounded,
                      background: AppColors.emerald100,
                      color: AppColors.emerald600,
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
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${transaction.category} - ${formatDate(transaction.date)}',
                            style: TextStyle(
                              color: AppColors.accentText(context),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatCurrency(transaction.amount),
                          style: TextStyle(
                            color: AppColors.primaryText(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'por mês',
                          style: TextStyle(
                            color: AppColors.accentText(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (expenses.length > 10) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {},
                child: Text('Ver todas as ${expenses.length} cobranças'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
