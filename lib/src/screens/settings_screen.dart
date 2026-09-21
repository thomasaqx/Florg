import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../core/analytics.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/auth_controller.dart';
import '../data/budget_controller.dart';
import '../data/financial_data_controller.dart';
import '../models/financial_models.dart';
import '../shared/layout.dart';
import './dashboard_screen.dart';
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onSignOut,
    required this.transactionAlerts,
    required this.weeklySummary,
    required this.budgetAlerts,
    required this.hideBalances,
    required this.onTransactionAlertsChanged,
    required this.onWeeklySummaryChanged,
    required this.onBudgetAlertsChanged,
    required this.onHideBalancesChanged,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;
  final bool transactionAlerts;
  final bool weeklySummary;
  final bool budgetAlerts;
  final bool hideBalances;
  final ValueChanged<bool> onTransactionAlertsChanged;
  final ValueChanged<bool> onWeeklySummaryChanged;
  final ValueChanged<bool> onBudgetAlertsChanged;
  final ValueChanged<bool> onHideBalancesChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Mês corrente e os dois anteriores, em vez de três meses fixos no código.
  late final List<String> _months = [
    for (var back = 0; back < 3; back++)
      monthLabel(DateTime(DateTime.now().year, DateTime.now().month - back)),
  ];
  late String _selectedMonth = _months.first;

  /// Converte "Abril de 2026" de volta num DateTime, para filtrar o extrato.
  DateTime _monthOf(String label) {
    final now = DateTime.now();
    for (var back = 0; back < 3; back++) {
      final candidate = DateTime(now.year, now.month - back);
      if (monthLabel(candidate) == label) return candidate;
    }
    return now;
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preferências salvas.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Configurações',
      subtitle: 'Preferências do app e tetos de gasto por categoria.',
      trailing: FilledButton.icon(
        onPressed: _saveSettings,
        icon: const Icon(Icons.check_rounded, size: 18),
        label: const Text('Salvar alterações'),
      ),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 920;
            final profile = _ProfileSettingsCard(
              transactionAlerts: widget.transactionAlerts,
              weeklySummary: widget.weeklySummary,
              budgetAlerts: widget.budgetAlerts,
              hideBalances: widget.hideBalances,
              isDarkMode: widget.isDarkMode,
              onTransactionAlertsChanged: widget.onTransactionAlertsChanged,
              onWeeklySummaryChanged: widget.onWeeklySummaryChanged,
              onBudgetAlertsChanged: widget.onBudgetAlertsChanged,
              onHideBalancesChanged: widget.onHideBalancesChanged,
              onToggleTheme: widget.onToggleTheme,
            );
            final account = _AccountSettingsCard(onSignOut: widget.onSignOut);

            if (compact) {
              return Column(
                children: [profile, const SizedBox(height: 24), account],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: profile),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: account),
              ],
            );
          },
        ),
        const SectionGap(),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Orçamentos mensais',
                        style: TextStyle(
                          color: AppColors.primaryText(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quanto você pretende gastar em cada categoria.',
                        style: TextStyle(
                          color: AppColors.secondaryText(context),
                        ),
                      ),
                    ],
                  ),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedMonth,
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      for (final month in _months)
                        DropdownMenuItem(value: month, child: Text(month)),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedMonth = value);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Builder(
                builder: (context) {
                  // As categorias vêm da API, então a lista acompanha o que o
                  // usuário realmente tem lançado.
                  final data = context.watch<FinancialDataController>();
                  final budgets = context.watch<BudgetController>();
                  final month = _monthOf(_selectedMonth);
                  final limits = budgets.limitsFor(
                    data.categories,
                    month: month,
                  );
                  final tracked = budgetsFor(
                    data.transactions,
                    limits: limits,
                    month: month,
                  );
                  final names = {
                    ...data.categories.map((item) => item.name),
                    ...tracked.map((item) => item.category),
                  }.toList()..sort();

                  if (names.isEmpty) {
                    return Text(
                      'Assim que houver categorias lançadas elas aparecem aqui.',
                      style: TextStyle(
                        color: AppColors.secondaryText(context),
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 900 ? 2 : 1;
                      const spacing = 20.0;
                      final itemWidth =
                          (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: 16,
                        children: [
                          for (final name in names)
                            SizedBox(
                              width: itemWidth,
                              child: _BudgetSettingRow(
                                budget: tracked.firstWhere(
                                  (item) => item.category == name,
                                  orElse: () => Budget(
                                    category: name,
                                    allocated: limits[name] ?? 0,
                                    spent: 0,
                                    color: colorForCategory(name),
                                  ),
                                ),
                                // Categoria ainda sem teto começa em zero em vez
                                // de estourar num "!" sobre chave inexistente.
                                value: limits[name] ?? 0,
                                // Grava no servidor. Zero apaga o teto, que é
                                // o que "sem limite" quer dizer.
                                onChanged: (value) => budgets.setLimit(
                                  categories: data.categories,
                                  categoryName: name,
                                  month: month,
                                  limitAmount: value,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileSettingsCard extends StatelessWidget {
  const _ProfileSettingsCard({
    required this.transactionAlerts,
    required this.weeklySummary,
    required this.budgetAlerts,
    required this.hideBalances,
    required this.isDarkMode,
    required this.onTransactionAlertsChanged,
    required this.onWeeklySummaryChanged,
    required this.onBudgetAlertsChanged,
    required this.onHideBalancesChanged,
    required this.onToggleTheme,
  });

  final bool transactionAlerts;
  final bool weeklySummary;
  final bool budgetAlerts;
  final bool hideBalances;
  final bool isDarkMode;
  final ValueChanged<bool> onTransactionAlertsChanged;
  final ValueChanged<bool> onWeeklySummaryChanged;
  final ValueChanged<bool> onBudgetAlertsChanged;
  final ValueChanged<bool> onHideBalancesChanged;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsSectionHeader(
            icon: Icons.tune_rounded,
            title: 'Preferências do usuário',
            subtitle: 'Aparência, privacidade e comunicações',
          ),
          _SettingsSwitch(
            icon: isDarkMode
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            title: 'Modo escuro',
            subtitle: isDarkMode ? 'Tema escuro ativado' : 'Tema claro ativado',
            value: isDarkMode,
            onChanged: (_) => onToggleTheme(),
          ),
          _SettingsSwitch(
            icon: Icons.receipt_long_rounded,
            title: 'Alertas de transações',
            subtitle: 'Avise quando houver uma nova movimentação',
            value: transactionAlerts,
            onChanged: onTransactionAlertsChanged,
          ),
          _SettingsSwitch(
            icon: Icons.summarize_rounded,
            title: 'Resumo semanal',
            subtitle: 'Receba um resumo dos seus gastos toda semana',
            value: weeklySummary,
            onChanged: onWeeklySummaryChanged,
          ),
          _SettingsSwitch(
            icon: Icons.warning_amber_rounded,
            title: 'Alertas de orçamento',
            subtitle: 'Avise ao atingir 80% do limite mensal',
            value: budgetAlerts,
            onChanged: onBudgetAlertsChanged,
          ),
          _SettingsSwitch(
            icon: Icons.visibility_off_rounded,
            title: 'Ocultar saldos por padrão',
            subtitle: 'Proteja seus valores ao abrir o aplicativo',
            value: hideBalances,
            onChanged: onHideBalancesChanged,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

/// Perfil de quem esta logado, gravado em PATCH /auth/me.
///
/// Antes os campos vinham preenchidos com "Florg" e "ana@florg.com" e o que
/// se digitasse neles nao ia a lugar nenhum.
class _AccountSettingsCard extends StatefulWidget {
  const _AccountSettingsCard({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  State<_AccountSettingsCard> createState() => _AccountSettingsCardState();
}

class _AccountSettingsCardState extends State<_AccountSettingsCard> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController? _name;
  TextEditingController? _email;
  String? _loadedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Os campos sao preenchidos quando o usuario chega (ou troca): montar o
    // controller no initState pegaria a sessao ainda em branco.
    final user = context.watch<AuthController>().user;
    if (user == null || user.id == _loadedUserId) return;
    _loadedUserId = user.id;
    _name?.dispose();
    _email?.dispose();
    _name = TextEditingController(text: user.name);
    _email = TextEditingController(text: user.email);
  }

  @override
  void dispose() {
    _name?.dispose();
    _email?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthController>();
    final saved = await auth.updateProfile(
      name: _name!.text.trim(),
      email: _email!.text.trim(),
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Perfil atualizado.'
              : auth.errorMessage ?? 'Não consegui salvar o perfil.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _SettingsSectionHeader(
            icon: Icons.person_outline_rounded,
            title: 'Perfil e conta',
            subtitle: 'Seus dados pessoais e segurança',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: _name == null
                ? const Center(child: CircularProgressIndicator())
                : Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Nome de exibição',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              (value ?? '').trim().isEmpty
                              ? 'Informe seu nome.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final email = (value ?? '').trim();
                            if (email.isEmpty) return 'Informe seu e-mail.';
                            if (!email.contains('@') || !email.contains('.')) {
                              return 'E-mail inválido.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const ValueKey('save-profile'),
                            onPressed: auth.isSubmitting ? null : _save,
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              auth.isSubmitting ? 'Salvando...' : 'Salvar perfil',
                            ),
                          ),
                        ),
                        const SizedBox(height: FlorgSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: widget.onSignOut,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Sair da conta'),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconTile(
            icon: icon,
            background: context.colors.primaryMuted,
            color: AppColors.teal600,
            size: 42,
            iconSize: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.secondaryText(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(icon, color: AppColors.accentText(context)),
          title: Text(
            title,
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 12,
            ),
          ),
          value: value,
          onChanged: onChanged,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: AppColors.border(context),
          ),
      ],
    );
  }
}

class _BudgetSettingRow extends StatelessWidget {
  const _BudgetSettingRow({
    required this.budget,
    required this.value,
    required this.onChanged,
  });

  final Budget budget;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.subtleFill(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: budget.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  budget.category,
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatCurrency(value, decimals: 0),
                style: TextStyle(
                  color: AppColors.primaryText(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: math.max(500, budget.allocated * 2),
            divisions: 20,
            label: formatCurrency(value, decimals: 0),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
