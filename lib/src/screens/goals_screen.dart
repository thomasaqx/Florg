import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/financial_data_controller.dart';
import '../data/goals_controller.dart';
import '../models/financial_models.dart';
import '../models/goal_models.dart';
import '../shared/layout.dart';
import './accounts_screen.dart';
import './dashboard_screen.dart';
import './transactions_screen.dart';

/// Ícone da meta.
///
/// O backend guarda a chave como texto livre, então um ícone novo aqui não
/// pede migração. Um valor desconhecido cai em [GoalIcon.outro].
enum GoalIcon { viagem, casa, carro, educacao, emergencia, presente, outro }

extension GoalIconX on GoalIcon {
  IconData get data => switch (this) {
    GoalIcon.viagem => Icons.flight_takeoff_rounded,
    GoalIcon.casa => Icons.home_rounded,
    GoalIcon.carro => Icons.directions_car_rounded,
    GoalIcon.educacao => Icons.school_rounded,
    GoalIcon.emergencia => Icons.health_and_safety_rounded,
    GoalIcon.presente => Icons.card_giftcard_rounded,
    GoalIcon.outro => Icons.star_rounded,
  };

  String get label => switch (this) {
    GoalIcon.viagem => 'Viagem',
    GoalIcon.casa => 'Casa',
    GoalIcon.carro => 'Carro',
    GoalIcon.educacao => 'Educação',
    GoalIcon.emergencia => 'Emergência',
    GoalIcon.presente => 'Presente',
    GoalIcon.outro => 'Outro',
  };
}

GoalIcon goalIconFrom(String? key) {
  return GoalIcon.values.firstWhere(
    (item) => item.name == key,
    orElse: () => GoalIcon.outro,
  );
}

extension GoalPriorityStyle on GoalPriority {
  Color color(BuildContext context) => switch (this) {
    GoalPriority.low => context.colors.textSecondary,
    GoalPriority.medium => context.colors.secondary,
    GoalPriority.high => context.colors.warning,
  };

  Color background(BuildContext context) =>
      color(context).withValues(alpha: 0.14);
}

enum _GoalStatusFilter { todas, emAndamento, concluidas }

/// Uma meta com a conta vinculada já resolvida.
///
/// Existe para o card não precisar procurar a conta no meio do build: o
/// progresso de uma meta vinculada é o saldo da conta, não o valor guardado à
/// mão.
class _GoalView {
  const _GoalView(this.goal, this.account);

  final Goal goal;
  final FinancialAccount? account;

  String get id => goal.id;
  String get title => goal.title;
  String? get description => goal.description;
  double get targetAmount => goal.targetAmount;
  DateTime? get deadline => goal.deadline;
  GoalPriority get priority => goal.priority;
  GoalIcon get icon => goalIconFrom(goal.icon);
  bool get isLinked => goal.isLinked;

  double get savedAmount => goal.savedWith(account?.balance);
  double get progress => goal.progressWith(account?.balance);
  double get remaining => goal.remainingWith(account?.balance);
  bool get isCompleted => goal.isCompletedWith(account?.balance);
  bool get isOverdue => goal.isOverdueWith(account?.balance);
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  String _searchTerm = '';
  _GoalStatusFilter _statusFilter = _GoalStatusFilter.todas;
  GoalPriority? _priorityFilter;

  List<_GoalView> _viewsOf(
    List<Goal> goals,
    List<FinancialAccount> accounts,
  ) {
    final accountsById = {for (final item in accounts) item.id: item};
    return [
      for (final goal in goals)
        _GoalView(goal, accountsById[goal.linkedAccountId]),
    ];
  }

