import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/financial_data_controller.dart';
import '../data/import_repository.dart';
import '../models/financial_models.dart';
import '../models/import_models.dart';
import '../shared/layout.dart';
import './dashboard_screen.dart' show IconTile;
import './transactions_screen.dart' show BadgePill;

/// Importa um extrato de planilha para dentro de uma conta.
///
/// O envio do arquivo não grava nada: o backend lê, devolve as linhas, e só o
/// que o usuário confirmar vira lançamento. Linhas que já entraram em uma
/// importação anterior aparecem marcadas e são puladas.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.onFinished});

  /// Chamado depois de uma importação bem-sucedida, para levar às transações.
  final VoidCallback onFinished;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  PlatformFile? _file;
  SpreadsheetPreview? _preview;
  String? _accountId;
  String? _error;
  bool _isReading = false;
  bool _isSaving = false;
  ImportResult? _result;

  /// Linhas que o usuário desmarcou na revisão.
  final Set<String> _excluded = {};

  ImportRepository get _repository => context.read<ImportRepository>();

  List<ImportRow> get _selectedRows =>
      (_preview?.rows ?? []).where((row) => !_excluded.contains(row.fingerprint)).toList();

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xlsm', 'csv', 'txt'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    if (file.bytes == null) {
      setState(() => _error = 'Não consegui ler o conteúdo do arquivo.');
      return;
    }

    setState(() {
      _file = file;
      _preview = null;
      _result = null;
      _error = null;
      _excluded.clear();
    });
    await _loadPreview();
  }

  Future<void> _loadPreview({ColumnMapping? mapping}) async {
    final file = _file;
    if (file == null || file.bytes == null) return;

    setState(() {
      _isReading = true;
      _error = null;
    });

    try {
      final preview = await _repository.preview(
        filename: file.name,
        bytes: file.bytes!,
        accountId: _accountId,
        mapping: mapping,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _excluded.clear();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _error = 'Não consegui falar com o servidor. Confira se a API está no ar.';
      });
    } finally {
      if (mounted) setState(() => _isReading = false);
    }
  }

  Future<void> _commit() async {
    final preview = _preview;
    final accountId = _accountId;
    if (preview == null || accountId == null || _selectedRows.isEmpty) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final result = await _repository.commit(
        accountId: accountId,
        filename: preview.filename,
        rows: _selectedRows,
      );
      if (!mounted) return;
      // Recarrega saldo e extrato para o resto do app refletir a importação.
      await context.read<FinancialDataController>().load(showLoading: false);
      if (!mounted) return;
      setState(() {
        _result = result;
        _preview = null;
        _file = null;
        _excluded.clear();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não consegui salvar os lançamentos.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FinancialDataController>();
    final accounts = data.accounts;

    // A conta é obrigatória e quase sempre há só uma, então já vem escolhida.
    if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }

    return PageFrame(
      title: 'Importar extrato',
      subtitle:
          'Envie a planilha que o banco exporta. Você confere tudo antes de salvar.',
      children: [
        if (accounts.isEmpty)
          const _NoAccountsCard()
        else ...[
          _FilePickerCard(
            file: _file,
            accounts: accounts,
            accountId: _accountId,
            isBusy: _isReading,
            onPick: _pickFile,
            onAccountChanged: (value) {
              setState(() => _accountId = value);
              if (_file != null) _loadPreview();
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _ErrorCard(message: _error!),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            _ResultCard(result: _result!, onOpenTransactions: widget.onFinished),
          ],
          if (_isReading) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_preview != null && !_isReading) ...[
            const SectionGap(),
            _PreviewSummary(preview: _preview!, selected: _selectedRows.length),
            const SizedBox(height: 24),
            _ColumnMappingCard(
              preview: _preview!,
              onChanged: (mapping) => _loadPreview(mapping: mapping),
            ),
            const SizedBox(height: 24),
            _RowsCard(
              preview: _preview!,
              excluded: _excluded,
              onToggle: (fingerprint) {
                setState(() {
                  if (!_excluded.remove(fingerprint)) _excluded.add(fingerprint);
                });
              },
            ),
            if (_preview!.skipped.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SkippedCard(skipped: _preview!.skipped),
            ],
            const SizedBox(height: 24),
            _ConfirmBar(
              count: _selectedRows.length,
              isSaving: _isSaving,
              onConfirm: _commit,
              onCancel: () => setState(() {
                _preview = null;
                _file = null;
                _excluded.clear();
              }),
            ),
          ],
        ],
      ],
    );
  }
}

