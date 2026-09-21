import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/financial_data_controller.dart';
import '../models/financial_models.dart';
import '../shared/layout.dart';
import './dashboard_screen.dart';
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({
    super.key,
    required this.onSignOut,
    required this.hideBalancesByDefault,
  });

  final VoidCallback onSignOut;
  final bool hideBalancesByDefault;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late bool _showBalances = !widget.hideBalancesByDefault;

  @override
  void didUpdateWidget(covariant AccountsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hideBalancesByDefault != widget.hideBalancesByDefault) {
      _showBalances = !widget.hideBalancesByDefault;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FinancialDataController>();
    final accounts = data.accounts;
    final checkingSavings = accounts
        .where(
          (account) => account.type == 'checking' || account.type == 'savings',
        )
        .fold(0.0, (sum, account) => sum + account.balance);
    final institutions = accounts
        .map((account) => account.institution)
        .toSet()
        .length;

    return PageFrame(
      title: 'Contas',
      subtitle: 'Onde seu dinheiro está hoje.',
      trailing: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlineActionButton(
            label: _showBalances ? 'Ocultar saldos' : 'Mostrar saldos',
            icon: _showBalances
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            onPressed: () => setState(() => _showBalances = !_showBalances),
          ),
          OutlineActionButton(
            label: 'Sincronizar contas',
            icon: Icons.sync_rounded,
            onPressed: () {},
          ),
          OutlineActionButton(
            label: 'Sair',
            icon: Icons.logout_rounded,
            onPressed: widget.onSignOut,
          ),
          SizedBox(
            width: 180,
            child: GradientButton(
              label: 'Conectar conta',
              icon: Icons.add_rounded,
              onPressed: () {},
            ),
          ),
        ],
      ),
      children: [
        ResponsiveWrap(
          minItemWidth: 260,
          maxColumns: 3,
          children: [
            AppCard(
              gradient: tealCyanGradient,
              borderColor: null,
              child: MetricTextBlock(
                label: 'Patrimônio líquido total',
                value: _showBalances ? formatCurrency(totalBalanceOf(accounts)) : '******',
                detail: 'Across ${accounts.length} accounts',
                isLight: true,
              ),
            ),
            AppCard(
              child: MetricTextBlock(
                label: 'Dinheiro e poupança',
                value: _showBalances
                    ? formatCurrency(checkingSavings)
                    : '******',
                detail: 'Liquid assets',
              ),
            ),
            AppCard(
              child: MetricTextBlock(
                label: 'Instituições conectadas',
                value: '$institutions',
                detail: 'Via Open Finance',
              ),
            ),
          ],
        ),
        const SectionGap(),
        Column(
          children: [
            for (final account in accounts) ...[
              AccountCard(
                account: account,
                showBalances: _showBalances,
                transactions: data.transactions,
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
        const ConnectMoreAccountsCard(),
      ],
    );
  }
}

class MetricTextBlock extends StatelessWidget {
  const MetricTextBlock({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    this.isLight = false,
  });

  final String label;
  final String value;
  final String detail;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final labelColor = isLight
        ? FlorgPalette.onAccentMuted
        : context.colors.textSecondary;
    final valueColor = isLight
        ? FlorgPalette.onAccent
        : context.colors.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(detail, style: TextStyle(color: labelColor, fontSize: 14)),
      ],
    );
  }
}

