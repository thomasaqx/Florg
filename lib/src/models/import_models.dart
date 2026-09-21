import 'financial_models.dart';

/// Which column of the spreadsheet holds each field, by zero-based index.
///
/// The backend fills this in on its own. The user only touches it when the
/// guess is wrong, which happens with statements that have odd column names.
class ColumnMapping {
  const ColumnMapping({this.date, this.description, this.amount, this.type});

  final int? date;
  final int? description;
  final int? amount;
  final int? type;

  factory ColumnMapping.fromJson(Map<String, dynamic> json) {
    return ColumnMapping(
      date: json['date'] as int?,
      description: json['description'] as int?,
      amount: json['amount'] as int?,
      type: json['type'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'description': description,
    'amount': amount,
    'type': type,
  };

  ColumnMapping copyWith({
    int? date,
    int? description,
    int? amount,
    int? type,
    bool clearType = false,
  }) {
    return ColumnMapping(
      date: date ?? this.date,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: clearType ? null : (type ?? this.type),
    );
  }
}

/// One statement line, already parsed and ready to become a transaction.
class ImportRow {
  const ImportRow({
    required this.line,
    required this.description,
    required this.amount,
    required this.type,
    required this.occurredAt,
    required this.fingerprint,
  });

  final int line;
  final String description;
  final double amount;
  final TransactionKind type;
  final DateTime occurredAt;

  /// Identifies the line across imports, so re-sending a file skips it.
  final String fingerprint;

  factory ImportRow.fromJson(Map<String, dynamic> json) {
    return ImportRow(
      line: json['line'] as int,
      description: json['description'].toString(),
      amount: double.parse(json['amount'].toString()),
      type: json['type'].toString() == TransactionKind.income.name
          ? TransactionKind.income
          : TransactionKind.expense,
      occurredAt: DateTime.parse(json['occurred_at'].toString()),
      fingerprint: json['fingerprint'].toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'line': line,
    'description': description,
    'amount': amount.toStringAsFixed(2),
    'type': type.name,
    'occurred_at':
        '${occurredAt.year}-'
        '${occurredAt.month.toString().padLeft(2, '0')}-'
        '${occurredAt.day.toString().padLeft(2, '0')}',
    'fingerprint': fingerprint,
  };
}

/// A line the parser could not read, kept so nothing disappears quietly.
class SkippedRow {
  const SkippedRow({
    required this.line,
    required this.reason,
    required this.raw,
  });

  final int line;
  final String reason;
  final List<String> raw;

  factory SkippedRow.fromJson(Map<String, dynamic> json) {
    return SkippedRow(
      line: json['line'] as int,
      reason: json['reason'].toString(),
      raw: (json['raw'] as List<dynamic>)
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class SpreadsheetPreview {
  const SpreadsheetPreview({
    required this.filename,
    required this.headers,
    required this.mapping,
    required this.totalRows,
    required this.rows,
    required this.skipped,
    required this.duplicateCount,
  });

  final String filename;
  final List<String> headers;
  final ColumnMapping mapping;
  final int totalRows;
  final List<ImportRow> rows;
  final List<SkippedRow> skipped;

  /// How many of these lines are already in the chosen account.
  final int duplicateCount;

  int get newRowCount => rows.length - duplicateCount;

  double get incomeTotal => rows
      .where((row) => row.type == TransactionKind.income)
      .fold(0, (sum, row) => sum + row.amount);

  double get expenseTotal => rows
      .where((row) => row.type == TransactionKind.expense)
      .fold(0, (sum, row) => sum + row.amount);

  factory SpreadsheetPreview.fromJson(Map<String, dynamic> json) {
    return SpreadsheetPreview(
      filename: json['filename'].toString(),
      headers: (json['headers'] as List<dynamic>)
          .map((item) => item.toString())
          .toList(),
      mapping: ColumnMapping.fromJson(json['mapping'] as Map<String, dynamic>),
      totalRows: json['total_rows'] as int,
      rows: (json['rows'] as List<dynamic>)
          .map((item) => ImportRow.fromJson(item as Map<String, dynamic>))
          .toList(),
      skipped: (json['skipped'] as List<dynamic>)
          .map((item) => SkippedRow.fromJson(item as Map<String, dynamic>))
          .toList(),
      duplicateCount: json['duplicate_count'] as int? ?? 0,
    );
  }
}

class ImportResult {
  const ImportResult({
    required this.imported,
    required this.duplicates,
    required this.accountBalance,
  });

  final int imported;
  final int duplicates;
  final double accountBalance;

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    return ImportResult(
      imported: json['imported'] as int,
      duplicates: json['duplicates'] as int,
      accountBalance: double.parse(json['account_balance'].toString()),
    );
  }
}

/// A spreadsheet that was imported in the past.
class ImportBatch {
  const ImportBatch({
    required this.id,
    required this.accountId,
    required this.filename,
    required this.rowsImported,
    required this.rowsDuplicated,
    required this.createdAt,
  });

  final String id;
  final String accountId;
  final String filename;
  final int rowsImported;
  final int rowsDuplicated;
  final DateTime createdAt;

  factory ImportBatch.fromJson(Map<String, dynamic> json) {
    return ImportBatch(
      id: json['id'].toString(),
      accountId: json['account_id'].toString(),
      filename: json['filename'].toString(),
      rowsImported: json['rows_imported'] as int,
      rowsDuplicated: json['rows_duplicated'] as int,
      createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
    );
  }
}
