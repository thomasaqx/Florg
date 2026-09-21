import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/financial_data_controller.dart';
import '../models/financial_models.dart';
import '../screens/manual_entry_dialogs.dart';
import '../shared/layout.dart';
import './dashboard_screen.dart';
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _searchTerm = '';
  String _filterCategory = 'all';
  String _filterType = 'all';

  List<Transaction> get _transactions =>
      context.watch<FinancialDataController>().transactions;

  List<String> get _categories {
    final values = _transactions
        .map((transaction) => transaction.category)
        .toSet()
        .toList();
    values.sort();
    return ['all', ...values];
  }

  List<Transaction> get _filteredTransactions {
    return _transactions.where((transaction) {
      final search = _searchTerm.toLowerCase();
      final matchesSearch =
          transaction.description.toLowerCase().contains(search) ||
          transaction.category.toLowerCase().contains(search);
      final matchesCategory =
          _filterCategory == 'all' || transaction.category == _filterCategory;
      final matchesType =
          _filterType == 'all' || transaction.type.name == _filterType;
      return matchesSearch && matchesCategory && matchesType;
    }).toList();
  }

  Future<void> _addTransaction() async {
    final created = await showAddTransactionDialog(context);
    if (created && mounted) {
      // Reload without a full-screen spinner: the list is already on screen
      // and flashing it on every entry would be worse than a silent wait.
      await context.read<FinancialDataController>().load(showLoading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FinancialDataController>();

    if (data.isLoading && !data.hasLoaded) {
      return const PageFrame(
        title: 'Transações',
        subtitle: 'Carregando seu extrato.',
        children: [Center(child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: CircularProgressIndicator(),
        ))],
      );
    }

    if (data.errorMessage != null && !data.hasLoaded) {
      return PageFrame(
        title: 'Transações',
        subtitle: 'Não foi possível carregar o extrato.',
        children: [
          _ErrorState(
            message: data.errorMessage!,
            onRetry: () => context.read<FinancialDataController>().load(),
          ),
        ],
      );
    }

    final filtered = _filteredTransactions;
    final income = totalFor(filtered, TransactionKind.income);
    final expenses = totalFor(filtered, TransactionKind.expense);

    return PageFrame(
      title: 'Transações',
      subtitle: data.transactions.isEmpty
          ? 'Nada lançado ainda. Importe um extrato ou use o botão abaixo.'
          : '${data.transactions.length} lançamentos em ${data.accounts.length} conta(s).',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTransaction,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova transação'),
      ),
      children: [
        ResponsiveWrap(
          minItemWidth: 240,
          maxColumns: 3,
          children: [
            SummaryTextCard(
              label: 'Total de transações',
              value: '${filtered.length}',
            ),
            SummaryTextCard(
              label: 'Total de receitas',
              value: formatCurrency(income),
              valueColor: AppColors.emerald600,
            ),
            SummaryTextCard(
              label: 'Total de despesas',
              value: formatCurrency(expenses),
              valueColor: AppColors.rose600,
            ),
          ],
        ),
        const SectionGap(),
        AppCard(
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  onChanged: (value) => setState(() => _searchTerm = value),
                  decoration: inputDecoration(
                    context,
                    hintText: 'Buscar transações...',
                    prefixIcon: Icons.search_rounded,
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _filterType,
                  isExpanded: true,
                  decoration: inputDecoration(context),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('Todos os tipos'),
                    ),
                    DropdownMenuItem(value: 'income', child: Text('Receita')),
                    DropdownMenuItem(value: 'expense', child: Text('Despesa')),
                  ],
                  onChanged: (value) =>
                      setState(() => _filterType = value ?? 'all'),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _filterCategory,
                  isExpanded: true,
                  decoration: inputDecoration(context),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(
                            category == 'all'
                                ? 'Todas as categorias'
                                : category,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _filterCategory = value ?? 'all'),
                ),
              ),
              SizedBox(
                width: 140,
                child: GradientButton(
                  label: 'Exportar',
                  icon: Icons.download_rounded,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TransactionsTable(transactions: filtered),
      ],
    );
  }
}

/// Network or API failure, with a way to retry.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 64),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.secondaryText(context)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText(context)),
            ),
            const SizedBox(height: 16),
            OutlineActionButton(
              label: 'Tentar novamente',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryTextCard extends StatelessWidget {
  const SummaryTextCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.accentText(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.primaryText(context),
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionsTable extends StatelessWidget {
  const TransactionsTable({super.key, required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (transactions.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 56),
              child: Column(
                children: [
                  const Icon(
                    Icons.filter_list_rounded,
                    color: AppColors.teal300,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhuma transação encontrada com os filtros atuais.',
                    style: TextStyle(color: AppColors.accentText(context)),
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AppColors.tableHeader(context),
                ),
                dataRowMinHeight: 64,
                dataRowMaxHeight: 76,
                columnSpacing: 32,
                dataTextStyle: TextStyle(color: AppColors.primaryText(context)),
                headingTextStyle: TextStyle(
                  color: AppColors.primaryText(context),
                  fontWeight: FontWeight.w700,
                ),
                columns: const [
                  DataColumn(label: Text('Data')),
                  DataColumn(label: Text('Descrição')),
                  DataColumn(label: Text('Categoria')),
                  DataColumn(label: Text('Conta')),
                  DataColumn(label: Text('Tipo')),
                  DataColumn(label: Text('Valor'), numeric: true),
                ],
                rows: transactions
                    .map((transaction) => _transactionRow(context, transaction))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  DataRow _transactionRow(BuildContext context, Transaction transaction) {
    final isIncome = transaction.type == TransactionKind.income;
    return DataRow(
      cells: [
        DataCell(
          Text(
            formatDate(transaction.date),
            style: TextStyle(color: AppColors.primaryText(context)),
          ),
        ),
        DataCell(
          Row(
            children: [
              IconTile(
                icon: isIncome
                    ? Icons.south_east_rounded
                    : Icons.north_east_rounded,
                background: isIncome
                    ? AppColors.emerald100
                    : context.colors.surfaceElevated,
                color: isIncome ? AppColors.emerald600 : AppColors.teal600,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: TextStyle(
                      color: AppColors.primaryText(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    children: [
                      if (transaction.isRecurring)
                        const BadgePill(label: 'Recorrente'),
                      if (transaction.isUnnecessary)
                        const BadgePill(
                          label: 'Revisar',
                          background: AppColors.amber100,
                          color: AppColors.amber700,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        DataCell(BadgePill(label: transaction.category)),
        DataCell(
          Text(
            transaction.account,
            style: TextStyle(color: AppColors.accentText(context)),
          ),
        ),
        DataCell(
          BadgePill(
            label: transactionKindLabel(transaction.type),
            background: isIncome ? AppColors.emerald100 : AppColors.rose100,
            color: isIncome ? AppColors.emerald700 : AppColors.rose700,
          ),
        ),
        DataCell(
          Text(
            formatTransactionAmount(transaction),
            style: TextStyle(
              color: isIncome
                  ? AppColors.emerald600
                  : AppColors.primaryText(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class BadgePill extends StatelessWidget {
  const BadgePill({
    super.key,
    required this.label,
    this.background,
    this.color,
  });

  final String label;
  final Color? background;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? AppColors.subtleFill(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.secondaryText(context),
          fontSize: 12,
        ),
      ),
    );
  }
}
