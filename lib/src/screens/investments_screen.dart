import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/analytics.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/financial_data_controller.dart';
import '../models/financial_models.dart';
import '../shared/layout.dart';
import './dashboard_screen.dart';
class InvestmentsScreen extends StatelessWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FinancialDataController>();
    final monthTransactions = transactionsInMonth(data.transactions, DateTime.now());
    final income = totalFor(monthTransactions, TransactionKind.income);
    final expenses = totalFor(monthTransactions, TransactionKind.expense);
    final availableToInvest = math.max(0.0, income - expenses);
    final leftoverRate = income == 0 ? 0.0 : availableToInvest / income * 100;
    // Detecta o que se repete pelo historico, em vez de ler uma flag que so o
    // mock preenchia e que em dado real vinha sempre falsa.
    final recurringExpenses = recurringCandidates(
      data.transactions,
    ).fold(0.0, (sum, transaction) => sum + transaction.amount);
    final reserveMonths = expenses == 0 ? 0.0 : totalBalanceOf(data.accounts) / expenses;
    final categoryTotals = <String, double>{};
    for (final transaction in monthTransactions.where(
      (transaction) => transaction.type == TransactionKind.expense,
    )) {
      categoryTotals.update(
        transaction.category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final profile = _buildInvestmentProfile(
      savingsRate: leftoverRate,
      recurringShare: expenses == 0 ? 0 : recurringExpenses / expenses,
      reserveMonths: reserveMonths,
    );
    final recommendations = _buildRecommendations(
      availableToInvest: availableToInvest,
      reserveMonths: reserveMonths,
    );

    return PageFrame(
      title: 'Investimentos',
      subtitle: 'Quanto sobra por mês e quanto tempo a reserva cobre.',
      children: [
        AppCard(
          gradient: const LinearGradient(
            colors: [FlorgPalette.green, FlorgPalette.greenDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderColor: null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final introduction = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Como está seu mês',
                    style: TextStyle(color: FlorgPalette.onAccentMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    profile.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    profile.description,
                    style: const TextStyle(
                      color: FlorgPalette.onAccentMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              );
              final metrics = Wrap(
                spacing: 24,
                runSpacing: 18,
                children: [
                  _InvestmentHeroMetric(
                    label: 'Sobrou',
                    value: formatCurrency(availableToInvest),
                  ),
                  _InvestmentHeroMetric(
                    label: 'Sobra do mês',
                    value: '${leftoverRate.toStringAsFixed(0)}%',
                  ),
                  _InvestmentHeroMetric(
                    label: 'Reserva cobre',
                    value: '${reserveMonths.toStringAsFixed(1)} meses',
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    introduction,
                    const Divider(height: 32, color: FlorgPalette.onAccentLine),
                    metrics,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: introduction),
                  const SizedBox(width: 40),
                  Expanded(flex: 3, child: metrics),
                ],
              );
            },
          ),
        ),
        const SectionGap(),
        TwoColumnSection(
          left: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estratégia recomendada',
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Distribuição mensal sugerida para o valor disponível.',
                  style: TextStyle(color: AppColors.secondaryText(context)),
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < recommendations.length; i++) ...[
                  _RecommendationTile(recommendation: recommendations[i]),
                  if (i != recommendations.length - 1)
                    Divider(height: 25, color: AppColors.border(context)),
                ],
              ],
            ),
          ),
          right: Column(
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Como você gasta',
                      style: TextStyle(
                        color: AppColors.primaryText(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final entry in sortedCategories.take(4))
                      _SpendingSignalRow(
                        category: entry.key,
                        value: entry.value,
                        total: expenses,
                      ),
                    Divider(height: 24, color: AppColors.border(context)),
                    _SignalSummary(
                      icon: Icons.autorenew_rounded,
                      label: 'Gastos recorrentes',
                      value: formatCurrency(recurringExpenses),
                    ),
                    const SizedBox(height: 12),
                    _SignalSummary(
                      icon: Icons.receipt_long_rounded,
                      label: 'Despesas do mês',
                      value: formatCurrency(expenses),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _InvestmentDisclaimer(),
            ],
          ),
          breakpoint: 980,
        ),
      ],
    );
  }
}