class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.account,
    required this.showBalances,
    required this.transactions,
  });

  final FinancialAccount account;
  final bool showBalances;
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    // Casa por id, nao por nome: duas contas podiam se chamar "Conta Corrente"
    // e uma mostrava o extrato da outra.
    final recentTransactions = transactions
        .where((transaction) => transaction.accountId == account.id)
        .take(5)
        .toList();
    final accountColor = accountAccent(account.type);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(FlorgSpacing.lg),
            // LayoutBuilder e nao Wrap: dentro de um Wrap a largura e
            // ilimitada, entao o nome de uma conta comprida empurrava a linha
            // para fora da tela em vez de quebrar.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 420;
                final identity = _AccountIdentity(
                  account: account,
                  accent: accountColor,
                );
                final balance = _AccountBalance(
                  account: account,
                  showBalances: showBalances,
                  alignEnd: !stacked,
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identity,
                      const SizedBox(height: FlorgSpacing.md),
                      balance,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: FlorgSpacing.md),
                    balance,
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: context.colors.border),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transações recentes',
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (recentTransactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Nenhuma transação recente',
                        style: TextStyle(color: AppColors.accentText(context)),
                      ),
                    ),
                  )
                else
                  for (final transaction in recentTransactions)
                    TransactionListTile(
                      transaction: transaction,
                      hideAmount: !showBalances,
                      showDate: true,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData accountIcon(String type) {
  switch (type) {
    case 'checking':
      return Icons.account_balance_rounded;
    case 'savings':
      return Icons.savings_rounded;
    case 'credit':
      return Icons.credit_card_rounded;
    case 'investment':
      return Icons.trending_up_rounded;
    default:
      return Icons.account_balance_rounded;
  }
}

/// Fundo de 14% do próprio acento: funciona no claro e no escuro sem
/// precisar do contexto, que este helper não recebe.
Color _accent(Color color) => color.withValues(alpha: 0.14);

({Color background, Color foreground}) accountAccent(String type) {
  switch (type) {
    case 'checking':
      return (
        background: _accent(FlorgPalette.green),
        foreground: FlorgPalette.greenSoft,
      );
    case 'savings':
      return (
        background: AppColors.emerald100,
        foreground: AppColors.emerald600,
      );
    case 'credit':
      return (
        background: AppColors.emerald100,
        foreground: AppColors.emerald600,
      );
    case 'investment':
      return (
        background: _accent(FlorgPalette.caution),
        foreground: FlorgPalette.caution,
      );
    default:
      return (
        background: _accent(FlorgPalette.slate),
        foreground: FlorgPalette.mist,
      );
  }
}

class ConnectMoreAccountsCard extends StatelessWidget {
  const ConnectMoreAccountsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gradient: const LinearGradient(
        colors: [FlorgPalette.surfaceRaised, FlorgPalette.surface],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Conectar mais contas',
                style: TextStyle(
                  color: AppColors.primaryText(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Vincule todas as suas contas financeiras pelo Open Finance para ter uma visão completa das suas finanças.',
                style: TextStyle(color: AppColors.secondaryText(context)),
              ),
              SizedBox(height: 16),
              FeatureLine(
                'Conecte-se com segurança a mais de 1000 instituições financeiras',
              ),
              FeatureLine(
                'Sincronização e categorização automática de transações',
              ),
              FeatureLine('Atualizações de saldo em tempo real'),
            ],
          );

          final button = SizedBox(
            width: 220,
            child: GradientButton(
              label: 'Conectar conta',
              icon: Icons.add_rounded,
              onPressed: () {},
              height: 48,
            ),
          );

          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [content, const SizedBox(height: 24), button],
            );
          }

          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 24),
              button,
            ],
          );
        },
      ),
    );
  }
}

class FeatureLine extends StatelessWidget {
  const FeatureLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.accentText(context),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Icone, nome e instituicao da conta.
class _AccountIdentity extends StatelessWidget {
  const _AccountIdentity({required this.account, required this.accent});

  final FinancialAccount account;
  final ({Color background, Color foreground}) accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconTile(
          icon: accountIcon(account.type),
          background: accent.background,
          color: accent.foreground,
        ),
        const SizedBox(width: FlorgSpacing.md),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (account.institution.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  account.institution,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Saldo da conta, oculto quando o usuario pediu para esconder valores.
class _AccountBalance extends StatelessWidget {
  const _AccountBalance({
    required this.account,
    required this.showBalances,
    required this.alignEnd,
  });

  final FinancialAccount account;
  final bool showBalances;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        const SectionLabel('Saldo'),
        const SizedBox(height: FlorgSpacing.xs),
        Text(
          showBalances ? formatCurrency(account.balance) : '••••••',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FlorgText.figure(context, size: 24).copyWith(
            color: account.balance < 0 ? colors.error : colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