  List<_GoalView> _filter(List<_GoalView> views) {
    final search = _searchTerm.toLowerCase();
    final result = views.where((view) {
      final matchesSearch =
          view.title.toLowerCase().contains(search) ||
          (view.description?.toLowerCase().contains(search) ?? false);
      final matchesStatus = switch (_statusFilter) {
        _GoalStatusFilter.todas => true,
        _GoalStatusFilter.emAndamento => !view.isCompleted,
        _GoalStatusFilter.concluidas => view.isCompleted,
      };
      final matchesPriority =
          _priorityFilter == null || view.priority == _priorityFilter;
      return matchesSearch && matchesStatus && matchesPriority;
    }).toList();

    // Concluídas descem; o resto mantém a ordem de criação que veio da API.
    result.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      return 0;
    });
    return result;
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      final message = context.read<GoalsController>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'Não consegui salvar a meta.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GoalsController>();
    final accounts = context.watch<FinancialDataController>().accounts;
    final views = _viewsOf(controller.goals, accounts);
    final filtered = _filter(views);

    final totalSaved = views.fold<double>(
      0,
      (sum, view) => sum + math.min(view.savedAmount, view.targetAmount),
    );
    final totalRemaining = views.fold<double>(
      0,
      (sum, view) => sum + view.remaining,
    );
    final completed = views.where((view) => view.isCompleted).length;
    final linked = views.where((view) => view.isLinked).length;

    return PageFrame(
      title: 'Metas',
      subtitle: views.isEmpty
          ? 'Guarde para alguma coisa: uma viagem, uma reserva, uma troca de carro.'
          : 'O valor do objetivo dividido pelos meses que faltam.',
      children: [
        if (controller.errorMessage != null && controller.goals.isEmpty)
          _GoalsErrorCard(
            message: controller.errorMessage!,
            onRetry: controller.load,
          )
        else ...[
          ResponsiveWrap(
            minItemWidth: 200,
            maxColumns: 5,
            children: [
              SummaryTextCard(label: 'Metas ativas', value: '${views.length}'),
              SummaryTextCard(
                label: 'Total guardado',
                value: formatCurrency(totalSaved),
                valueColor: context.colors.success,
              ),
              SummaryTextCard(
                label: 'Falta guardar',
                value: formatCurrency(totalRemaining),
                valueColor: context.colors.secondary,
              ),
              SummaryTextCard(
                label: 'Metas concluídas',
                value: '$completed de ${views.length}',
              ),
              SummaryTextCard(
                label: 'Vinculadas a contas',
                value: '$linked de ${views.length}',
              ),
            ],
          ),
          const SectionGap(),
          _GoalFilters(
            statusFilter: _statusFilter,
            priorityFilter: _priorityFilter,
            onSearch: (value) => setState(() => _searchTerm = value),
            onStatusChanged: (value) => setState(() => _statusFilter = value),
            onPriorityChanged: (value) =>
                setState(() => _priorityFilter = value),
            onCreate: () => _openGoalForm(accounts: accounts),
          ),
          const SectionGap(),
          if (controller.isLoading && controller.goals.isEmpty)
            const AppCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 56),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (filtered.isEmpty)
            _GoalsEmptyState(hasGoals: views.isNotEmpty)
          else
            ResponsiveWrap(
              minItemWidth: 360,
              maxColumns: 2,
              children: [
                for (final view in filtered)
                  _GoalCard(
                    view: view,
                    onEdit: () => _openGoalForm(accounts: accounts, existing: view),
                    onDelete: () => _confirmDelete(view),
                    onContribute: () => _openContributionDialog(view),
                    onUnlink: () => _unlink(view),
                  ),
              ],
            ),
        ],
      ],
    );
  }

  Future<void> _openGoalForm({
    required List<FinancialAccount> accounts,
    _GoalView? existing,
  }) async {
    final result = await showDialog<_GoalFormResult>(
      context: context,
      builder: (_) => _GoalFormDialog(existing: existing, accounts: accounts),
    );
    if (result == null || !mounted) return;

    final controller = context.read<GoalsController>();
    await _run(() {
      if (existing == null) {
        return controller.create(
          title: result.title,
          description: result.description,
          targetAmount: result.targetAmount,
          savedAmount: result.savedAmount,
          deadline: result.deadline,
          priority: result.priority,
          icon: result.icon.name,
          linkedAccountId: result.linkedAccountId,
        );
      }
      return controller.update(
        existing.id,
        title: result.title,
        description: result.description ?? '',
        targetAmount: result.targetAmount,
        savedAmount: result.savedAmount,
        deadline: result.deadline,
        priority: result.priority,
        icon: result.icon.name,
        linkedAccountId: result.linkedAccountId,
        clearDeadline: result.deadline == null,
        clearLinkedAccount: result.linkedAccountId == null,
      );
    });
  }

  Future<void> _openContributionDialog(_GoalView view) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _ContributionDialog(title: view.title),
    );
    if (amount == null || !mounted) return;

    final controller = context.read<GoalsController>();
    await _run(() => controller.contribute(view.id, amount));
  }

  Future<void> _confirmDelete(_GoalView view) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover meta'),
        content: Text(
          'Tem certeza que deseja remover "${view.title}"? '
          'Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.error),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final controller = context.read<GoalsController>();
    await _run(() => controller.delete(view.id));
  }

  /// Desvincula a conta congelando o saldo atual como valor guardado.
  ///
  /// Zerar aqui faria a meta voltar do zero só por ter trocado a fonte.
  Future<void> _unlink(_GoalView view) async {
    final controller = context.read<GoalsController>();
    await _run(
      () => controller.update(
        view.id,
        savedAmount: view.savedAmount,
        clearLinkedAccount: true,
      ),
    );
  }
}