({String title, String description}) _buildInvestmentProfile({
  required double savingsRate,
  required double recurringShare,
  required double reserveMonths,
}) {
  if (savingsRate >= 30 && reserveMonths >= 6 && recurringShare < 0.7) {
    return (
      title: 'Sobra folgada e reserva formada',
      description:
          'Sobra mais de 30% do que entra e o saldo das contas cobre seis meses de despesa.',
    );
  }
  if (reserveMonths < 6) {
    return (
      title: 'Reserva ainda abaixo de seis meses',
      description:
          'O saldo das contas cobre menos de seis meses de despesa no ritmo atual.',
    );
  }
  return (
    title: 'Reserva formada, sobra apertada',
    description:
        'A reserva já cobre seis meses, mas a margem que sobra todo mês é curta.',
  );
}

List<_InvestmentRecommendation> _buildRecommendations({
  required double availableToInvest,
  required double reserveMonths,
}) {
  final reserveWeight = reserveMonths < 6 ? 0.7 : 0.2;
  final inflationWeight = reserveMonths < 6 ? 0.2 : 0.35;
  final growthWeight = 1 - reserveWeight - inflationWeight;
  return [
    _InvestmentRecommendation(
      title: 'Liquidez e reserva',
      examples: 'o que dá para resgatar a qualquer momento',
      percentage: reserveWeight,
      amount: availableToInvest * reserveWeight,
      color: AppColors.teal500,
      icon: Icons.shield_outlined,
    ),
    _InvestmentRecommendation(
      title: 'Proteção contra inflação',
      examples: 'o que acompanha a alta de preços no longo prazo',
      percentage: inflationWeight,
      amount: availableToInvest * inflationWeight,
      color: FlorgPalette.greenSoft,
      icon: Icons.trending_up_rounded,
    ),
    _InvestmentRecommendation(
      title: 'Crescimento',
      examples: 'o que oscila mais e pede prazo longo',
      percentage: growthWeight,
      amount: availableToInvest * growthWeight,
      color: FlorgPalette.greenBright,
      icon: Icons.public_rounded,
    ),
  ];
}

class _InvestmentRecommendation {
  const _InvestmentRecommendation({
    required this.title,
    required this.examples,
    required this.percentage,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String title;
  final String examples;
  final double percentage;
  final double amount;
  final Color color;
  final IconData icon;
}

class _InvestmentHeroMetric extends StatelessWidget {
  const _InvestmentHeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: FlorgPalette.onAccentSubtle, fontSize: 12),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.recommendation});

  final _InvestmentRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile(
          icon: recommendation.icon,
          background: recommendation.color.withValues(alpha: 0.14),
          color: recommendation.color,
          size: 44,
          iconSize: 22,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recommendation.title,
                      style: TextStyle(
                        color: AppColors.primaryText(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${(recommendation.percentage * 100).round()}%',
                    style: TextStyle(
                      color: recommendation.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                recommendation.examples,
                style: TextStyle(
                  color: AppColors.secondaryText(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: recommendation.percentage,
                        minHeight: 7,
                        backgroundColor: AppColors.subtleFill(context),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          recommendation.color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatCurrency(recommendation.amount),
                    style: TextStyle(
                      color: AppColors.primaryText(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpendingSignalRow extends StatelessWidget {
  const _SpendingSignalRow({
    required this.category,
    required this.value,
    required this.total,
  });

  final String category;
  final double value;
  final double total;

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : value / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(color: AppColors.primaryText(context)),
                ),
              ),
              Text(
                '${(share * 100).round()}%',
                style: TextStyle(
                  color: AppColors.secondaryText(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 6,
              backgroundColor: AppColors.subtleFill(context),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.teal500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalSummary extends StatelessWidget {
  const _SignalSummary({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.accentText(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.secondaryText(context)),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.primaryText(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InvestmentDisclaimer extends StatelessWidget {
  const _InvestmentDisclaimer();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.subtleFill(context),
      shadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: AppColors.accentText(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'O FLORG não é consultor de investimentos e não indica produtos. '
              'As faixas acima são um ponto de partida para estudo, calculadas '
              'só com o que entrou e saiu das suas contas.',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
