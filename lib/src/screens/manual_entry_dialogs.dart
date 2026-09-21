import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/layout.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/financial_data_controller.dart';
import '../models/financial_models.dart';
Future<bool> showAddAccountDialog(BuildContext context) async {
  final data = context.read<FinancialDataController>();
  return await showDialog<bool>(
        context: context,
        builder: (_) => _AccountFormDialog(data: data),
      ) ??
      false;
}

Future<bool> showAddTransactionDialog(BuildContext context) async {
  final data = context.read<FinancialDataController>();
  if (data.accounts.isEmpty) {
    final addAccount = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cadastre uma conta primeiro'),
        content: const Text(
          'Toda transação precisa estar vinculada a uma conta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Adicionar conta'),
          ),
        ],
      ),
    );
    if (addAccount == true && context.mounted) {
      final accountCreated = await showAddAccountDialog(context);
      if (accountCreated && context.mounted && data.accounts.isNotEmpty) {
        return showAddTransactionDialog(context);
      }
      return accountCreated;
    }
    return false;
  }

  return await showDialog<bool>(
        context: context,
        builder: (_) => _TransactionFormDialog(data: data),
      ) ??
      false;
}

class _AccountFormDialog extends StatefulWidget {
  const _AccountFormDialog({required this.data});

  final FinancialDataController data;

  @override
  State<_AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<_AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0,00');
  String _type = 'checking';
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.data.createAccount(
        name: _nameController.text.trim(),
        type: _type,
        balance: parseManualAmount(_balanceController.text)!,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = financialErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar conta'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: inputDecoration(
                    context,
                    hintText: 'Nome da conta',
                    prefixIcon: Icons.account_balance_wallet_rounded,
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Informe o nome da conta.'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: inputDecoration(context),
                  items: accountTypeLabels.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _type = value ?? _type),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _balanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: inputDecoration(
                    context,
                    hintText: 'Saldo inicial',
                    prefixIcon: Icons.attach_money_rounded,
                  ),
                  validator: (value) => parseManualAmount(value ?? '') == null
                      ? 'Informe um valor válido.'
                      : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.rose600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_isSaving ? 'Salvando...' : 'Salvar conta'),
        ),
      ],
    );
  }
}

class _TransactionFormDialog extends StatefulWidget {
  const _TransactionFormDialog({required this.data});

  final FinancialDataController data;

  @override
  State<_TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<_TransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  late String _accountId;
  String _categorySelection = 'auto';
  TransactionKind _kind = TransactionKind.expense;
  DateTime _date = DateTime.now();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _accountId = widget.data.accounts.first.id;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.data.createTransaction(
        accountId: _accountId,
        description: _descriptionController.text.trim(),
        amount: parseManualAmount(_amountController.text)!,
        type: _kind,
        occurredAt: _date,
        categoryId: _categorySelection == 'auto' ? null : _categorySelection,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = financialErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova transação'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<TransactionKind>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionKind.expense,
                      label: Text('Despesa'),
                      icon: Icon(Icons.north_east_rounded),
                    ),
                    ButtonSegment(
                      value: TransactionKind.income,
                      label: Text('Receita'),
                      icon: Icon(Icons.south_east_rounded),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (selection) =>
                      setState(() => _kind = selection.first),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _descriptionController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: inputDecoration(
                    context,
                    hintText: 'Descrição',
                    prefixIcon: Icons.notes_rounded,
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Informe uma descrição.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: inputDecoration(
                    context,
                    hintText: 'Valor',
                    prefixIcon: Icons.attach_money_rounded,
                  ),
                  validator: (value) {
                    final amount = parseManualAmount(value ?? '');
                    return amount == null || amount <= 0
                        ? 'Informe um valor maior que zero.'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _accountId,
                  isExpanded: true,
                  decoration: inputDecoration(context),
                  items: widget.data.accounts
                      .map(
                        (account) => DropdownMenuItem(
                          value: account.id,
                          child: Text(account.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _accountId = value ?? _accountId),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _categorySelection,
                  isExpanded: true,
                  decoration: inputDecoration(context),
                  items: [
                    const DropdownMenuItem<String>(
                      value: 'auto',
                      child: Text('Categorizar automaticamente'),
                    ),
                    ...widget.data.categories.map(
                      (category) => DropdownMenuItem<String>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _categorySelection = value ?? 'auto'),
                ),
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: inputDecoration(context),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: AppColors.teal400,
                        ),
                        const SizedBox(width: 12),
                        Text(formatDate(_date)),
                      ],
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.rose600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_isSaving ? 'Salvando...' : 'Salvar transação'),
        ),
      ],
    );
  }
}

const accountTypeLabels = <String, String>{
  'checking': 'Conta corrente',
  'savings': 'Poupança',
  'wallet': 'Carteira',
  'credit_card': 'Cartão de crédito',
};

double? parseManualAmount(String value) {
  var normalized = value
      .trim()
      .replaceAll('R\$', '')
      .replaceAll(RegExp(r'\s'), '');
  if (normalized.isEmpty) return null;
  if (normalized.contains(',')) {
    normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(normalized);
}

String financialErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is StateError) return error.message.toString();
  return 'Não foi possível salvar. Tente novamente.';
}