class _GoalsErrorCard extends StatelessWidget {
  const _GoalsErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: context.colors.error.withValues(alpha: 0.5),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, color: context.colors.error, size: 32),
          const SizedBox(height: FlorgSpacing.md),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: FlorgSpacing.md),
          OutlineActionButton(
            label: 'Tentar de novo',
            icon: Icons.refresh_rounded,
            onPressed: () => onRetry(),
          ),
        ],
      ),
    );
  }
}

class _GoalsEmptyState extends StatelessWidget {
  const _GoalsEmptyState({required this.hasGoals});

  /// Distingue "nenhuma meta" de "nenhuma meta com estes filtros".
  final bool hasGoals;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Column(
          children: [
            Icon(
              Icons.savings_rounded,
              color: context.colors.secondary,
              size: 44,
            ),
            const SizedBox(height: FlorgSpacing.md),
            Text(
              hasGoals
                  ? 'Nenhuma meta encontrada com os filtros atuais.'
                  : 'Você ainda não tem metas. Crie a primeira e comece a '
                        'guardar dinheiro para o que importa.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalFilters extends StatelessWidget {
  const _GoalFilters({
    required this.statusFilter,
    required this.priorityFilter,
    required this.onSearch,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onCreate,
  });

  final _GoalStatusFilter statusFilter;
  final GoalPriority? priorityFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_GoalStatusFilter> onStatusChanged;
  final ValueChanged<GoalPriority?> onPriorityChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Wrap(
        spacing: FlorgSpacing.md,
        runSpacing: FlorgSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              onChanged: onSearch,
              decoration: inputDecoration(
                context,
                hintText: 'Buscar metas...',
                prefixIcon: Icons.search_rounded,
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<_GoalStatusFilter>(
              initialValue: statusFilter,
              isExpanded: true,
              decoration: inputDecoration(context),
              items: const [
                DropdownMenuItem(
                  value: _GoalStatusFilter.todas,
                  child: Text('Todas'),
                ),
                DropdownMenuItem(
                  value: _GoalStatusFilter.emAndamento,
                  child: Text('Em andamento'),
                ),
                DropdownMenuItem(
                  value: _GoalStatusFilter.concluidas,
                  child: Text('Concluídas'),
                ),
              ],
              onChanged: (value) =>
                  onStatusChanged(value ?? _GoalStatusFilter.todas),
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<GoalPriority?>(
              initialValue: priorityFilter,
              isExpanded: true,
              decoration: inputDecoration(context),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Toda prioridade'),
                ),
                for (final priority in GoalPriority.values)
                  DropdownMenuItem(
                    value: priority,
                    child: Text(priority.label),
                  ),
              ],
              onChanged: onPriorityChanged,
            ),
          ),
          SizedBox(
            width: 160,
            child: GradientButton(
              label: 'Nova meta',
              icon: Icons.add_rounded,
              onPressed: onCreate,
            ),
          ),
        ],
      ),
    );
  }
}