class _NoAccountsCard extends StatelessWidget {
  const _NoAccountsCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: Icons.account_balance_wallet_rounded,
            background: context.colors.primaryMuted,
            color: context.colors.secondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Crie uma conta antes de importar',
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Os lançamentos da planilha precisam pertencer a alguma conta. '
            'Abra a aba Contas e cadastre a sua.',
            style: TextStyle(color: AppColors.secondaryText(context), height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _FilePickerCard extends StatelessWidget {
  const _FilePickerCard({
    required this.file,
    required this.accounts,
    required this.accountId,
    required this.isBusy,
    required this.onPick,
    required this.onAccountChanged,
  });

  final PlatformFile? file;
  final List<FinancialAccount> accounts;
  final String? accountId;
  final bool isBusy;
  final VoidCallback onPick;
  final ValueChanged<String?> onAccountChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Para qual conta',
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: accountId,
            decoration: inputDecoration(
              context,
              prefixIcon: Icons.account_balance_wallet_rounded,
            ),
            items: accounts
                .map(
                  (account) => DropdownMenuItem(
                    value: account.id,
                    child: Text(
                      '${account.name} · ${formatCurrency(account.balance)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onAccountChanged,
          ),
          const SizedBox(height: 24),
          DottedDropZone(
            file: file,
            isBusy: isBusy,
            onPick: onPick,
          ),
          const SizedBox(height: 12),
          Text(
            'Aceita .xlsx e .csv, até 5 MB. A planilha precisa ter uma linha de '
            'cabeçalho com data, descrição e valor. Valor negativo vira despesa; '
            'positivo, receita.',
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class DottedDropZone extends StatelessWidget {
  const DottedDropZone({
    super.key,
    required this.file,
    required this.isBusy,
    required this.onPick,
  });

  final PlatformFile? file;
  final bool isBusy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final selected = file != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isBusy ? null : onPick,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.subtleFill(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.teal500 : AppColors.border(context),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                selected
                    ? Icons.description_rounded
                    : Icons.upload_file_rounded,
                size: 38,
                color: AppColors.teal600,
              ),
              const SizedBox(height: 12),
              Text(
                selected ? file!.name : 'Escolher planilha',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primaryText(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                selected
                    ? '${_readableSize(file!.size)} · toque para trocar'
                    : 'Extrato do banco em .xlsx ou .csv',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondaryText(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _readableSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _PreviewSummary extends StatelessWidget {
  const _PreviewSummary({required this.preview, required this.selected});

  final SpreadsheetPreview preview;
  final int selected;

  @override
  Widget build(BuildContext context) {
    return ResponsiveWrap(
      minItemWidth: 220,
      maxColumns: 4,
      spacing: 16,
      children: [
        _SummaryTile(
          label: 'Linhas lidas',
          value: '${preview.rows.length}',
          detail: 'de ${preview.totalRows} no arquivo',
          icon: Icons.table_rows_rounded,
          color: AppColors.teal600,
          background: context.colors.primaryMuted,
        ),
        _SummaryTile(
          label: 'Entradas',
          value: formatCurrency(preview.incomeTotal),
          detail: 'somadas ao saldo',
          icon: Icons.south_west_rounded,
          color: AppColors.emerald600,
          background: AppColors.emerald100,
        ),
        _SummaryTile(
          label: 'Saídas',
          value: formatCurrency(preview.expenseTotal),
          detail: 'subtraídas do saldo',
          icon: Icons.north_east_rounded,
          color: AppColors.rose600,
          background: AppColors.rose100,
        ),
        _SummaryTile(
          label: 'Já importadas',
          value: '${preview.duplicateCount}',
          detail: preview.duplicateCount == 0
              ? 'nada repetido'
              : 'serão puladas',
          icon: Icons.content_copy_rounded,
          color: AppColors.amber600,
          background: AppColors.amber100,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: icon,
            background: background,
            color: color,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
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
          const SizedBox(height: 4),
          Text(
            detail,
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

/// Correção manual do mapeamento quando o palpite do backend erra.
class _ColumnMappingCard extends StatelessWidget {
  const _ColumnMappingCard({required this.preview, required this.onChanged});

  final SpreadsheetPreview preview;
  final ValueChanged<ColumnMapping> onChanged;

  @override
  Widget build(BuildContext context) {
    final mapping = preview.mapping;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Colunas reconhecidas',
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const BadgePill(label: 'ajuste se estiver errado'),
            ],
          ),
          const SizedBox(height: 16),
          ResponsiveWrap(
            minItemWidth: 220,
            maxColumns: 4,
            spacing: 16,
            children: [
              _ColumnSelector(
                label: 'Data',
                value: mapping.date,
                headers: preview.headers,
                onChanged: (index) =>
                    onChanged(mapping.copyWith(date: index)),
              ),
              _ColumnSelector(
                label: 'Descrição',
                value: mapping.description,
                headers: preview.headers,
                onChanged: (index) =>
                    onChanged(mapping.copyWith(description: index)),
              ),
              _ColumnSelector(
                label: 'Valor',
                value: mapping.amount,
                headers: preview.headers,
                onChanged: (index) =>
                    onChanged(mapping.copyWith(amount: index)),
              ),
              _ColumnSelector(
                label: 'Tipo',
                value: mapping.type,
                headers: preview.headers,
                allowNone: true,
                onChanged: (index) => onChanged(
                  index == null
                      ? mapping.copyWith(clearType: true)
                      : mapping.copyWith(type: index),
                ),
              ),
            ],
          ),
          if (mapping.type == null) ...[
            const SizedBox(height: 12),
            Text(
              'Sem coluna de tipo, o sinal do valor decide: negativo é despesa.',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColumnSelector extends StatelessWidget {
  const _ColumnSelector({
    required this.label,
    required this.value,
    required this.headers,
    required this.onChanged,
    this.allowNone = false,
  });

  final String label;
  final int? value;
  final List<String> headers;
  final ValueChanged<int?> onChanged;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.secondaryText(context),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int?>(
          initialValue: value,
          isExpanded: true,
          decoration: inputDecoration(context),
          items: [
            if (allowNone)
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Nenhuma'),
              ),
            for (var index = 0; index < headers.length; index++)
              DropdownMenuItem<int?>(
                value: index,
                child: Text(
                  headers[index].isEmpty
                      ? 'Coluna ${index + 1}'
                      : headers[index],
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _RowsCard extends StatelessWidget {
  const _RowsCard({
    required this.preview,
    required this.excluded,
    required this.onToggle,
  });

  final SpreadsheetPreview preview;
  final Set<String> excluded;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confira os lançamentos',
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Desmarque o que não quiser trazer.',
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          for (final row in preview.rows)
            _RowTile(
              row: row,
              included: !excluded.contains(row.fingerprint),
              onToggle: () => onToggle(row.fingerprint),
            ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.row,
    required this.included,
    required this.onToggle,
  });

  final ImportRow row;
  final bool included;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isIncome = row.type == TransactionKind.income;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border(context))),
      ),
      child: Opacity(
        opacity: included ? 1 : 0.4,
        child: Row(
          children: [
            Checkbox(
              value: included,
              onChanged: (_) => onToggle(),
              activeColor: AppColors.teal600,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.primaryText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatDate(row.occurredAt)} · linha ${row.line}',
                      style: TextStyle(
                        color: AppColors.accentText(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${isIncome ? '+' : '-'}${formatCurrency(row.amount)}',
              style: TextStyle(
                color: isIncome ? AppColors.emerald600 : AppColors.rose600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkippedCard extends StatelessWidget {
  const _SkippedCard({required this.skipped});

  final List<SkippedRow> skipped;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.amber500.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(
                icon: Icons.report_problem_rounded,
                background: AppColors.amber100,
                color: AppColors.amber600,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${skipped.length} linha(s) fora da importação',
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final row in skipped.take(20))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Linha ${row.line}: ${row.reason}'
                '${row.raw.isEmpty ? '' : ' — ${row.raw.take(3).join(' | ')}'}',
                style: TextStyle(
                  color: AppColors.secondaryText(context),
                  fontSize: 13,
                ),
              ),
            ),
          if (skipped.length > 20)
            Text(
              'e mais ${skipped.length - 20}.',
              style: TextStyle(
                color: AppColors.accentText(context),
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.count,
    required this.isSaving,
    required this.onConfirm,
    required this.onCancel,
  });

  final int count;
  final bool isSaving;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            count == 0
                ? 'Nenhuma linha marcada.'
                : '$count lançamento(s) prontos para entrar.',
            style: TextStyle(
              color: AppColors.primaryText(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          Wrap(
            spacing: 12,
            children: [
              OutlineActionButton(
                label: 'Descartar',
                icon: Icons.close_rounded,
                onPressed: isSaving ? () {} : onCancel,
              ),
              if (isSaving)
                const SizedBox(
                  height: 44,
                  width: 44,
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: 210,
                  child: GradientButton(
                    label: 'Importar $count lançamento(s)',
                    icon: Icons.download_done_rounded,
                    onPressed: count == 0 ? () {} : onConfirm,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onOpenTransactions});

  final ImportResult result;
  final VoidCallback onOpenTransactions;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.emerald500.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(
                icon: Icons.check_circle_rounded,
                background: AppColors.emerald100,
                color: AppColors.emerald600,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${result.imported} lançamento(s) importados',
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.duplicates > 0
                ? '${result.duplicates} já estavam na conta e ficaram de fora. '
                      'Saldo agora: ${formatCurrency(result.accountBalance)}.'
                : 'Saldo agora: ${formatCurrency(result.accountBalance)}.',
            style: TextStyle(
              color: AppColors.secondaryText(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          OutlineActionButton(
            label: 'Ver no extrato',
            icon: Icons.arrow_forward_rounded,
            onPressed: onOpenTransactions,
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.rose500.withValues(alpha: 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconTile(
            icon: Icons.error_outline_rounded,
            background: AppColors.rose100,
            color: AppColors.rose600,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.primaryText(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