/// O que o formulário devolve para a tela gravar.
class _GoalFormResult {
  const _GoalFormResult({
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    required this.priority,
    required this.icon,
    this.description,
    this.deadline,
    this.linkedAccountId,
  });

  final String title;
  final String? description;
  final double targetAmount;
  final double savedAmount;
  final DateTime? deadline;
  final GoalPriority priority;
  final GoalIcon icon;
  final String? linkedAccountId;
}

class _GoalFormDialog extends StatefulWidget {
  const _GoalFormDialog({required this.accounts, this.existing});

  final List<FinancialAccount> accounts;
  final _GoalView? existing;

  @override
  State<_GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends State<_GoalFormDialog> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _description = TextEditingController(
    text: widget.existing?.description,
  );
  late final _target = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.targetAmount.toStringAsFixed(2),
  );
  late final _saved = TextEditingController(
    text: widget.existing == null
        ? '0'
        : widget.existing!.goal.savedAmount.toStringAsFixed(2),
  );

  late GoalPriority _priority = widget.existing?.priority ?? GoalPriority.medium;
  late GoalIcon _icon = widget.existing?.icon ?? GoalIcon.outro;
  late DateTime? _deadline = widget.existing?.deadline;
  late bool _useAccount = widget.existing?.isLinked ?? false;
  late String? _accountId = widget.existing?.goal.linkedAccountId;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  double _parseAmount(String text) =>
      double.tryParse(text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  void _submit() {
    final title = _title.text.trim();
    final target = _parseAmount(_target.text);

    if (title.isEmpty) {
      setState(() => _error = 'Dê um nome para a meta.');
      return;
    }
    if (target <= 0) {
      setState(() => _error = 'O valor da meta precisa ser maior que zero.');
      return;
    }
    if (_useAccount && _accountId == null) {
      setState(() => _error = 'Escolha a conta que vai acompanhar a meta.');
      return;
    }

    final description = _description.text.trim();
    Navigator.pop(
      context,
      _GoalFormResult(
        title: title,
        description: description.isEmpty ? null : description,
        targetAmount: target,
        // Vinculada a uma conta, o guardado vem do saldo; o campo manual fica
        // só como o valor de partida caso a meta seja desvinculada depois.
        savedAmount: _useAccount
            ? (widget.existing?.goal.savedAmount ?? 0)
            : _parseAmount(_saved.text),
        deadline: _deadline,
        priority: _priority,
        icon: _icon,
        linkedAccountId: _useAccount ? _accountId : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selectedAccount = widget.accounts
        .where((account) => account.id == _accountId)
        .firstOrNull;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(FlorgSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'Nova meta' : 'Editar meta',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: FlorgSpacing.lg),
              TextField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: inputDecoration(context, hintText: 'Título da meta'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: inputDecoration(
                  context,
                  hintText: 'Descrição (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _target,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: inputDecoration(
                  context,
                  hintText: 'Valor da meta (R\$)',
                ),
              ),
              const SizedBox(height: FlorgSpacing.md),
              const SectionLabel('Fonte do progresso'),
              const SizedBox(height: FlorgSpacing.sm),
              Wrap(
                spacing: FlorgSpacing.sm,
                children: [
                  ChoiceChip(
                    label: const Text('Aporte manual'),
                    selected: !_useAccount,
                    onSelected: (_) => setState(() => _useAccount = false),
                  ),
                  ChoiceChip(
                    label: const Text('Vincular a uma conta'),
                    selected: _useAccount,
                    onSelected: widget.accounts.isEmpty
                        ? null
                        : (_) => setState(() {
                            _useAccount = true;
                            _accountId ??= widget.accounts.first.id;
                          }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_useAccount) ...[
                DropdownButtonFormField<String>(
                  initialValue: _accountId,
                  isExpanded: true,
                  decoration: inputDecoration(context),
                  items: [
                    for (final account in widget.accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          account.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _accountId = value),
                ),
                if (selectedAccount != null) ...[
                  const SizedBox(height: FlorgSpacing.sm),
                  Text(
                    'Saldo atual: ${formatCurrency(selectedAccount.balance)} · '
                    'atualizado automaticamente',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ] else
                TextField(
                  controller: _saved,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: inputDecoration(
                    context,
                    hintText: 'Já guardado (R\$)',
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(
                  _deadline == null
                      ? 'Definir prazo (opcional)'
                      : formatDate(_deadline!),
                ),
                onPressed: _pickDeadline,
              ),
              if (_deadline != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _deadline = null),
                    child: const Text('Remover prazo'),
                  ),
                ),
              const SizedBox(height: 12),
              const SectionLabel('Prioridade'),
              const SizedBox(height: FlorgSpacing.sm),
              Wrap(
                spacing: FlorgSpacing.sm,
                children: [
                  for (final priority in GoalPriority.values)
                    ChoiceChip(
                      label: Text(priority.label),
                      selected: _priority == priority,
                      selectedColor: priority.background(context),
                      onSelected: (_) => setState(() => _priority = priority),
                    ),
                ],
              ),
              const SizedBox(height: FlorgSpacing.md),
              const SectionLabel('Ícone'),
              const SizedBox(height: FlorgSpacing.sm),
              Wrap(
                spacing: FlorgSpacing.sm,
                runSpacing: FlorgSpacing.sm,
                children: [
                  for (final option in GoalIcon.values)
                    Tooltip(
                      message: option.label,
                      child: GestureDetector(
                        onTap: () => setState(() => _icon = option),
                        child: IconTile(
                          icon: option.data,
                          background: _icon == option
                              ? colors.primary
                              : colors.surfaceElevated,
                          color: _icon == option
                              ? colors.onPrimary
                              : colors.textSecondary,
                          size: 44,
                          iconSize: 20,
                        ),
                      ),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: FlorgSpacing.md),
                Text(
                  _error!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: FlorgSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: FlorgSpacing.sm),
                  GradientButton(
                    label: widget.existing == null ? 'Criar meta' : 'Salvar',
                    icon: Icons.check_rounded,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }
}

class _ContributionDialog extends StatefulWidget {
  const _ContributionDialog({required this.title});

  final String title;

  @override
  State<_ContributionDialog> createState() => _ContributionDialogState();
}

class _ContributionDialogState extends State<_ContributionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _value =>
      double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(FlorgSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adicionar aporte',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: FlorgSpacing.xs),
              Text(widget.title, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: FlorgSpacing.md),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                decoration: inputDecoration(
                  context,
                  hintText: 'Valor (R\$)',
                  prefixIcon: Icons.savings_rounded,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: FlorgSpacing.sm,
                children: [
                  for (final amount in [50, 100, 250, 500])
                    ActionChip(
                      label: Text(
                        '+ ${formatCurrency(amount.toDouble(), decimals: 0)}',
                      ),
                      onPressed: () {
                        _controller.text = (_value + amount).toStringAsFixed(2);
                        setState(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: FlorgSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: FlorgSpacing.sm),
                  GradientButton(
                    label: 'Adicionar',
                    icon: Icons.add_rounded,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_value <= 0) return;
    Navigator.pop(context, _value);
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.view,
    required this.onEdit,
    required this.onDelete,
    required this.onContribute,
    required this.onUnlink,
  });

  final _GoalView view;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onContribute;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progressColor = view.isCompleted
        ? colors.success
        : view.isOverdue
        ? colors.error
        : colors.primary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GoalCardHeader(view: view, onSelected: _handleMenu),
          const SizedBox(height: 14),
          Wrap(
            spacing: FlorgSpacing.sm,
            runSpacing: 6,
            children: [
              BadgePill(
                label: view.priority.label,
                background: view.priority.background(context),
                color: view.priority.color(context),
              ),
              if (view.isCompleted)
                BadgePill(
                  label: 'Meta atingida',
                  background: colors.success.withValues(alpha: 0.14),
                  color: colors.success,
                )
              else if (view.deadline != null)
                BadgePill(
                  label: view.isOverdue
                      ? 'Prazo vencido'
                      : formatDate(view.deadline!),
                  background: view.isOverdue
                      ? colors.error.withValues(alpha: 0.14)
                      : colors.surfaceElevated,
                  color: view.isOverdue ? colors.error : colors.textSecondary,
                ),
            ],
          ),
          if (view.account != null) ...[
            const SizedBox(height: 10),
            _LinkedAccountBadge(account: view.account!),
          ],
          const SizedBox(height: FlorgSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(FlorgRadius.sm),
            child: LinearProgressIndicator(
              value: view.progress,
              minHeight: 8,
              backgroundColor: colors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
          const SizedBox(height: FlorgSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${formatCurrency(view.savedAmount)} de '
                  '${formatCurrency(view.targetAmount)}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(view.progress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (!view.isCompleted) ...[
            const SizedBox(height: FlorgSpacing.xs),
            Text(
              'Faltam ${formatCurrency(view.remaining)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: FlorgSpacing.md),
          if (!view.isCompleted)
            if (view.isLinked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(FlorgRadius.sm),
                ),
                child: Text(
                  'Atualizado automaticamente pela conta vinculada',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  label: 'Adicionar aporte',
                  icon: Icons.savings_rounded,
                  onPressed: onContribute,
                ),
              ),
        ],
      ),
    );
  }

  void _handleMenu(String value) {
    switch (value) {
      case 'edit':
        onEdit();
      case 'unlink':
        onUnlink();
      case 'delete':
        onDelete();
    }
  }
}

class _GoalCardHeader extends StatelessWidget {
  const _GoalCardHeader({required this.view, required this.onSelected});

  final _GoalView view;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile(
          icon: view.icon.data,
          background: view.priority.background(context),
          color: view.priority.color(context),
          size: 44,
          iconSize: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                view.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (view.description != null) ...[
                const SizedBox(height: 2),
                Text(
                  view.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: onSelected,
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            if (view.isLinked)
              const PopupMenuItem(
                value: 'unlink',
                child: Text('Desvincular conta'),
              ),
            const PopupMenuItem(value: 'delete', child: Text('Remover')),
          ],
        ),
      ],
    );
  }
}

class _LinkedAccountBadge extends StatelessWidget {
  const _LinkedAccountBadge({required this.account});

  final FinancialAccount account;

  @override
  Widget build(BuildContext context) {
    final accent = accountAccent(account.type);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: FlorgSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: accent.background,
        borderRadius: BorderRadius.circular(FlorgRadius.sm),
      ),
      child: Row(
        children: [
          Icon(accountIcon(account.type), size: 16, color: accent.foreground),
          const SizedBox(width: FlorgSpacing.sm),
          Expanded(
            child: Text(
              'Sincronizado com ${account.name}',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: accent.foreground),
            ),
          ),
        ],
      ),
    );
  }
}
